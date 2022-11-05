//
//  OpusEncoder.swift
//  OpusSwift
//
//  Created by Marcelo Sarquis on 14.10.22.
//

import Foundation

public protocol OpusEncoderProtocol {
    func encode(pcm: Data) throws
    func bitstream(flush: Bool, fillBytes: Int32?) -> Data
    func endstream(fillBytes: Int32?) throws -> Data
}

/// This implementation uses the libopus and libogg libraries to encode and encapsulate audio.
/// For more information about these libraries, refer to their online documentation.
/// (The opus-tools source code was also helpful to verify the implementation.)
public final class OpusEncoder: OpusEncoderProtocol {
    
    private typealias opus_encoder = OpaquePointer
    
    private let opusHelper = OpusHelper()
    
    /// state of the ogg stream
    private var stream: ogg_stream_state
    /// encoder to convert pcm to opus
    private var encoder: opus_encoder
    /// total number of encoded pcm samples in the stream
    private var granulePosition: Int64
    /// total number of packets encoded in the stream
    private var packetNumber: Int64
    /// number of pcm frames to encode in an opus frame (20ms)
    private let frameSize: Int32
    /// maximum size of an opus frame
    private var maxFrameSize: Int32 { 6 * frameSize }
    /// desired sample rate of the opus audio
    private let opusRate: Int32
    /// bytes per frame in the pcm audio
    private let pcmBytesPerFrame: UInt32
    /// cache for pcm audio that is too short to encode
    private var pcmCache = Data()
    /// cache for ogg stream
    private var oggCache = Data()
    
    public init(pcmRate: Int32, pcmChannels: Int32, pcmBytesPerFrame: UInt32, opusRate: Int32, application: OpusApplication) throws {
        // avoid resampling
        guard pcmRate == opusRate else {
            print("Resampling is not supported. Please ensure that the PCM and Opus sample rates match.")
            throw OggError.internalError
        }
        
        // set properties
        self.granulePosition = 0
        self.packetNumber = 0
        self.frameSize = Int32(960 / (24000 / opusRate))
        self.opusRate = opusRate
        self.pcmBytesPerFrame = pcmBytesPerFrame
        self.pcmCache = Data()
        
        // create status to capture errors
        var status = Int32(0)
        
        // initialize ogg stream
        stream = ogg_stream_state()
        let serial = Int32(bitPattern: arc4random())
        status = ogg_stream_init(&stream, serial)
        guard status == 0 else {
            throw OggError.internalError
        }
        
        // initialize opus encoder
        encoder = opus_encoder_create(opusRate, pcmChannels, application.rawValue, &status)
        guard let error = OpusError(rawValue: status) else {
            throw OpusError.internalError
        }
        guard error == .okay else {
            throw error
        }
        
        opusHelper.setFrameSize(UInt(OPUS_FRAMESIZE_20_MS), encoder: encoder)
        
        // add opus headers to ogg stream
        try addOpusHeader(channels: UInt8(pcmChannels), rate: UInt32(pcmRate))
        try addOpusCommentHeader()
    }
    
    deinit {
        // ogg_stream_destroy(&stream)
        opus_encoder_destroy(encoder)
    }
    
    public func encode(pcm: Data) throws {
        guard let inputDataBytes = pcm.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to: Int16.self) }) else {
            throw OpusError.allocationFailure
        }
        try encode(pcm: inputDataBytes, count: pcm.count)
    }
    
    public func bitstream(flush: Bool = false, fillBytes: Int32? = nil) -> Data {
        assemblePages(flush: flush, fillBytes: fillBytes)
        let bitstream = oggCache
        oggCache = Data()
        return bitstream
    }
    
    public func endstream(fillBytes: Int32? = nil) throws -> Data {
        // compute granule position using cache
        let pcmFrames = pcmCache.count / Int(pcmBytesPerFrame)
        granulePosition += Int64(pcmFrames * 24000 / Int(opusRate))
        
        // add padding to cache to construct complete frame
        let toAppend = Int(frameSize) * Int(pcmBytesPerFrame) - pcmCache.count
        let padding = [UInt8](repeating: 0, count: toAppend)
        pcmCache.append(padding, count: toAppend)
        
        // encode an opus frame
        var opus = [UInt8](repeating: 0, count: Int(maxFrameSize))
        guard let cache = pcmCache.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to: Int16.self) }) else {
            throw OpusError.allocationFailure
        }
        let numBytes = opus_encode(encoder, cache, frameSize, &opus, maxFrameSize)
        guard numBytes >= 0 else {
            throw OpusError.internalError
        }
        
        // construct ogg packet with opus frame
        let packetPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: opus.count)
        packetPointer.initialize(from: &opus, count: opus.count)
        var packet = ogg_packet()
        packet.packet = packetPointer
        packet.bytes = Int(numBytes)
        packet.b_o_s = 0
        packet.e_o_s = 1
        packet.granulepos = granulePosition
        packet.packetno = Int64(packetNumber)
        packetNumber += 1
        
        // add packet to ogg stream
        let status = ogg_stream_packetin(&stream, &packet)
        guard status == 0 else {
            throw OggError.internalError
        }
        
        return bitstream(flush: true)
    }
}

private extension OpusEncoder {
    func encode(pcm: UnsafePointer<Int16>, count: Int) throws {
        // ensure we have complete pcm frames
        guard UInt32(count) % pcmBytesPerFrame == 0 else {
            throw OpusError.internalError
        }
        
        // construct audio buffers
        var pcm = UnsafeMutablePointer<Int16>(mutating: pcm)
        var opus = [UInt8](repeating: 0, count: Int(maxFrameSize))
        var count = count
        
        // encode cache, if necessary
        try encodeCache(pcm: &pcm, bytes: &count)
        
        // encode complete frames
        while count >= Int(frameSize) * Int(pcmBytesPerFrame) {
            
            // encode an opus frame
            let numBytes = opus_encode(encoder, pcm, frameSize, &opus, maxFrameSize)
            guard numBytes >= 0 else {
                throw OpusError.internalError
            }
            
            // construct ogg packet with opus frame
            let packetPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: opus.count)
            packetPointer.initialize(from: &opus, count: opus.count)
            var packet = ogg_packet()
            granulePosition += Int64(frameSize * 24000 / opusRate)
            packet.packet = packetPointer
            packet.bytes = Int(numBytes)
            packet.b_o_s = 0
            packet.e_o_s = 0
            packet.granulepos = granulePosition
            packet.packetno = Int64(packetNumber)
            packetNumber += 1
            
            // add packet to ogg stream
            let status = ogg_stream_packetin(&stream, &packet)
            guard status == 0 else {
                throw OggError.internalError
            }
            
            // advance pcm buffer
            let bytesEncoded = Int(frameSize) * Int(pcmBytesPerFrame)
            pcm = pcm.advanced(by: bytesEncoded / MemoryLayout<Int16>.stride)
            count -= bytesEncoded
        }
        
        // cache remaining pcm data
        pcm.withMemoryRebound(to: UInt8.self, capacity: count) { data in
            pcmCache.append(data, count: count)
        }
    }
    
    func addOpusHeader(channels: UInt8, rate: UInt32) throws {
        // construct opus header
        let header = Header(
            outputChannels: channels,
            preskip: 0,
            inputSampleRate: rate,
            outputGain: 0,
            channelMappingFamily: .rtp
        )
        
        // convert header to a data buffer
        let headerData = header.toData()
        let packetData = UnsafeMutablePointer<UInt8>.allocate(capacity: headerData.count)
        headerData.copyBytes(to: packetData, count: headerData.count)
        
        // construct ogg packet with header
        var packet = ogg_packet()
        packet.packet = packetData
        packet.bytes = headerData.count
        packet.b_o_s = 1
        packet.e_o_s = 0
        packet.granulepos = granulePosition
        packet.packetno = Int64(packetNumber)
        packetNumber += 1
        
        // add packet to ogg stream
        let status = ogg_stream_packetin(&stream, &packet)
        guard status == 0 else {
            throw OggError.internalError
        }
        
        // deallocate header data buffer
        packetData.deallocate()
        
        // assemble pages and add to ogg cache
        assemblePages(flush: true)
    }
    
    func addOpusCommentHeader() throws {
        // construct opus comment header
        let header = CommentHeader()
        let headerData = header.toData()
        let packetData = UnsafeMutablePointer<UInt8>.allocate(capacity: headerData.count)
        headerData.copyBytes(to: packetData, count: headerData.count)
        
        // construct ogg packet with comment header
        var packet = ogg_packet()
        packet.packet = packetData
        packet.bytes = headerData.count
        packet.b_o_s = 0
        packet.e_o_s = 0
        packet.granulepos = granulePosition
        packet.packetno = Int64(packetNumber)
        packetNumber += 1
        
        // add packet to ogg stream
        let status = ogg_stream_packetin(&stream, &packet)
        guard status == 0 else {
            throw OggError.internalError
        }
        
        // deallocate header data buffer
        packetData.deallocate()
        
        // assemble pages and add to ogg cache
        assemblePages(flush: true)
    }
    
    func encodeCache(pcm: inout UnsafeMutablePointer<Int16>, bytes: inout Int) throws {
        // ensure there is cached data
        guard pcmCache.count > 0 else {
            return
        }
        
        // ensure we can add enough pcm data for a complete frame
        guard pcmCache.count + bytes >= Int(frameSize) * Int(pcmBytesPerFrame) else {
            return
        }
        
        // append pcm data to create a complete frame
        let toAppend = Int(frameSize) * Int(pcmBytesPerFrame) - pcmCache.count
        pcm.withMemoryRebound(to: UInt8.self, capacity: toAppend) { data in
            pcmCache.append(data, count: toAppend)
        }
        
        // advance pcm buffer (modifies the inout arguments)
        pcm = pcm.advanced(by: toAppend / MemoryLayout<Int16>.stride)
        bytes -= toAppend
        
        // encode an opus frame
        var opus = [UInt8](repeating: 0, count: Int(maxFrameSize))
        guard let cache = pcmCache.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to: Int16.self) }) else {
            throw OpusError.allocationFailure
        }
        let numBytes = opus_encode(encoder, cache, frameSize, &opus, maxFrameSize)
        guard numBytes >= 0 else {
            throw OpusError.internalError
        }
        
        // construct ogg packet with opus frame
        let packetPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: opus.count)
        packetPointer.initialize(from: &opus, count: opus.count)
        var packet = ogg_packet()
        granulePosition += Int64(frameSize * 24000 / opusRate)
        packet.packet = packetPointer
        packet.bytes = Int(numBytes)
        packet.b_o_s = 0
        packet.e_o_s = 0
        packet.granulepos = granulePosition
        packet.packetno = Int64(packetNumber)
        packetNumber += 1
        
        // add packet to ogg stream
        let status = ogg_stream_packetin(&stream, &packet)
        guard status == 0 else {
            throw OggError.internalError
        }
        
        // reset cache
        pcmCache = Data()
    }
    
    func assemblePages(flush: Bool = false, fillBytes: Int32? = nil) {
        var page = ogg_page()
        var status = Int32(1)
        
        // assemble pages until there is insufficient data to fill a page
        while true {
            
            // assemble accumulated packets into an ogg page
            switch (flush, fillBytes) {
            case (true, .some(let fillBytes)):
                status = ogg_stream_flush_fill(&stream, &page, fillBytes)
            case (true, .none):
                status = ogg_stream_flush(&stream, &page)
            case (false, .some(let fillBytes)):
                status = ogg_stream_pageout_fill(&stream, &page, fillBytes)
            case (false, .none):
                status = ogg_stream_pageout(&stream, &page)
            }
            
            // break when all packet data has been accumulated into pages
            guard status != 0 else {
                return
            }
            
            // add ogg page to cache
            oggCache.append(page.header, count: page.header_len)
            oggCache.append(page.body, count: page.body_len)
        }
    }
}

// MARK: - Header
private class Header {
    private(set) var magicSignature: [UInt8]
    private(set) var version: UInt8
    private(set) var outputChannels: UInt8
    private(set) var preskip: UInt16
    private(set) var inputSampleRate: UInt32
    private(set) var outputGain: Int16
    private(set) var channelMappingFamily: ChannelMappingFamily
    
    init(outputChannels: UInt8, preskip: UInt16, inputSampleRate: UInt32, outputGain: Int16, channelMappingFamily: ChannelMappingFamily) {
        self.magicSignature = [ 0x4f, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64 ] // "OpusHead"
        self.version = 1 // must always be `1` for this version of the encapsulation specification
        self.outputChannels = outputChannels
        self.preskip = preskip
        self.inputSampleRate = inputSampleRate
        self.outputGain = outputGain
        self.channelMappingFamily = channelMappingFamily
    }
    
    func toData() -> Data {
        var data = Data()
        data.append(magicSignature, count: magicSignature.count)
        withUnsafePointer(to: &version) { ptr in
            data.append(ptr, count: MemoryLayout<UInt8>.size)
        }
        withUnsafePointer(to: &outputChannels) { ptr in
            data.append(ptr, count: MemoryLayout<UInt8>.size)
        }
        withUnsafePointer(to: &preskip) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt16>.size)
            }
        }
        withUnsafePointer(to: &inputSampleRate) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt32>.size)
            }
        }
        withUnsafePointer(to: &outputGain) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt16>.size)
            }
        }
        withUnsafePointer(to: &channelMappingFamily) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<ChannelMappingFamily>.size)
            }
        }
        return data
    }
}

// MARK: - Comment Header
private class CommentHeader {
    private(set) var magicSignature: [UInt8]
    private(set) var vendorStringLength: UInt32
    private(set) var vendorString: String
    private(set) var userCommentListLength: UInt32
    private(set) var userComments: [Comment]
    
    init() {
        magicSignature = [ 0x4f, 0x70, 0x75, 0x73, 0x54, 0x61, 0x67, 0x73 ] // "OpusTags"
        vendorString = String(validatingUTF8: opus_get_version_string())!
        vendorStringLength = UInt32(vendorString.count)
        userComments = [Comment(tag: "ENCODER", value: "IBM Mobile Innovation Lab")]
        userCommentListLength = UInt32(userComments.count)
    }
    
    func toData() -> Data {
        var data = Data()
        data.append(magicSignature, count: magicSignature.count)
        withUnsafePointer(to: &vendorStringLength) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt32>.size)
            }
        }
        data.append(vendorString.data(using: String.Encoding.utf8)!)
        withUnsafePointer(to: &userCommentListLength) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt32>.size)
            }
        }
        for comment in userComments {
            data.append(comment.toData())
        }
        return data
    }
}

// MARK: - Comment
private class Comment {
    private(set) var length: UInt32
    private(set) var comment: String
    
    fileprivate init(tag: String, value: String) {
        comment = "\(tag)=\(value)"
        length = UInt32(comment.count)
    }
    
    fileprivate func toData() -> Data {
        var data = Data()
        withUnsafePointer(to: &length) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr in
                data.append(ptr, count: MemoryLayout<UInt32>.size)
            }
        }
        data.append(comment.data(using: String.Encoding.utf8)!)
        return data
    }
}

// MARK: - ChannelMappingFamily
private enum ChannelMappingFamily: UInt8 {
    case rtp = 0
    case vorbis = 1
    case undefined = 255
}
