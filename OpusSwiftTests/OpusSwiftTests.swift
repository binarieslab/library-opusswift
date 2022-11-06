//
//  OpusSwiftTests.swift
//  OpusSwiftTests
//
//  Created by Marcelo Sarquis on 27.10.22.
//

@testable import OpusSwift
import XCTest

final class OpusSwiftTests: XCTestCase {

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
        let encodedURL = TestUtils.pcmfile.url
            .deletingLastPathComponent()
            .appendingPathComponent("encodedfile.ogg")
        try encodedData.write(to: encodedURL)
        
        XCTAssertTrue(encodedData.count > 0)
    }
    
    func testEncoder_whenWrongAudioIsGiven_shouldThrowError() throws {
    }
    
    func testDecoder_whenValidAudioIsGiven_shouldEncodeNewFormat() throws {
//        // Given
//        let audioData = TestUtils.opusfile.data
//        let numChannels: Int32 = 1
//        let sampleRate: Int32 = 48000
//
//        // When
//        let decoder = try OpusDecoder(numChannels: numChannels, sampleRate: sampleRate)
//        let decodedData = try decoder.decode(audioData: audioData)
//
//        // Expected
//        XCTAssertEqual(decodedData.count, 283892)
    }
    
    func testDecoder_whenWrongAudioIsGiven_shouldThrowError() throws {
    }
    
    func testEncoderDecoder_whenValudAudioIsGiven_shouldEncodeDecodeCorretly() throws {
//        // Given
//        let pcmData = TestUtils.pcmfile.data
//        let pcmRate: Int32 = 48000
//        let pcmChannels: Int32 = 1
//        let bytesPerFrame: UInt32 = 1
//        let opusRate: Int32 = 48000
//        let decodeNumChannels: Int32 = 1
//        let decodeSampleRate: Int32 = 48000
//
//        // When
//        let encoder = try OpusEncoder(pcmRate: pcmRate, pcmChannels: pcmChannels, pcmBytesPerFrame: bytesPerFrame, opusRate: opusRate, application: .audio)
//        try encoder.encode(pcm: pcmData)
//        let encodedData = try encoder.endstream()
//        let decoder = try OpusDecoder(numChannels: decodeNumChannels, sampleRate: decodeSampleRate)
//        let decodedData = try decoder.decode(audioData: encodedData)
//
//
//
//        let decodedURL = TestUtils.pcmfile.url
//            .deletingLastPathComponent()
//            .appendingPathComponent("finaldecoded.wav")
//        try decodedData.write(to: decodedURL)
    }
}
