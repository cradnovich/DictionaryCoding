import XCTest
@testable import DictionaryCoding

fileprivate struct TestStruct: Codable, Equatable {
    let id: String
    let number: Int
    let floops: [Double]
}

fileprivate let t1 = TestStruct(id: "test", number: 47, floops: [9.827])

let encoder = DictionaryEncoder()
let decoder = DictionaryDecoder()

final class DictionaryCoderTests: XCTestCase {
    func testEncode() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        do {
            let dict = try encoder.encode(t1)
            
            XCTAssert(dict.elementsEqual(["id": "test", "number": 47, "floops": [9.827]], by: { (kvPair, realDictElement) -> Bool in
                true
            }))
        } catch {
            XCTFail(error.localizedDescription)
        }
        
    }
    
    func testEncodeUnkeyed() {
        let ary = ["whoomp", "derp"]
        
        do {
            let _ = try encoder.encode(ary)
            
            XCTFail("Shouldn't be able to encode an array to the top-level of a dictionary")
        } catch {
            XCTAssert(error is EncodingError)
        }
        
        do {
            let wrapped = ["wrapped":ary]
            
            let dict = try encoder.encode(wrapped)
            
            XCTAssertEqual(1, wrapped.count)
            XCTAssertEqual(wrapped["wrapped"], ary)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    
    func testDecode() {
        let manualDict: [AnyHashable:Any] = ["id": "test", "number": 47, "floops": [9.827]]
        
        do {
            let decoded = try decoder.decode(TestStruct.self, from: manualDict)
            
            XCTAssertEqual(decoded, t1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    static var allTests = [
        ("testEncode", testEncode),
        ("testDecode", testDecode)
    ]
}
