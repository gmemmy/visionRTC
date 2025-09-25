export type Resolution = {width: number; height: number};

export type TrackOptions = {
  fps?: number; // default 30
  resolution?: Resolution;
  backpressure?: Backpressure;
  bitrate?: number;
  colorSpace?: 'auto' | 'sRGB' | 'BT.709' | 'BT.2020';
  orientationMode?: 'auto' | 'fixed-0' | 'fixed-90' | 'fixed-180' | 'fixed-270';
  mode?: 'null-gpu' | 'null-cpu' | 'external';
};

export type VisionCameraSource = {__nativeSourceId: string};

type NativePixelSourceIOS = {
  platform: 'ios';
  pixelBufferRef: unknown;
};

type NativePixelSourceAndroidHardwareBuffer = {
  platform: 'android';
  hardwareBufferRef: unknown;
  surfaceTextureId?: never;
};

type NativePixelSourceAndroidSurfaceTexture = {
  platform: 'android';
  surfaceTextureId: number;
  hardwareBufferRef?: never;
};

export type NativePixelSource =
  | NativePixelSourceIOS
  | NativePixelSourceAndroidHardwareBuffer
  | NativePixelSourceAndroidSurfaceTexture;

export type VisionRTCTrack = {
  trackId: string;
};

export type Backpressure = 'drop-late' | 'latest-wins' | 'throttle';

export type Capabilities = {
  webrtc: boolean;
  visionCamera: boolean;
  arkit: boolean;
  hwEncoder: {h264: boolean; vp8: boolean};
  expoGo: boolean;
};

export type VisionRtcErrorCode =
  | 'ERR_EXPO_GO'
  | 'ERR_MISSING_VISION_CAMERA'
  | 'ERR_UNSUPPORTED_PLATFORM'
  | 'ERR_NATIVE_MODULE_UNAVAILABLE';

export type VisionRtcError = {
  code: VisionRtcErrorCode;
  message: string;
};

export type TrackStats = {
  producedFps: number;
  deliveredFps: number;
  droppedFrames: number;
  bitrateKbps?: number;
  avgEncodeMs?: number;
  qp?: number;
};
