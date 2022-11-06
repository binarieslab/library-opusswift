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
- (void)setBandwidth:(NSUInteger)bandwidth encoder:(OpusEncoder *)encoder;
- (void)setFrameSize:(NSUInteger)frameSize encoder:(OpusEncoder *)encoder;
- (void)setLsbDepth:(NSUInteger)lsbDepth encoder:(OpusEncoder *)encoder;

@end

NS_ASSUME_NONNULL_END
