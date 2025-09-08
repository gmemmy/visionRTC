#import "VisionRTCRegistryBridge.h"
#import <WebRTC/WebRTC.h>
#import <objc/message.h>

RTCVideoTrack * _Nullable VisionRTCGetTrackFor(NSString * _Nonnull trackId) {
  Class registryClass = NSClassFromString(@"VisionRtc.VisionRTCTrackRegistry");
  if (registryClass == nil) {
    registryClass = NSClassFromString(@"VisionRTCTrackRegistry");
  }
  if (registryClass == nil) { return nil; }

  SEL sharedSel = NSSelectorFromString(@"shared");
  if (![registryClass respondsToSelector:sharedSel]) { return nil; }
  id shared = ((id (*)(id, SEL))objc_msgSend)(registryClass, sharedSel);
  if (shared == nil) { return nil; }

  SEL trackForSel = NSSelectorFromString(@"trackFor:");
  if (![shared respondsToSelector:trackForSel]) { return nil; }
  RTCVideoTrack *track = ((RTCVideoTrack * (*)(id, SEL, NSString *))objc_msgSend)(shared, trackForSel, trackId);
  return track;
}