# react-native-vision-rtc

React Native library for streaming Vision Camera, ARKit, OpenCV, or ML frames over WebRTC.

## Installation


```sh
npm install react-native-vision-rtc
```


## Usage


```ts
import {
  createVisionCameraSource,
  createWebRTCTrack,
  disposeTrack,
  getStats,
} from 'react-native-vision-rtc';

async function demo(reactTag: number) {
  const source = await createVisionCameraSource(reactTag);
  const { trackId } = await createWebRTCTrack(source, {
    fps: 30,
    resolution: { width: 1280, height: 720 },
  });

  const stats = (await getStats?.()) ?? null;
  await disposeTrack(trackId);
  return stats;
}

// Example invocation:
// demo(findNodeHandle(cameraRef));
```

### API

- **Functions**
  - `createVisionCameraSource(viewTag: number)`: Links a native camera-like view to the library and returns a source you can stream from.
  - `createWebRTCTrack(source, opts?)`: Creates a WebRTC video track from a source. You can pass simple options like `fps` and `resolution`.
  - `replaceTrack(senderId: string, nextTrackId: string)`: Swaps the video track used by an existing WebRTC sender.
  - `pauseTrack(trackId: string)`: Temporarily stops sending frames for that track (does not destroy it).
  - `resumeTrack(trackId: string)`: Restarts frame sending for a paused track.
  - `setTrackConstraints(trackId: string, opts)`: Changes track settings on the fly (for example, fps or resolution).
  - `disposeTrack(trackId: string)`: Frees native resources for that track.
  - `getStats()`: Returns basic runtime stats like `fps` and `droppedFrames` (if supported on the platform).

- **Component**
  - `VisionRTCView`: A native view that can render a given `trackId`.
    - Props:
      - `trackId?: string | null`
      - `style?: ViewStyle | ViewStyle[]`

- **Types**
  - `TrackOptions`: Options for tracks. Common fields:
    - `fps?: number` (frames per second)
    - `resolution?: { width: number; height: number }`
    - `bitrate?: number`
    - `colorSpace?: 'auto' | 'sRGB' | 'BT.709' | 'BT.2020'`
    - `orientationMode?: 'auto' | 'fixed-0' | 'fixed-90' | 'fixed-180' | 'fixed-270'`
    - `mode?: 'null-gpu' | 'null-cpu' | 'external'`
  - `VisionRTCTrack`: `{ trackId: string }` returned when you create a track.
  - `VisionCameraSource`: Source handle returned by `createVisionCameraSource`.
  - `NativePixelSource`: Low-level source if you already have native pixels (platform-specific shapes).
  - `Resolution`: `{ width: number; height: number }`.


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
