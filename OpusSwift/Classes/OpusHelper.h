//
//  OpusHelper.h
//  OpusSwift
//
//  Created by Marcelo Sarquis on 02.11.22.
//

#import <Foundation/Foundation.h>
#import "opus.h"

NS_ASSUME_NONNULL_BEGIN

@interface OpusHelper : NSObject

- (void)setBitrate:(NSUInteger)bitrate encoder:(OpusEncoder *)encoder;
- (void)setComplexity:(NSUInteger)complexity encoder:(OpusEncoder *)encoder;
- (void)setSignal:(NSUInteger)signal encoder:(OpusEncoder *)encoder;
- (void)setPacketLossPerc:(NSUInteger)packageLoss encoder:(OpusEncoder *)encoder;
- (void)setInBandFec:(NSUInteger)inBandFec encoder:(OpusEncoder *)encoder;

/// Set new Bandwidth
///
/// 4 kHz bandpass - OPUS_BANDWIDTH_NARROWBAND: 1101
///
/// 6 kHz bandpass - OPUS_BANDWIDTH_MEDIUMBAND: 1102
///
/// 8 kHz bandpass - OPUS_BANDWIDTH_WIDEBAND: 1103
///
/// 12 kHz bandpass - OPUS_BANDWIDTH_SUPERWIDEBAND: 1104
/// 
/// 20 kHz bandpass - OPUS_BANDWIDTH_FULLBAND: 1105
- (void)setBandwidth:(NSUInteger)bandwidth encoder:(OpusEncoder *)encoder;

/// Set new frame size
///
/// Select frame size from the argument (default) - OPUS_FRAMESIZE_ARG: 5000
///
/// Use 2.5 ms frames - OPUS_FRAMESIZE_2_5_MS: 5001
///
/// Use 5 ms frames - OPUS_FRAMESIZE_5_MS: 5002
///
/// Use 10 ms frames - OPUS_FRAMESIZE_10_MS: 5003
///
/// Use 20 ms frames - OPUS_FRAMESIZE_20_MS: 5004
///
/// Use 40 ms frames - OPUS_FRAMESIZE_40_MS: 5005
///
/// Use 60 ms frames - OPUS_FRAMESIZE_60_MS: 5006
///
/// Use 80 ms frames - OPUS_FRAMESIZE_80_MS: 5007
///
/// Use 100 ms frames - OPUS_FRAMESIZE_100_MS: 5008
///
/// Use 120 ms frames - OPUS_FRAMESIZE_120_MS: 5009
- (void)setFrameSize:(NSUInteger)frameSize encoder:(OpusEncoder *)encoder;

- (void)setLsbDepth:(NSUInteger)lsbDepth encoder:(OpusEncoder *)encoder;

@end

NS_ASSUME_NONNULL_END
