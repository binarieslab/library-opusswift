//
//  OpusDecoder.swift
//  OpusSwift
//
//  Created by Marcelo Sarquis on 14.10.22.
//

import Foundation

public protocol OpusDecoderProtocol {
    init(numChannels: Int32, sampleRate: Int32) throws
    func decode(audioData: Data) throws -> Data
}

public final class OpusDecoder: OpusDecoderProtocol {

    /// object containing the decoded pcm data with wav headers
    private var pcmDataWithHeaders = Data()
    
    typealias opus_decoder = OpaquePointer
    private let MAX_FRAME_SIZE = Int32(960 * 6)

    /// state of ogg stream
    private var streamState: ogg_stream_state
    /// encapsulates the data for an Ogg page
    private var page: ogg_page
    /// tracks the status of data during decoding
    private var syncState: ogg_sync_state
    /// packet within a stream passing information
    private var packet: ogg_packet
    /// header of the Opus file to decode
    private var header: OpusHeader
    /// decoder to convert opus to pcm
    private var decoder: opus_decoder

    /// number of packets read during decoding
    private var packetCount: Int64 = 0
    /// if decoding of stream has begun
    private var beginStream = true
    /// position of the packet data at page
    private var pageGranulePosition: Int64 = 0
    /// whether or not the opus stream has been created
    private var hasOpusStream = false
    /// whether or not the tags packet has been read
    private var hasTagsPacket = false
    /// the assigned serial number of the opus stream
    private var opusSerialNumber: Int = 0
    /// total number of bytes written from opus stream to pcmData
    private var linkOut: Int32 = 0
    /// a count of the number of opus streams
    private var totalLinks: Int = 0
    /// Number of channels. Default value is 1
    private var numChannels: Int32
    private var pcmDataBuffer = UnsafeMutablePointer<Float>.allocate(capacity: 0)
    /// Sample rate for decoding. Default value by Opus is 48000. This must be one of 8000, 12000, 16000, 24000, or 48000.
    private var sampleRate: Int32
    /// number of samples to be skipped at beginning of stream
    private var preSkip: Int32 = 0
    /// where to begin reading the data from Opus
    private var granOffset: Int32 = 0
    /// number of samples decoded
    private var frameSize: Int32 = 0
    /// decoded pcm data
    private var pcmData = Data()

    public init(numChannels: Int32 = 1, sampleRate: Int32 = 48000) throws {
        self.numChannels = numChannels
        self.sampleRate = sampleRate
        
        // set properties
        streamState = ogg_stream_state()
        page = ogg_page()
        syncState = ogg_sync_state()
        packet = ogg_packet()
        header = OpusHeader()

        // status to catch errors when creating decoder
        var status = Int32(0)
        decoder = opus_decoder_create(sampleRate, numChannels, &status)
        
        guard let error = OpusError(rawValue: status) else {
            throw OpusError.internalError
        }
        guard error == .okay else {
            throw error
        }
    }
    
    public func decode(audioData: Data) throws -> Data {
        // initialize ogg sync state
        ogg_sync_init(&syncState)
        var processedByteCount = 0

        while processedByteCount < audioData.count {
            // determine the size of the buffer to ask for
            var bufferSize: Int
            if audioData.count - processedByteCount > 200 {
                bufferSize = 200
            } else {
                bufferSize = audioData.count - processedByteCount
            }

            // obtain a buffer from the syncState
            var bufferData: UnsafeMutablePointer<Int8>
            bufferData = ogg_sync_buffer(&syncState, bufferSize)

            // write data from the service into the syncState buffer
            bufferData.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bufferDataUInt8 in
                audioData.copyBytes(to: bufferDataUInt8, from: processedByteCount..<processedByteCount + bufferSize)
            }
            processedByteCount += bufferSize
            // notify syncState of number of bytes we actually wrote
            ogg_sync_wrote(&syncState, bufferSize)

            // attempt to get a page from the data that we wrote
            while ogg_sync_pageout(&syncState, &page) == 1 {
                if beginStream {
                    // assign stream's number with the page.
                    ogg_stream_init(&streamState, ogg_page_serialno(&page))
                    beginStream = false
                }

                if ogg_page_serialno(&page) != Int32(streamState.serialno) {
                    ogg_stream_reset_serialno(&streamState, ogg_page_serialno(&page))
                }

                // add page to the ogg stream
                ogg_stream_pagein(&streamState, &page)

                // save position of the current decoding process
                pageGranulePosition = ogg_page_granulepos(&page)

                // extract packets from the ogg stream until no packets are left
                try extractPacket(&streamState, &packet)
            }
        }

        if totalLinks == 0 {
            print("Does not look like an opus file.")
            throw OpusError.invalidState
        }

        // add wav header
        addWAVHeader()

        // perform cleanup
        opus_multistream_decoder_destroy(decoder)
        if !beginStream {
            ogg_stream_clear(&streamState)
        }
        ogg_sync_clear(&syncState)
        
        return pcmDataWithHeaders
    }
}

private extension OpusDecoder {
    /// Extract a packet from the ogg stream and store the extracted data within the packet object.
    func extractPacket(_ streamState: inout ogg_stream_state, _ packet: inout ogg_packet) throws {
        // attempt to extract a packet from the ogg stream
        while ogg_stream_packetout(&streamState, &packet) == 1 {
            // execute if initial stream header
            if packet.b_o_s != 0 && packet.bytes >= 8 && memcmp(packet.packet, "OpusHead", 8) == 0 {
                // check if there's another opus head to see if stream is chained without EOS
                if hasOpusStream && hasTagsPacket {
                    hasOpusStream = false
                    opus_multistream_decoder_destroy(decoder)
                }

                // set properties if we are in a new opus stream
                if !hasOpusStream {
                    if packetCount > 0 && opusSerialNumber == streamState.serialno {
                        print("Apparent chaining without changing serial number. Something bad happened.")
                        throw OpusError.internalError
                    }
                    opusSerialNumber = streamState.serialno
                    hasOpusStream = true
                    hasTagsPacket = false
                    linkOut = 0
                    packetCount = 0
                    totalLinks += 1
                } else {
                    print("Warning: ignoring opus stream.")
                }
            }

            if !hasOpusStream || streamState.serialno != opusSerialNumber {
                break
            }

            // if first packet in logical stream, process header
            if packetCount == 0 {
                // create decoder from information in Opus header
                decoder = try processHeader(packet: &packet, channels: &numChannels, preskip: &preSkip)

                // Check that there are no more packets in the first page.
                let lastElementIndex = page.header_len - 1
                let lacingValue = page.header[lastElementIndex]
                // A lacing value of 255 would suggest that the packet continues on the next page.
                if ogg_stream_packetout(&streamState, &packet) != 0 || lacingValue == 255 {
                    throw OpusError.invalidPacket
                }

                granOffset = preSkip

                pcmDataBuffer = UnsafeMutablePointer<Float>.allocate(capacity: MemoryLayout<Float>.stride * Int(MAX_FRAME_SIZE) * Int(numChannels))

                // deallocate pcmDataBuffer when the function ends, regardless if the function ended normally or with an error.
                do {
                    pcmDataBuffer.deallocate()
                }
            } else if packetCount == 1 {
                hasTagsPacket = true

                let lastElementIndex = page.header_len - 1
                let lacingValue = page.header[lastElementIndex]
                if ogg_stream_packetout(&streamState, &packet) != 0 || lacingValue == 255 {
                    print("Extra packets on initial tags page. Invalid stream.")
                    throw OpusError.invalidPacket
                }
            } else {
                var numberOfSamplesDecoded: Int32
                var maxOut: Int64
                var outSample: Int64

                // Decode opus packet.
                numberOfSamplesDecoded = opus_multistream_decode_float(decoder, packet.packet, Int32(packet.bytes), pcmDataBuffer, MAX_FRAME_SIZE, 0)

                if numberOfSamplesDecoded < 0 {
                    print("Decoding error: \(String(describing: opus_strerror(numberOfSamplesDecoded)))")
                    throw OpusError.internalError
                }

                frameSize = numberOfSamplesDecoded

                // Make sure the output duration follows the final end-trim
                // Output sample count should not be ahead of granpos value.
                maxOut = ((pageGranulePosition - Int64(granOffset)) * Int64(sampleRate) / 48000) - Int64(linkOut)
                outSample = try audioWrite(pcmDataBuffer: &pcmDataBuffer, channels: numChannels, frameSize: frameSize, skip: &preSkip, maxOut: &maxOut)

                linkOut += Int32(outSample)
            }
            packetCount += 1
        }

    }
    
    /// Process the Opus header and create a decoder with these values
    func processHeader(packet: inout ogg_packet, channels: inout Int32, preskip: inout Int32) throws -> opus_decoder {
        // create status to capture errors
        var status = Int32(0)

        if opus_header_parse(packet.packet, Int32(packet.bytes), &header) == 0 {
            throw OpusError.invalidPacket
        }

        channels = header.channels
        preskip = header.preskip

        // update the sample rate if a reasonable one is specified in the header
        let rate = Int32(header.input_sample_rate)
        if rate >= 8000 && rate <= 192000 {
            sampleRate = rate
        }

        decoder = opus_multistream_decoder_create(sampleRate, channels, header.nb_streams, header.nb_coupled, &header.stream_map.0, &status)
        if status != OpusError.okay.rawValue {
            throw OpusError.badArgument
        }
        return decoder
    }
    
    /// Write the decoded Opus data (now PCM) to the pcmData object
    func audioWrite(
        pcmDataBuffer: inout UnsafeMutablePointer<Float>,
        channels: Int32,
        frameSize: Int32,
        skip: inout Int32,
        maxOut: inout Int64
    ) throws -> Int64 {
        var sampOut: Int64 = 0
        var tmpSkip: Int32
        var outLength: UInt
        var shortOutput: UnsafeMutablePointer<CShort>
        var floatOutput: UnsafeMutablePointer<Float>
        shortOutput = UnsafeMutablePointer<CShort>.allocate(capacity: MemoryLayout<CShort>.stride * Int(MAX_FRAME_SIZE) * Int(channels))

        if maxOut < 0 {
            maxOut = 0
        }

        if skip != 0 {
            if skip > frameSize {
                tmpSkip = frameSize
            } else {
                tmpSkip = skip
            }
            skip -= tmpSkip
        } else {
            tmpSkip = 0
        }
        floatOutput = pcmDataBuffer.advanced(by: Int(channels) * Int(tmpSkip))

        outLength = UInt(frameSize) - UInt(tmpSkip)

        let maxLoop = Int(outLength) * Int(channels)
        for count in 0..<maxLoop {
            let maxMin = max(-32768, min(floatOutput.advanced(by: count).pointee * Float(32768), 32767))
            let float2int = CShort((floor(0.5 + maxMin)))
            shortOutput.advanced(by: count).initialize(to: float2int)
        }

        shortOutput.withMemoryRebound(to: UInt8.self, capacity: Int(outLength) * Int(channels)) { shortOutputUint8 in
            if maxOut > 0 {
                pcmData.append(shortOutputUint8, count: Int(outLength) * 2)
                sampOut += Int64(outLength)
            }
        }

        return sampOut
    }
    
    /// Add WAV headers to the decoded PCM data.
    /// Refer to the documentation here for details: http://soundfile.sapp.org/doc/WaveFormat/
    func addWAVHeader() {
        var header = Data()
        let headerSize = 44
        let pcmDataLength = pcmData.count
        let bitsPerSample = Int32(16)

        // RIFF chunk descriptor
        let chunkID = [UInt8]("RIFF".utf8)
        header.append(chunkID, count: 4)

        var chunkSize = Int32(pcmDataLength + headerSize - 4).littleEndian
        withUnsafePointer(to: &chunkSize) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        let format = [UInt8]("WAVE".utf8)
        header.append(format, count: 4)

        // "fmt" sub-chunk
        let subchunk1ID = [UInt8]("fmt ".utf8)
        header.append(subchunk1ID, count: 4)

        var subchunk1Size = Int32(16).littleEndian
        withUnsafePointer(to: &subchunk1Size) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var audioFormat = Int16(1).littleEndian
        withUnsafePointer(to: &audioFormat) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var headerNumChannels = Int16(numChannels).littleEndian
        withUnsafePointer(to: &headerNumChannels) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var headerSampleRate = Int32(sampleRate).littleEndian
        withUnsafePointer(to: &headerSampleRate) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var byteRate = Int32(sampleRate * numChannels * bitsPerSample / 8).littleEndian
        withUnsafePointer(to: &byteRate) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var blockAlign = Int16(numChannels * bitsPerSample / 8).littleEndian
        withUnsafePointer(to: &blockAlign) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        var headerBitsPerSample = Int16(bitsPerSample).littleEndian
        withUnsafePointer(to: &headerBitsPerSample) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        // "data" sub-chunk
        let subchunk2ID = [UInt8]("data".utf8)
        header.append(subchunk2ID, count: 4)

        var subchunk2Size = Int32(pcmDataLength).littleEndian
        withUnsafePointer(to: &subchunk2Size) { header.append(UnsafeBufferPointer(start: $0, count: 1)) }

        pcmDataWithHeaders.append(header)
        pcmDataWithHeaders.append(pcmData)
    }
}
