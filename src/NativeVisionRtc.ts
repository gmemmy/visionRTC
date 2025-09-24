import {TurboModuleRegistry, type TurboModule} from 'react-native';

type VisionCameraSourceShape = {__nativeSourceId: string};
type NativePixelSourceShape =
  | {platform: 'ios'; pixelBufferRef: unknown}
  | {
      platform: 'android';
      hardwareBufferRef?: unknown;
      surfaceTextureId?: number;
    };
type TrackOptionsShape = {
  fps?: number;
  resolution?: {width: number; height: number};
  mode?: 'null-gpu' | 'null-cpu' | 'external';
};

export interface Spec extends TurboModule {
  readonly createVisionCameraSource: (
    viewTag: number
  ) => Promise<VisionCameraSourceShape>;
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
}

export default TurboModuleRegistry.getEnforcing<Spec>('VisionRTC');
