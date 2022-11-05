//
//  OpusApplication.swift
//  OpusSwift
//
//  Created by Marcelo Sarquis on 14.10.22.
//

import Foundation

public enum OpusApplication {
    case voip
    case audio
    case lowDelay

    public var rawValue: Int32 {
        switch self {
        case .voip:
            return OPUS_APPLICATION_VOIP
        case .audio:
            return OPUS_APPLICATION_AUDIO
        case .lowDelay:
            return OPUS_APPLICATION_RESTRICTED_LOWDELAY
        }
    }

    public init?(rawValue: Int32) {
        switch rawValue {
        case OPUS_APPLICATION_VOIP:
            self = .voip
        case OPUS_APPLICATION_AUDIO:
            self = .audio
        case OPUS_APPLICATION_RESTRICTED_LOWDELAY:
            self = .lowDelay
        default:
            return nil
        }
    }
}
