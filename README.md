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


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
