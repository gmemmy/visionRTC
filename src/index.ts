import NativeVisionRTC from './NativeVisionRtc';
import type {
  TrackOptions,
  VisionRTCTrack,
  VisionCameraSource,
  NativePixelSource,
  Resolution,
  Capabilities,
  VisionRtcError,
  TrackStats,
} from './types';
import VisionRTCView from './vision-rtc-view';

export type {
  TrackOptions,
  VisionRTCTrack,
  VisionCameraSource,
  NativePixelSource,
  Resolution,
  Capabilities,
  VisionRtcError,
  TrackStats,
};

export {VisionRTCView};

export async function createVisionCameraSource(
  viewTag: number
): Promise<VisionCameraSource> {
  return NativeVisionRTC.createVisionCameraSource(viewTag);
}

export function updateSource(
  sourceId: string,
  opts: {position?: 'front' | 'back'; torch?: boolean; maxFps?: number}
): Promise<void> {
  return NativeVisionRTC.updateSource(sourceId, opts);
}

export function disposeSource(sourceId: string): Promise<void> {
  return NativeVisionRTC.disposeSource(sourceId);
}

export async function createWebRTCTrack(
  source: VisionCameraSource | NativePixelSource,
  opts?: TrackOptions
): Promise<VisionRTCTrack> {
  return NativeVisionRTC.createTrack(source, opts ?? {});
}

export function replaceSenderTrack(
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

export function updateTrack(
  trackId: string,
  constraints: TrackOptions
): Promise<void> {
  return NativeVisionRTC.setTrackConstraints(trackId, constraints);
}

export function disposeTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.disposeTrack(trackId);
}

export async function getStats(
  _trackId?: string
): Promise<TrackStats | undefined> {
  if (_trackId && NativeVisionRTC.getStatsForTrack) {
    const s = await NativeVisionRTC.getStatsForTrack(_trackId);
    if (!s) return undefined;
    return s;
  }
  if (NativeVisionRTC.getStats) {
    const s = await NativeVisionRTC.getStats();
    if (!s) return undefined;
    return {
      producedFps: s.fps ?? 0,
      deliveredFps: s.fps ?? 0,
      droppedFrames: s.droppedFrames ?? 0,
    };
  }
  return undefined;
}

function detectExpoGo(): boolean {
  try {
    // Optional dependency; only if project uses Expo
    const Constants = require('expo-constants').default;
    return Constants?.appOwnership === 'expo';
  } catch {
    return false;
  }
}

function hasVisionCamera(): boolean {
  try {
    const vc = require('react-native-vision-camera');
    return !!vc;
  } catch {
    return false;
  }
}

export function getCapabilities(): Capabilities {
  const expoGo = detectExpoGo();
  const webrtc = !!NativeVisionRTC;
  const visionCamera = hasVisionCamera();
  const arkit = false;
  const hwEncoder = {
    h264: true,
    vp8: true,
  };
  return {webrtc, visionCamera, arkit, hwEncoder, expoGo};
}

export function assertSupportedOrThrow(): void {
  const caps = getCapabilities();
  if (caps.expoGo) {
    const err: VisionRtcError = {
      code: 'ERR_EXPO_GO',
      message: 'Expo Go is not supported. Use Expo Dev Client.',
    };
    throw err;
  }
  if (!caps.webrtc) {
    const err: VisionRtcError = {
      code: 'ERR_NATIVE_MODULE_UNAVAILABLE',
      message: 'VisionRTC native module not available.',
    };
    throw err;
  }
}
