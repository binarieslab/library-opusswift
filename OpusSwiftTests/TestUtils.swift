//
//  TestUtils.swift
//  OpusSwiftTests
//
//  Created by Marcelo Sarquis on 28.10.22.
//

import Foundation

private final class TestUtilsClass {}

enum TestUtils: String {
    case opusfile
    case pcmfile
    
    var fileExtension: String? {
        switch self {
        case .opusfile: return "ogg"
        case .pcmfile: return "wav"
        }
    }

    var data: Data {
        guard let data = try? Data(contentsOf: url) else {
            fatalError("No file found")
        }
        return data
    }

    var url: URL {
        guard
            let url = Bundle(for: TestUtilsClass.self)
            .url(forResource: rawValue, withExtension: fileExtension)
        else {
            fatalError("No file found")
        }
        return url
    }

    var string: String {
        String(decoding: data, as: UTF8.self)
    }

    var stringTrimmingWhitespacesAndNewlines: String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
