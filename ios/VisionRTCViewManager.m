#import <React/RCTViewManager.h>
#import <WebRTC/WebRTC.h>
#import "VisionRTCRegistryBridge.h"

@interface VisionRTCView : RTCMTLVideoView
@property(nonatomic, copy) NSString *trackId;
@property(nonatomic, strong) RTCVideoTrack *attachedTrack;
@end

@implementation VisionRTCView
- (void)setTrackId:(NSString *)trackId {
  if ([_trackId isEqualToString:trackId]) { return; }
  _trackId = [trackId copy];

  if (self.attachedTrack) {
    [self.attachedTrack removeRenderer:self];
    self.attachedTrack = nil;
  }

  if (_trackId.length > 0) {
    RTCVideoTrack *track = VisionRTCGetTrackFor(_trackId);
    if (track) {
      self.contentMode = UIViewContentModeScaleAspectFit;
      [track addRenderer:self];
      self.attachedTrack = track;
    }
  }
}
@end

@interface VisionRTCViewManager : RCTViewManager
@end

@implementation VisionRTCViewManager

RCT_EXPORT_MODULE(VisionRTCView)

- (UIView *)view
{
  return [VisionRTCView new];
}

RCT_EXPORT_VIEW_PROPERTY(trackId, NSString)

@end
