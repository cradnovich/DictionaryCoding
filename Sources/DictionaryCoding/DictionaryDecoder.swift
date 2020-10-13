//  DictionaryDecoder.swift
//  DictionaryCoder
//
//  Created by Meir Radnovich on 24 Tishri 5781.
//  Copyright © 5781 Meir Radnovich. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is based on the PropertyListDecoder in the Swift.org open source project
//
//===----------------------------------------------------------------------===//

import Foundation
import Combine

//===----------------------------------------------------------------------===//
// Dictionary Decoder
//===----------------------------------------------------------------------===//

/// `DictionaryDecoder` facilitates the decoding of property list values into semantic `Decodable` types.
open class DictionaryDecoder {
  
  public typealias Input = [AnyHashable:Any]
  
  // MARK: Options
  
  /// Contextual user-provided information for use during decoding.
  open var userInfo: [CodingUserInfoKey : Any] = [:]
  
  /// Options set on the top-level encoder to pass down the decoding hierarchy.
  fileprivate struct _Options {
    let userInfo: [CodingUserInfoKey : Any]
  }
  
  /// The options set on the top-level decoder.
  fileprivate var options: _Options {
    return _Options(userInfo: userInfo)
  }
  
  // MARK: - Constructing a Property List Decoder
  
  /// Initializes `self` with default strategies.
  public init() {}
  
  // MARK: - Decoding Values
  
  open func decode<T>(_ type: T.Type, from dict: Input) throws -> T where T : Decodable {
    return try decode(type, fromTopLevel: dict)
  }
  
  /// Decodes a top-level value of the given type from the given container (top-level dictionary).
  ///
  /// - parameter type: The type of the value to decode.
  /// - parameter container: The top-level dictionary container.
  /// - returns: A value of the requested type.
  /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not a valid property list.
  /// - throws: An error if any value throws an error during decoding.
  internal func decode<T : Decodable>(_ type: T.Type, fromTopLevel container: Any) throws -> T {
    let decoder = __DictDecoder(referencing: container, options: self.options)
    guard let value = try decoder.unbox(container, as: type) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
    }
    
    return value
  }
}

// MARK: - __DictDecoder

fileprivate class __DictDecoder : Decoder {
  // MARK: Properties
  
  /// The decoder's storage.
  fileprivate var storage: _DictDecodingStorage
  
  /// Options set on the top-level decoder.
  fileprivate let options: DictionaryDecoder._Options
  
  /// The path to the current point in encoding.
  fileprivate(set) public var codingPath: [CodingKey]
  
  /// Contextual user-provided information for use during encoding.
  public var userInfo: [CodingUserInfoKey : Any] {
    return self.options.userInfo
  }
  
  // MARK: - Initialization
  
  /// Initializes `self` with the given top-level container and options.
  fileprivate init(referencing container: Any, at codingPath: [CodingKey] = [], options: DictionaryDecoder._Options) {
    self.storage = _DictDecodingStorage()
    self.storage.push(container: container)
    self.codingPath = codingPath
    self.options = options
  }
  
  // MARK: - Decoder Methods
  
  public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard !(self.storage.topContainer is NSNull) else {
      throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get keyed decoding container -- found null value instead."))
    }
    
    guard let topContainer = self.storage.topContainer as? [String : Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: self.storage.topContainer)
    }
    
    let container = _DictKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
    return KeyedDecodingContainer(container)
  }
  
  public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    guard !(self.storage.topContainer is NSNull) else {
      throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
    }
    
    guard let topContainer = self.storage.topContainer as? [Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [Any].self, reality: self.storage.topContainer)
    }
    
    return _DictUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
  }
  
  public func singleValueContainer() throws -> SingleValueDecodingContainer {
    return self
  }
}

// MARK: - Decoding Storage

fileprivate struct _DictDecodingStorage {
  // MARK: Properties
  
  /// The container stack.
  /// Elements may be any one of the plist types (NSNumber, Date, String, Array, [String : Any]).
  private(set) fileprivate var containers: [Any] = []
  
  // MARK: - Initialization
  
  /// Initializes `self` with no containers.
  fileprivate init() {}
  
  // MARK: - Modifying the Stack
  
  fileprivate var count: Int {
    return self.containers.count
  }
  
  fileprivate var topContainer: Any {
    precondition(!self.containers.isEmpty, "Empty container stack.")
    return self.containers.last!
  }
  
  fileprivate mutating func push(container: __owned Any) {
    self.containers.append(container)
  }
  
  fileprivate mutating func popContainer() {
    precondition(!self.containers.isEmpty, "Empty container stack.")
    self.containers.removeLast()
  }
}

// MARK: Decoding Containers

fileprivate struct _DictKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
  typealias Key = K
  
  // MARK: Properties
  
  /// A reference to the decoder we're reading from.
  private let decoder: __DictDecoder
  
  /// A reference to the container we're reading from.
  private let container: [String : Any]
  
  /// The path of coding keys taken to get to this point in decoding.
  private(set) public var codingPath: [CodingKey]
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given decoder and container.
  fileprivate init(referencing decoder: __DictDecoder, wrapping container: [String : Any]) {
    self.decoder = decoder
    self.container = container
    self.codingPath = decoder.codingPath
  }
  
  // MARK: - KeyedDecodingContainerProtocol Methods
  
  public var allKeys: [Key] {
    return self.container.keys.compactMap { Key(stringValue: $0) }
  }
  
  public func contains(_ key: Key) -> Bool {
    return self.container[key.stringValue] != nil
  }
  
  public func decodeNil(forKey key: Key) throws -> Bool {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    guard let _ = entry as? NSNull else {
      return false
    }
    
    return true
  }
  
  public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Int.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Int8.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Int16.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Int32.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Int64.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: UInt.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: UInt8.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: UInt16.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: UInt32.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: UInt64.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    guard let value = try self.decoder.unbox(entry, as: Float.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: Double.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode(_ type: String.Type, forKey key: Key) throws -> String {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: String.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    guard let entry = self.container[key.stringValue] else {
      throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
    }
    
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = try self.decoder.unbox(entry, as: type) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }
    
    return value
  }
  
  public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = self.container[key.stringValue] else {
      throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get nested keyed container -- no value found for key \"\(key.stringValue)\""))
    }
    
    guard let dictionary = value as? [String : Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: value)
    }
    
    let container = _DictKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
    return KeyedDecodingContainer(container)
  }
  
  public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    guard let value = self.container[key.stringValue] else {
      throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get nested unkeyed container -- no value found for key \"\(key.stringValue)\""))
    }
    
    guard let array = value as? [Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
    }
    
    return _DictUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
  }
  
  private func _superDecoder(forKey key: __owned CodingKey) throws -> Decoder {
    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }
    
    let value: Any = self.container[key.stringValue] ?? NSNull()
    return __DictDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
  }
  
  public func superDecoder() throws -> Decoder {
    return try _superDecoder(forKey: _DictKey.super)
  }
  
  public func superDecoder(forKey key: Key) throws -> Decoder {
    return try _superDecoder(forKey: key)
  }
}

fileprivate struct _DictUnkeyedDecodingContainer : UnkeyedDecodingContainer {
  // MARK: Properties
  
  /// A reference to the decoder we're reading from.
  private let decoder: __DictDecoder
  
  /// A reference to the container we're reading from.
  private let container: [Any]
  
  /// The path of coding keys taken to get to this point in decoding.
  private(set) public var codingPath: [CodingKey]
  
  /// The index of the element we're about to decode.
  private(set) public var currentIndex: Int
  
  // MARK: - Initialization
  
  /// Initializes `self` by referencing the given decoder and container.
  fileprivate init(referencing decoder: __DictDecoder, wrapping container: [Any]) {
    self.decoder = decoder
    self.container = container
    self.codingPath = decoder.codingPath
    self.currentIndex = 0
  }
  
  // MARK: - UnkeyedDecodingContainer Methods
  
  public var count: Int? {
    return self.container.count
  }
  
  public var isAtEnd: Bool {
    return self.currentIndex >= self.count!
  }
  
  public mutating func decodeNil() throws -> Bool {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    if self.container[self.currentIndex] is NSNull {
      self.currentIndex += 1
      return true
    } else {
      return false
    }
  }
  
  public mutating func decode(_ type: Bool.Type) throws -> Bool {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Bool.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Int.Type) throws -> Int {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Int8.Type) throws -> Int8 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int8.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Int16.Type) throws -> Int16 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int16.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Int32.Type) throws -> Int32 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int32.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Int64.Type) throws -> Int64 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int64.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: UInt.Type) throws -> UInt {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt8.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt16.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt32.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt64.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Float.Type) throws -> Float {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Float.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: Double.Type) throws -> Double {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Double.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode(_ type: String.Type) throws -> String {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: String.self) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func decode<T : Decodable>(_ type: T.Type) throws -> T {
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
    }
    
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: type) else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_DictKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
    }
    
    self.currentIndex += 1
    return decoded
  }
  
  public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
    }
    
    let value = self.container[self.currentIndex]
    guard !(value is NSNull) else {
      throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get keyed decoding container -- found null value instead."))
    }
    
    guard let dictionary = value as? [String : Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: value)
    }
    
    self.currentIndex += 1
    let container = _DictKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
    return KeyedDecodingContainer(container)
  }
  
  public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get nested unkeyed container -- unkeyed container is at end."))
    }
    
    let value = self.container[self.currentIndex]
    guard !(value is NSNull) else {
      throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                        DecodingError.Context(codingPath: self.codingPath,
                                                              debugDescription: "Cannot get keyed decoding container -- found null value instead."))
    }
    
    guard let array = value as? [Any] else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
    }
    
    self.currentIndex += 1
    return _DictUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
  }
  
  public mutating func superDecoder() throws -> Decoder {
    self.decoder.codingPath.append(_DictKey(index: self.currentIndex))
    defer { self.decoder.codingPath.removeLast() }
    
    guard !self.isAtEnd else {
      throw DecodingError.valueNotFound(Decoder.self, DecodingError.Context(codingPath: self.codingPath,
                                                                            debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."))
    }
    
    let value = self.container[self.currentIndex]
    self.currentIndex += 1
    return __DictDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
  }
}

extension __DictDecoder : SingleValueDecodingContainer {
  // MARK: SingleValueDecodingContainer Methods
  
  private func expectNonNull<T>(_ type: T.Type) throws {
    guard !self.decodeNil() else {
      throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected \(type) but found null value instead."))
    }
  }
  
  public func decodeNil() -> Bool {
    guard let _ = self.storage.topContainer as? NSNull else {
      return false
    }
    
    return true
  }
  
  public func decode(_ type: Bool.Type) throws -> Bool {
    try expectNonNull(Bool.self)
    return try self.unbox(self.storage.topContainer, as: Bool.self)!
  }
  
  public func decode(_ type: Int.Type) throws -> Int {
    try expectNonNull(Int.self)
    return try self.unbox(self.storage.topContainer, as: Int.self)!
  }
  
  public func decode(_ type: Int8.Type) throws -> Int8 {
    try expectNonNull(Int8.self)
    return try self.unbox(self.storage.topContainer, as: Int8.self)!
  }
  
  public func decode(_ type: Int16.Type) throws -> Int16 {
    try expectNonNull(Int16.self)
    return try self.unbox(self.storage.topContainer, as: Int16.self)!
  }
  
  public func decode(_ type: Int32.Type) throws -> Int32 {
    try expectNonNull(Int32.self)
    return try self.unbox(self.storage.topContainer, as: Int32.self)!
  }
  
  public func decode(_ type: Int64.Type) throws -> Int64 {
    try expectNonNull(Int64.self)
    return try self.unbox(self.storage.topContainer, as: Int64.self)!
  }
  
  public func decode(_ type: UInt.Type) throws -> UInt {
    try expectNonNull(UInt.self)
    return try self.unbox(self.storage.topContainer, as: UInt.self)!
  }
  
  public func decode(_ type: UInt8.Type) throws -> UInt8 {
    try expectNonNull(UInt8.self)
    return try self.unbox(self.storage.topContainer, as: UInt8.self)!
  }
  
  public func decode(_ type: UInt16.Type) throws -> UInt16 {
    try expectNonNull(UInt16.self)
    return try self.unbox(self.storage.topContainer, as: UInt16.self)!
  }
  
  public func decode(_ type: UInt32.Type) throws -> UInt32 {
    try expectNonNull(UInt32.self)
    return try self.unbox(self.storage.topContainer, as: UInt32.self)!
  }
  
  public func decode(_ type: UInt64.Type) throws -> UInt64 {
    try expectNonNull(UInt64.self)
    return try self.unbox(self.storage.topContainer, as: UInt64.self)!
  }
  
  public func decode(_ type: Float.Type) throws -> Float {
    try expectNonNull(Float.self)
    return try self.unbox(self.storage.topContainer, as: Float.self)!
  }
  
  public func decode(_ type: Double.Type) throws -> Double {
    try expectNonNull(Double.self)
    return try self.unbox(self.storage.topContainer, as: Double.self)!
  }
  
  public func decode(_ type: String.Type) throws -> String {
    try expectNonNull(String.self)
    return try self.unbox(self.storage.topContainer, as: String.self)!
  }
  
  public func decode<T : Decodable>(_ type: T.Type) throws -> T {
    try expectNonNull(type)
    return try self.unbox(self.storage.topContainer, as: type)!
  }
}

// MARK: - Concrete Value Representations

extension __DictDecoder {
  /// Returns the given value unboxed from a container.
  fileprivate func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
    if let _ = value as? NSNull { return nil }
    
    if let number = value as? NSNumber {
      // TODO: Add a flag to coerce non-boolean numbers into Bools?
      if number === NSNumber(booleanLiteral: true) {
        return true
      } else if number === NSNumber(booleanLiteral: false) {
        return false
      }
      
      /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
       } else if let bool = value as? Bool {
       return bool
       */
      
    }
    
    throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
  }
  
  fileprivate func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let int = number.intValue
    guard NSNumber(value: int) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return int
  }
  
  fileprivate func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let int8 = number.int8Value
    guard NSNumber(value: int8) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return int8
  }
  
  fileprivate func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let int16 = number.int16Value
    guard NSNumber(value: int16) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return int16
  }
  
  fileprivate func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let int32 = number.int32Value
    guard NSNumber(value: int32) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return int32
  }
  
  fileprivate func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let int64 = number.int64Value
    guard NSNumber(value: int64) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return int64
  }
  
  fileprivate func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let uint = number.uintValue
    guard NSNumber(value: uint) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return uint
  }
  
  fileprivate func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let uint8 = number.uint8Value
    guard NSNumber(value: uint8) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return uint8
  }
  
  fileprivate func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let uint16 = number.uint16Value
    guard NSNumber(value: uint16) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return uint16
  }
  
  fileprivate func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let uint32 = number.uint32Value
    guard NSNumber(value: uint32) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return uint32
  }
  
  fileprivate func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let uint64 = number.uint64Value
    guard NSNumber(value: uint64) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return uint64
  }
  
  fileprivate func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let float = number.floatValue
    guard NSNumber(value: float) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return float
  }
  
  fileprivate func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
    if let _ = value as? NSNull { return nil }
    
    guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    let double = number.doubleValue
    guard NSNumber(value: double) == number else {
      throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed property list number <\(number)> does not fit in \(type)."))
    }
    
    return double
  }
  
  fileprivate func unbox(_ value: Any, as type: String.Type) throws -> String? {
    guard let string = value as? String else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    return string
  }
  
  fileprivate func unbox(_ value: Any, as type: Date.Type) throws -> Date? {
    if let _ = value as? NSNull { return nil }
    
    guard let date = value as? Date else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    return date
  }
  
  fileprivate func unbox(_ value: Any, as type: Data.Type) throws -> Data? {
    if let _ = value as? NSNull { return nil }
    
    guard let data = value as? Data else {
      throw DecodingError.typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    return data
  }
  
  fileprivate func unbox<T : Decodable>(_ value: Any, as type: T.Type) throws -> T? {
    if type == Date.self || type == NSDate.self {
      return try self.unbox(value, as: Date.self) as? T
    } else if type == Data.self || type == NSData.self {
      return try self.unbox(value, as: Data.self) as? T
    } else {
      self.storage.push(container: value)
      defer { self.storage.popContainer() }
      return try type.init(from: self)
    }
  }
}

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

internal struct _DictKey : CodingKey {
  public var stringValue: String
  public var intValue: Int?
  
  public init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }
  
  public init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
  
  internal init(index: Int) {
    self.stringValue = "Index \(index)"
    self.intValue = index
  }
  
  internal static let `super` = _DictKey(stringValue: "super")!
}


// Only support 64bit
#if !(os(iOS) && (arch(i386) || arch(arm)))

import Combine

//===----------------------------------------------------------------------===//
// Generic Decoding
//===----------------------------------------------------------------------===//

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension DictionaryDecoder: TopLevelDecoder { }

#endif /* !(os(iOS) && (arch(i386) || arch(arm))) */


