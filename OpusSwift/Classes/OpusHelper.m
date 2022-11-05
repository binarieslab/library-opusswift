//
//  OpusHelper.m
//  OpusSwift
//
//  Created by Marcelo Sarquis on 02.11.22.
//

#import "OpusHelper.h"

@interface OpusHelper()

@property (nonatomic,strong) dispatch_queue_t processingQueue;

@end

@implementation OpusHelper

- (instancetype)init
{
    if (self = [super init]) {
        _processingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        dispatch_set_target_queue(_processingQueue, dispatch_queue_create("com.binarieslab.opusswift.processingqueue", DISPATCH_QUEUE_SERIAL));
    }
    
    return self;
}

- (void)setBitrate:(NSUInteger)bitrate encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_BITRATE(bitrate));
    });
}

- (void)setComplexity:(NSUInteger)complexity encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_COMPLEXITY(complexity));
    });
}

- (void)setSignal:(NSUInteger)signal encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_SIGNAL(signal));
    });
}

- (void)setPacketLossPerc:(NSUInteger)packageLoss encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_PACKET_LOSS_PERC(packageLoss));
    });
}

- (void)setInBandFec:(NSUInteger)inBandFec encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_INBAND_FEC(inBandFec));
    });
}

- (void)setBandwidth:(NSUInteger)bandwidth encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_BANDWIDTH(bandwidth));
    });
}

- (void)setFrameSize:(NSUInteger)frameSize encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_EXPERT_FRAME_DURATION(frameSize));
    });
}

- (void)setLsbDepth:(NSUInteger)lsbDepth encoder:(OpusEncoder *)encoder
{
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(encoder, OPUS_SET_LSB_DEPTH(lsbDepth));
    });
}



@end
