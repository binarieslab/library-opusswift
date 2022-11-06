//
//  OpusEncoderTests.swift
//  OpusSwiftTests
//
//  Created by Marcelo Sarquis on 06.11.22.
//

@testable import OpusSwift
import XCTest

final class OpusEncoderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEncoder_whenValidAudioIsGiven_shouldEncodeNewFormat() throws {
        // Given
        let pcmData = TestUtils.pcmfile.data
        let pcmRate: Int32 = 24000
        let pcmChannels: Int32 = 1
        let bytesPerFrame: UInt32 = 1
        let opusRate: Int32 = 24000
        
        // When
        let encoder = try OpusEncoder(pcmRate: pcmRate, pcmChannels: pcmChannels, pcmBytesPerFrame: bytesPerFrame, opusRate: opusRate, granuleFraction: opusRate, application: .audio)
        try encoder.encode(pcm: pcmData)
        let encodedData = try encoder.endstream()
        
        print(encodedData.count)
        
        // Expected
        XCTAssertEqual(encodedData.count, 19973)
    }
    
    func testEncoder_whenWrongAudioIsGiven_shouldThrowError() throws {
    }
}
