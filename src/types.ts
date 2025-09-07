export type Resolution = {width: number; height: number};

export type TrackOptions = {
  fps?: number; // default 30
  resolution?: Resolution;
  bitrate?: number;
  colorSpace?: 'auto' | 'sRGB' | 'BT.709' | 'BT.2020';
  orientationMode?: 'auto' | 'fixed-0' | 'fixed-90' | 'fixed-180' | 'fixed-270';
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
