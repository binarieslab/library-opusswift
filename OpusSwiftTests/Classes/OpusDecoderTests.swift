//
//  OpusDecoderTests.swift
//  OpusSwiftTests
//
//  Created by Marcelo Sarquis on 06.11.22.
//

@testable import OpusSwift
import XCTest

final class OpusDecoderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDecoder_whenValidAudioIsGiven_shouldEncodeNewFormat() throws {
        // Given
        let audioData = TestUtils.opusfile.data
        let numChannels: Int32 = 1
        let sampleRate: Int32 = 48000

        // When
        let decoder = try OpusDecoder(numChannels: numChannels, sampleRate: sampleRate)
        let decodedData = try decoder.decode(audioData: audioData)

        // Expected
        XCTAssertEqual(decodedData.count, 283892)
    }
    
    func testDecoder_whenWrongAudioIsGiven_shouldThrowError() throws {
    }
}
