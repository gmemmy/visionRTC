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

const sourcesRegistry: Record<string, boolean> = {};
const processorsRegistry: Record<string, boolean> = {};

/**
 * Marks a capability (source or processor) as registered by name.
 * @param kind - The kind of capability ('source' or 'processor').
 * @param name - The name of the capability.
 * @private
 */
function markCapability(kind: 'source' | 'processor', name: string) {
  if (kind === 'source') {
    sourcesRegistry[name] = true;
  } else {
    processorsRegistry[name] = true;
  }
}

/**
 * Register a new source plugin by name.
 * This is called by plugins at initialization time.
 * @param name - Unique name for the plugin source.
 * @internal
 */
export const __registerSource = (name: string): void => {
  markCapability('source', name);
};

/**
 * Register a new processor plugin by name.
 * This is called by plugins at initialization time.
 * @param name - Unique name for the plugin processor.
 * @internal
 */
export const __registerProcessor = (name: string): void => {
  markCapability('processor', name);
};

type VisionCameraPluginDescriptor = {
  name: 'visioncamera';
};

let visionCameraPlugin: VisionCameraPluginDescriptor | null = null;

/**
 * Register the VisionCamera plugin as a source.
 * This is called by @visionrtc/source-visioncamera on import.
 * @internal
 */
export const __registerVisionCameraPlugin = (): void => {
  visionCameraPlugin = {name: 'visioncamera'};
  __registerSource(visionCameraPlugin.name);
};

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

const PLUGIN_MISSING_ERROR: VisionRtcError = {
  code: 'E_PLUGIN_MISSING',
  message:
    'VisionRTC VisionCamera source requires the @visionrtc/source-visioncamera plugin. Install and autolink the plugin, then rebuild the native app.',
};

/**
 * Creates a VisionCamera source handle for streaming frames from a VisionCamera view.
 * @param viewTag - The native view tag of the VisionCamera component.
 * @returns A Promise that resolves to a VisionCameraSource.
 * @throws If the VisionCamera plugin is not registered (i.e. @visionrtc/source-visioncamera not imported).
 */
export async function createVisionCameraSource(
  viewTag: number
): Promise<VisionCameraSource> {
  if (!visionCameraPlugin) {
    try {
      // Attempt to load and register the plugin lazily. If the package isn't installed, we'll throw later.
      require('@visionrtc/source-visioncamera/register');
    } catch {}
  }
  if (!visionCameraPlugin) {
    throw PLUGIN_MISSING_ERROR;
  }
  return NativeVisionRTC.createVisionCameraSource(viewTag);
}

/**
 * Updates the properties of a registered source such as camera position, torch state, or maximum fps.
 * @param sourceId - The source handle/id to update.
 * @param opts - Options: position (front/back), torch, maxFps.
 * @returns Promise that resolves when update completes.
 */
export function updateSource(
  sourceId: string,
  opts: {position?: 'front' | 'back'; torch?: boolean; maxFps?: number}
): Promise<void> {
  return NativeVisionRTC.updateSource(sourceId, opts);
}

/**
 * Disposes the given source, freeing native resources.
 * @param sourceId - The identifier of the source to dispose.
 * @returns Promise that resolves when disposal is complete.
 */
export function disposeSource(sourceId: string): Promise<void> {
  return NativeVisionRTC.disposeSource(sourceId);
}

/**
 * Creates a new WebRTC track from a source.
 * @param source - The source (VisionCameraSource or NativePixelSource) to stream from.
 * @param opts - Track options such as fps, resolution, colorSpace, etc.
 * @returns Promise resolving to a VisionRTCTrack (trackId).
 */
export async function createWebRTCTrack(
  source: VisionCameraSource | NativePixelSource,
  opts?: TrackOptions
): Promise<VisionRTCTrack> {
  return NativeVisionRTC.createTrack(source, opts ?? {});
}

/**
 * Replaces the track for a given WebRTC sender with a new track.
 * @param senderId - The WebRTC sender to replace the track on.
 * @param nextTrackId - The id of the new track.
 * @returns Promise that resolves when replacement is complete.
 */
export function replaceSenderTrack(
  senderId: string,
  nextTrackId: string
): Promise<void> {
  return NativeVisionRTC.replaceSenderTrack(senderId, nextTrackId);
}

/**
 * Pauses streaming for a track (frames are not sent).
 * @param trackId - The id of the track to pause.
 * @returns Promise that resolves when the track is paused.
 */
export function pauseTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.pauseTrack(trackId);
}

/**
 * Resumes streaming for a paused track.
 * @param trackId - The id of the track to resume.
 * @returns Promise that resolves when the track is resumed.
 */
export function resumeTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.resumeTrack(trackId);
}

/**
 * Updates (sets) constraints such as fps, resolution, or bitrate on an active track.
 * @param trackId - The id of the track to update.
 * @param constraints - New constraints (TrackOptions) to apply to the track.
 * @returns Promise that resolves when the constraints are set.
 */
export function updateTrack(
  trackId: string,
  constraints: TrackOptions
): Promise<void> {
  return NativeVisionRTC.setTrackConstraints(trackId, constraints);
}

/**
 * Disposes and tears down an active WebRTC track, freeing native resources.
 * @param trackId - The id of the track to dispose.
 * @returns Promise that resolves when the track is disposed.
 */
export function disposeTrack(trackId: string): Promise<void> {
  return NativeVisionRTC.disposeTrack(trackId);
}

/**
 * (Native VisionCamera plugin) Deliver a single frame with pixel data from JS/worklets to native.
 * Used internally by frame processors.
 * @param sourceId - The VisionCamera source ID.
 * @param pixelBuffer - The native reference to the pixel buffer (platform-specific).
 * @param timestampNs - The timestamp in nanoseconds for the frame.
 * @returns Promise that resolves when frame is delivered.
 * @throws If deliverFrame is not implemented in the native module.
 */
export async function deliverFrame(
  sourceId: string,
  pixelBuffer: unknown,
  timestampNs: number
): Promise<void> {
  if (!NativeVisionRTC.deliverFrame) {
    throw new Error('VisionRTC native module missing deliverFrame support');
  }
  return NativeVisionRTC.deliverFrame(sourceId, pixelBuffer, timestampNs);
}

/**
 * Gets runtime stats such as producedFps, deliveredFps, and droppedFrames.
 * If a trackId is provided and supported, gets stats for that track.
 * @param _trackId - (Optional) The id of the track to query stats for.
 * @returns Promise resolving to TrackStats or undefined if stats not available.
 */
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

/**
 * Returns the capabilities of the runtime environment and VisionRTC plugins.
 * Includes info about which sources, processors, and encoders are available.
 * @returns Capabilities object describing supported features.
 */
export function getCapabilities(): Capabilities {
  const expoGo = detectExpoGo();
  const webrtc = !!NativeVisionRTC;
  const arkit = false;
  const hwEncoder = {
    h264: true,
    vp8: true,
  };
  return {
    webrtc,
    sources: {...sourcesRegistry},
    processors: {...processorsRegistry},
    visionCamera: sourcesRegistry.visioncamera ?? false,
    arkit,
    hwEncoder,
    expoGo,
  };
}

/**
 * Checks if the runtime/platform is supported and throws if not.
 * Throws a specific error if running on Expo Go or if the native module is missing.
 * @throws VisionRtcError if the environment is not supported.
 */
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
