import NativeVisionRTC from './NativeVisionRtc';
import type {
  TrackOptions,
  VisionRTCTrack,
  VisionCameraSource,
  NativePixelSource,
  Resolution,
} from './types';

export type {
  TrackOptions,
  VisionRTCTrack,
  VisionCameraSource,
  NativePixelSource,
  Resolution,
};

export async function createVisionCameraSource(
  viewTag: number
): Promise<VisionCameraSource> {
  return NativeVisionRTC.createVisionCameraSource(viewTag);
}

export async function createWebRTCTrack(
  source: VisionCameraSource | NativePixelSource,
  opts?: TrackOptions
): Promise<VisionRTCTrack> {
  return NativeVisionRTC.createTrack(source, opts ?? {});
}

export function replaceTrack(
  senderId: string,
  nextTrackId: string
): Promise<void> {
  return NativeVisionRTC.replaceSenderTrack(senderId, nextTrackId);
}

export function pauseTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.pauseTrack(trackId);
}

export function resumeTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.resumeTrack(trackId);
}

export function setTrackConstraints(
  trackId: string,
  opts: TrackOptions
): Promise<void> {
  return NativeVisionRTC.setTrackConstraints(trackId, opts);
}

export function disposeTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.disposeTrack(trackId);
}

export async function getStats(): Promise<
  {fps: number; droppedFrames: number; encoderQueueDepth?: number} | undefined
> {
  return NativeVisionRTC.getStats
    ? await NativeVisionRTC.getStats()
    : undefined;
}
