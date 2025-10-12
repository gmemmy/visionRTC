import {TurboModuleRegistry, type TurboModule} from 'react-native';

type VisionCameraSourceShape = {__nativeSourceId: string};
type NativePixelSourceIOSShape = {
  platform: 'ios';
  pixelBufferRef: unknown;
};
type NativePixelSourceAndroidShape =
  | {
      platform: 'android';
      hardwareBufferRef: unknown;
      surfaceTextureId?: never;
    }
  | {
      platform: 'android';
      surfaceTextureId: number;
      hardwareBufferRef?: never;
    };
type NativePixelSourceShape =
  | NativePixelSourceIOSShape
  | NativePixelSourceAndroidShape;

type TrackResolutionShape = {width: number; height: number};
type TrackOptionsShape = {
  fps?: number;
  resolution?: TrackResolutionShape;
  backpressure?: 'drop-late' | 'latest-wins' | 'throttle';
  mode?: 'null-gpu' | 'null-cpu' | 'external';
};

export interface Spec extends TurboModule {
  readonly createVisionCameraSource: (
    viewTag: number
  ) => Promise<VisionCameraSourceShape>;
  readonly updateSource: (
    sourceId: string,
    opts: {position?: 'front' | 'back'; torch?: boolean; maxFps?: number}
  ) => Promise<void>;
  readonly disposeSource: (sourceId: string) => Promise<void>;
  readonly createTrack: (
    source: VisionCameraSourceShape | NativePixelSourceShape,
    opts?: TrackOptionsShape
  ) => Promise<{trackId: string}>;
  readonly replaceSenderTrack: (
    senderId: string,
    newTrackId: string
  ) => Promise<void>;
  readonly pauseTrack: (trackId: string) => Promise<void>;
  readonly resumeTrack: (trackId: string) => Promise<void>;
  readonly setTrackConstraints: (
    trackId: string,
    opts: TrackOptionsShape
  ) => Promise<void>;
  readonly disposeTrack: (trackId: string) => Promise<void>;

  readonly getStats?: () => Promise<{
    fps: number;
    droppedFrames: number;
    encoderQueueDepth?: number;
  }>;
  readonly getStatsForTrack?: (trackId: string) => Promise<{
    producedFps: number;
    deliveredFps: number;
    droppedFrames: number;
  }>;
  readonly deliverFrame?: (
    sourceId: string,
    pixelBuffer: unknown,
    timestampNs: number
  ) => Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('VisionRTC');
