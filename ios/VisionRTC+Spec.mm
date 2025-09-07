#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import "VisionRtcSpec/VisionRtcSpec.h"
#import <ReactCommon/RCTTurboModule.h>
#import <WebRTC/WebRTC.h>

@protocol VisionRTCExports <NSObject>
- (void)createVisionCameraSource:(NSNumber *)viewTag
                         resolver:(RCTPromiseResolveBlock)resolve
                         rejecter:(RCTPromiseRejectBlock)reject;
- (void)createTrack:(NSDictionary *)source
               opts:(NSDictionary *)opts
            resolver:(RCTPromiseResolveBlock)resolve
            rejecter:(RCTPromiseRejectBlock)reject;
- (void)replaceSenderTrack:(NSString *)senderId
                newTrackId:(NSString *)newTrackId
                   resolver:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject;
- (void)pauseTrack:(NSString *)trackId
           resolver:(RCTPromiseResolveBlock)resolve
           rejecter:(RCTPromiseRejectBlock)reject;
- (void)resumeTrack:(NSString *)trackId
            resolver:(RCTPromiseResolveBlock)resolve
            rejecter:(RCTPromiseRejectBlock)reject;
- (void)setTrackConstraints:(NSString *)trackId
                       opts:(NSDictionary *)opts
                    resolver:(RCTPromiseResolveBlock)resolve
                    rejecter:(RCTPromiseRejectBlock)reject;
- (void)disposeTrack:(NSString *)trackId
              resolver:(RCTPromiseResolveBlock)resolve
              rejecter:(RCTPromiseRejectBlock)reject;
- (void)getStats:(RCTPromiseResolveBlock)resolve
          rejecter:(RCTPromiseRejectBlock)reject;
@end

@interface VisionRTCTurbo : NSObject <NativeVisionRtcSpec>
@property(nonatomic, strong) id<VisionRTCExports> swift;
@end

@implementation VisionRTCTurbo

RCT_EXPORT_MODULE(VisionRTC)

- (instancetype)init {
  if (self = [super init]) {
    Class swiftClass = NSClassFromString(@"VisionRtc.VisionRTC");
    if (swiftClass == nil) {
      swiftClass = NSClassFromString(@"VisionRTC");
    }
    _swift = swiftClass ? [swiftClass new] : nil;
  }
  return self;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeVisionRtcSpecJSI>(params);
}

- (void)createVisionCameraSource:(double)viewTag
                         resolve:(RCTPromiseResolveBlock)resolve
                          reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift createVisionCameraSource:@(viewTag) resolver:resolve rejecter:reject];
}

- (void)createTrack:(NSDictionary *)source
               opts:(JS::NativeVisionRtc::TrackOptionsShape &)opts
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  NSMutableDictionary *optsDict = [NSMutableDictionary dictionary];
  if (auto fps = opts.fps()) {
    optsDict[@"fps"] = @(*fps);
  }
  if (auto res = opts.resolution()) {
    NSMutableDictionary *resDict = [NSMutableDictionary dictionary];
    resDict[@"width"] = @((*res).width());
    resDict[@"height"] = @((*res).height());
    optsDict[@"resolution"] = resDict;
  }
  [self.swift createTrack:source opts:optsDict resolver:resolve rejecter:reject];
}

- (void)replaceSenderTrack:(NSString *)senderId
                newTrackId:(NSString *)newTrackId
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift replaceSenderTrack:senderId newTrackId:newTrackId resolver:resolve rejecter:reject];
}

- (void)pauseTrack:(NSString *)trackId
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift pauseTrack:trackId resolver:resolve rejecter:reject];
}

- (void)resumeTrack:(NSString *)trackId
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift resumeTrack:trackId resolver:resolve rejecter:reject];
}

- (void)setTrackConstraints:(NSString *)trackId
                       opts:(JS::NativeVisionRtc::TrackOptionsShape &)opts
                    resolve:(RCTPromiseResolveBlock)resolve
                     reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  NSMutableDictionary *optsDict = [NSMutableDictionary dictionary];
  if (auto fps = opts.fps()) {
    optsDict[@"fps"] = @(*fps);
  }
  if (auto res = opts.resolution()) {
    NSMutableDictionary *resDict = [NSMutableDictionary dictionary];
    resDict[@"width"] = @((*res).width());
    resDict[@"height"] = @((*res).height());
    optsDict[@"resolution"] = resDict;
  }
  [self.swift setTrackConstraints:trackId opts:optsDict resolver:resolve rejecter:reject];
}

- (void)disposeTrack:(NSString *)trackId
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift disposeTrack:trackId resolver:resolve rejecter:reject];
}

- (void)getStats:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  if (!self.swift) {
    if (reject) reject(@"E_NO_SWIFT_IMPL",
                       @"VisionRTC Swift implementation not found. Ensure @objc(VisionRTC) exists in module 'VisionRtc'.",
                       nil);
    return;
  }
  [self.swift getStats:resolve rejecter:reject];
}

@end