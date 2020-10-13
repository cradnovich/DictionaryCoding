//  DictionaryEncoder.swift
//  DictionaryCoder
//
//  Created by Meir Radnovich on 24 Tishri 5781.
//  Copyright © 5781 Meir Radnovich. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is based on the PropertyListEncoder in the Swift.org open source project
//
//===----------------------------------------------------------------------===//

import Foundation

//===----------------------------------------------------------------------===//
// Dictionary Encoder
//===----------------------------------------------------------------------===//

/// `DictionaryEncoder` facilitates the encoding of `Encodable` values into `[AnyHashable:Any]` dictionaries.
open class DictionaryEncoder
{
  public typealias Output = [AnyHashable:Any]
  
  
  // MARK: - Options
  
  /// Contextual user-provided information for use during encoding.
  //open var userInfo: [CodingUserInfoKey : Any] = [:]
  
  /// Options set on the top-level encoder to pass down the encoding hierarchy.
//  fileprivate struct _Options {
//    let outputFormat: PropertyListSerialization.PropertyListFormat
//    let userInfo: [CodingUserInfoKey : Any]
//  }
  
  /// The options set on the top-level encoder.
//  fileprivate var options: _Options {
//    return _Options(outputFormat: outputFormat, userInfo: userInfo)
//  }
  
  // MARK: - Constructing a Dictionary Encoder
  
  /// Initializes `self` with default strategies.
  public init() {}
  
  // MARK: - Encoding Values
  
  /// Encodes the given top-level value and returns its property list representation.
  ///
  /// - parameter value: The value to encode.
  /// - returns: A new `[AnyHashable:Any]` value containing the encoded data.
  /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
  /// - throws: An error if any value throws an error during encoding.
  open func encode<Value : Encodable>(_ value: Value) throws -> [AnyHashable:Any] {
    let topLevel = try encodeToTopLevelContainer(value)
    if topLevel is NSNumber {
      throw EncodingError.invalidValue(value,
                                       EncodingError.Context(codingPath: [],
                                                             debugDescription: "Top-level \(Value.self) encoded as number dictionary fragment."))
    } else if topLevel is NSString {
      throw EncodingError.invalidValue(value,
                                       EncodingError.Context(codingPath: [],
                                                             debugDescription: "Top-level \(Value.self) encoded as string dictionary fragment."))
    } else if topLevel is NSDate {
      throw EncodingError.invalidValue(value,
                                       EncodingError.Context(codingPath: [],
                                                             debugDescription: "Top-level \(Value.self) encoded as date dictionary fragment."))
    }
    
    guard let dict = topLevel as? Output else {
      throw EncodingError.invalidValue(value,
                                       EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value as a dictionary."))
    }
    
    return dict
  }
  
  /// Encodes the given top-level value and returns its plist-type representation.
  ///
  /// - parameter value: The value to encode.
  /// - returns: A new top-level array or dictionary representing the value.
  /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
  /// - throws: An error if any value throws an error during encoding.
  internal func encodeToTopLevelContainer<Value : Encodable>(_ value: Value) throws -> Any {
    let encoder = __DictEncoder() //(options: self.options)
    guard let topLevel = try encoder.box_(value) else {
      throw EncodingError.invalidValue(value,
                                       EncodingError.Context(codingPath: [],
                                                             debugDescription: "Top-level \(Value.self) did not encode any values."))
    }
    
    return topLevel
  }
}

// MARK: - __DictEncoder

fileprivate class __DictEncoder : Encoder {
  // MARK: Properties
  
  /// The encoder's storage.
  fileprivate var storage: _DictEncodingStorage
  
  /// Options set on the top-level encoder.
//  fileprivate let options: PropertyListEncoder._Options
  
  /// The path to the current point in encoding.
  fileprivate(set) public var codingPath: [CodingKey]
  
  /// Contextual user-provided information for use during encoding.
  public var userInfo: [CodingUserInfoKey : Any] {
    return [:] //self.options.userInfo
  }
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given top-level encoder options.
//  fileprivate init(options: PropertyListEncoder._Options, codingPath: [CodingKey] = []) {
//    self.options = options
//    self.storage = _DictEncodingStorage()
//    self.codingPath = codingPath
//  }
  fileprivate init(codingPath: [CodingKey] = []) {
    self.storage = _DictEncodingStorage()
    self.codingPath = codingPath
  }
  
  
  /// Returns whether a new element can be encoded at this coding path.
  ///
  /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
  fileprivate var canEncodeNewValue: Bool {
    // Every time a new value gets encoded, the key it's encoded for is pushed onto the coding path (even if it's a nil key from an unkeyed container).
    // At the same time, every time a container is requested, a new value gets pushed onto the storage stack.
    // If there are more values on the storage stack than on the coding path, it means the value is requesting more than one container, which violates the precondition.
    //
    // This means that anytime something that can request a new container goes onto the stack, we MUST push a key onto the coding path.
    // Things which will not request containers do not need to have the coding path extended for them (but it doesn't matter if it is, because they will not reach here).
    return self.storage.count == self.codingPath.count
  }
  
  // MARK: - Encoder Methods
  public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
    // If an existing keyed container was already requested, return that one.
    let topContainer: NSMutableDictionary
    if self.canEncodeNewValue {
      // We haven't yet pushed a container at this level; do so here.
      topContainer = self.storage.pushKeyedContainer()
    } else {
      guard let container = self.storage.containers.last as? NSMutableDictionary else {
        preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
      }
      
      topContainer = container
    }
    
    let container = _DictKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    return KeyedEncodingContainer(container)
  }
  
  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    // If an existing unkeyed container was already requested, return that one.
    let topContainer: NSMutableArray
    if self.canEncodeNewValue {
      // We haven't yet pushed a container at this level; do so here.
      topContainer = self.storage.pushUnkeyedContainer()
    } else {
      guard let container = self.storage.containers.last as? NSMutableArray else {
        preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
      }
      
      topContainer = container
    }
    
    return _DictUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
  }
  
  public func singleValueContainer() -> SingleValueEncodingContainer {
    return self
  }
}

// MARK: - Encoding Storage and Containers

fileprivate struct _DictEncodingStorage {
  // MARK: Properties
  
  /// The container stack.
  /// Elements may be any one of the plist types (NSNumber, NSString, NSDate, NSArray, NSDictionary).
  private(set) fileprivate var containers: [NSObject] = []
  
  // MARK: - Initialization
  
  /// Initializes `self` with no containers.
  fileprivate init() {}
  
  // MARK: - Modifying the Stack
  
  fileprivate var count: Int {
    return self.containers.count
  }
  
  fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
    let dictionary = NSMutableDictionary()
    self.containers.append(dictionary)
    return dictionary
  }
  
  fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
    let array = NSMutableArray()
    self.containers.append(array)
    return array
  }
  
  fileprivate mutating func push(container: __owned NSObject) {
    self.containers.append(container)
  }
  
  fileprivate mutating func popContainer() -> NSObject {
    precondition(!self.containers.isEmpty, "Empty container stack.")
    return self.containers.popLast()!
  }
}

// MARK: - Encoding Containers

fileprivate struct _DictKeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
  typealias Key = K
  
  // MARK: Properties
  
  /// A reference to the encoder we're writing to.
  private let encoder: __DictEncoder
  
  /// A reference to the container we're writing to.
  private let container: NSMutableDictionary
  
  /// The path of coding keys taken to get to this point in encoding.
  private(set) public var codingPath: [CodingKey]
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given references.
  fileprivate init(referencing encoder: __DictEncoder, codingPath: [CodingKey], wrapping container: NSMutableDictionary) {
    self.encoder = encoder
    self.codingPath = codingPath
    self.container = container
  }
  
  // MARK: - KeyedEncodingContainerProtocol Methods
  
  public mutating func encodeNil(forKey key: Key)               throws { self.container[key.stringValue] = self.encoder.boxNull() }
  public mutating func encode(_ value: Bool, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Int, forKey key: Key)    throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Int8, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Int16, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Int32, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Int64, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: UInt, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: UInt8, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: UInt16, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: UInt32, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: UInt64, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: String, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Float, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
  public mutating func encode(_ value: Double, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
  
  public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
    self.encoder.codingPath.append(key)
    defer { self.encoder.codingPath.removeLast() }
    self.container[key.stringValue] = try self.encoder.box(value)
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
    let dictionary = NSMutableDictionary()
    self.container[key.stringValue] = dictionary
    
    self.codingPath.append(key)
    defer { self.codingPath.removeLast() }
    
    let container = _DictKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
    return KeyedEncodingContainer(container)
  }
  
  public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let array = NSMutableArray()
    self.container[key.stringValue] = array
    
    self.codingPath.append(key)
    defer { self.codingPath.removeLast() }
    return _DictUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
  }
  
  public mutating func superEncoder() -> Encoder {
    return __DictReferencingEncoder(referencing: self.encoder, at: _DictKey.super, wrapping: self.container)
  }
  
  public mutating func superEncoder(forKey key: Key) -> Encoder {
    return __DictReferencingEncoder(referencing: self.encoder, at: key, wrapping: self.container)
  }
}

fileprivate struct _DictUnkeyedEncodingContainer : UnkeyedEncodingContainer {
  // MARK: Properties
  
  /// A reference to the encoder we're writing to.
  private let encoder: __DictEncoder
  
  /// A reference to the container we're writing to.
  private let container: NSMutableArray
  
  /// The path of coding keys taken to get to this point in encoding.
  private(set) public var codingPath: [CodingKey]
  
  /// The number of elements encoded into the container.
  public var count: Int {
    return self.container.count
  }
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given references.
  fileprivate init(referencing encoder: __DictEncoder, codingPath: [CodingKey], wrapping container: NSMutableArray) {
    self.encoder = encoder
    self.codingPath = codingPath
    self.container = container
  }
  
  // MARK: - UnkeyedEncodingContainer Methods
  
  public mutating func encodeNil()             throws { self.container.add(self.encoder.boxNull()) }
  public mutating func encode(_ value: Bool)   throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Int)    throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Int8)   throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Int16)  throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Int32)  throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Int64)  throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: UInt)   throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: UInt8)  throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: UInt16) throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: UInt32) throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: UInt64) throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Float)  throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: Double) throws { self.container.add(self.encoder.box(value)) }
  public mutating func encode(_ value: String) throws { self.container.add(self.encoder.box(value)) }
  
  public mutating func encode<T : Encodable>(_ value: T) throws {
    self.encoder.codingPath.append(_DictKey(index: self.count))
    defer { self.encoder.codingPath.removeLast() }
    self.container.add(try self.encoder.box(value))
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
    self.codingPath.append(_DictKey(index: self.count))
    defer { self.codingPath.removeLast() }
    
    let dictionary = NSMutableDictionary()
    self.container.add(dictionary)
    
    let container = _DictKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
    return KeyedEncodingContainer(container)
  }
  
  public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    self.codingPath.append(_DictKey(index: self.count))
    defer { self.codingPath.removeLast() }
    
    let array = NSMutableArray()
    self.container.add(array)
    return _DictUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
  }
  
  public mutating func superEncoder() -> Encoder {
    return __DictReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
  }
}

extension __DictEncoder : SingleValueEncodingContainer {
  // MARK: - SingleValueEncodingContainer Methods
  
  private func assertCanEncodeNewValue() {
    precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
  }
  
  public func encodeNil() throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.boxNull())
  }
  
  public func encode(_ value: Bool) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Int) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Int8) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Int16) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Int32) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Int64) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: UInt) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: UInt8) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: UInt16) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: UInt32) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: UInt64) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: String) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Float) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode(_ value: Double) throws {
    assertCanEncodeNewValue()
    self.storage.push(container: self.box(value))
  }
  
  public func encode<T : Encodable>(_ value: T) throws {
    assertCanEncodeNewValue()
    try self.storage.push(container: self.box(value))
  }
}

// MARK: - Concrete Value Representations

extension __DictEncoder {
  
  /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
  fileprivate func box(_ value: Bool)   -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Int)    -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Int8)   -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Int16)  -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Int32)  -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Int64)  -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: UInt)   -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: UInt8)  -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: UInt16) -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: UInt32) -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: UInt64) -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Float)  -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: Double) -> NSObject { return NSNumber(value: value) }
  fileprivate func box(_ value: String) -> NSObject { return NSString(string: value) }
  fileprivate func boxNull() -> NSObject { return NSNull() }
  
  fileprivate func box<T : Encodable>(_ value: T) throws -> NSObject {
    return try self.box_(value) ?? NSDictionary()
  }
  
  fileprivate func box_<T : Encodable>(_ value: T) throws -> NSObject? {
    if T.self == Date.self || T.self == NSDate.self {
      // PropertyListSerialization handles NSDate directly.
      return (value as! NSDate)
    } else if T.self == Data.self || T.self == NSData.self {
      // PropertyListSerialization handles NSData directly.
      return (value as! NSData)
    }
    
    // The value should request a container from the __DictEncoder.
    let depth = self.storage.count
    do {
      try value.encode(to: self)
    } catch let error {
      // If the value pushed a container before throwing, pop it back off to restore state.
      if self.storage.count > depth {
        let _ = self.storage.popContainer()
      }
      
      throw error
    }
    
    // The top container should be a new container.
    guard self.storage.count > depth else {
      return nil
    }
    
    return self.storage.popContainer()
  }
}

// MARK: - __DictReferencingEncoder

/// __DictReferencingEncoder is a special subclass of __DictEncoder which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
fileprivate class __DictReferencingEncoder : __DictEncoder {
  // MARK: Reference types.
  
  /// The type of container we're referencing.
  private enum Reference {
    /// Referencing a specific index in an array container.
    case array(NSMutableArray, Int)
    
    /// Referencing a specific key in a dictionary container.
    case dictionary(NSMutableDictionary, String)
  }
  
  // MARK: - Properties
  
  /// The encoder we're referencing.
  private let encoder: __DictEncoder
  
  /// The container reference itself.
  private let reference: Reference
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given array container in the given encoder.
  fileprivate init(referencing encoder: __DictEncoder, at index: Int, wrapping array: NSMutableArray) {
    self.encoder = encoder
    self.reference = .array(array, index)
//    super.init(options: encoder.options, codingPath: encoder.codingPath)
    super.init(codingPath: encoder.codingPath)
    
    self.codingPath.append(_DictKey(index: index))
  }
  
  /// Initializes `self` by referencing the given dictionary container in the given encoder.
  fileprivate init(referencing encoder: __DictEncoder, at key: CodingKey, wrapping dictionary: NSMutableDictionary) {
    self.encoder = encoder
    self.reference = .dictionary(dictionary, key.stringValue)
//    super.init(options: encoder.options, codingPath: encoder.codingPath)
    super.init(codingPath: encoder.codingPath)
    
    self.codingPath.append(key)
  }
  
  // MARK: - Coding Path Operations
  
  fileprivate override var canEncodeNewValue: Bool {
    // With a regular encoder, the storage and coding path grow together.
    // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
    // We have to take this into account.
    return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
  }
  
  // MARK: - Deinitialization
  
  // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
  deinit {
    let value: Any
    switch self.storage.count {
    case 0: value = NSDictionary()
    case 1: value = self.storage.popContainer()
    default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
    }
    
    switch self.reference {
    case .array(let array, let index):
      array.insert(value, at: index)
      
    case .dictionary(let dictionary, let key):
      dictionary[NSString(string: key)] = value
    }
  }
}


// Only support 64bit
#if !(os(iOS) && (arch(i386) || arch(arm)))

import Combine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension DictionaryEncoder: TopLevelEncoder { }

#endif /* !(os(iOS) && (arch(i386) || arch(arm))) */

