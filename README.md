# react-native-vision-rtc

A React Native library for streaming high-performance camera frames: Vision Camera, ARKit, OpenCV, or ML, over WebRTC with zero-copy GPU transfer. 

- Plugin-based: Add filters, ML, or AR processors only as needed.
- Type-safe, cross-platform, and unopinionated about signaling.
- No per-project native code required.

> 🚧 This library is a work in progress. APIs, behaviors, and native implementations may change without notice.


## Features

- Zero-copy streaming of native GPU frames from Vision Camera and other sources.
- Composable processor pipeline for filters, ML, and AR (via plugins).
- Live track management: pause/resume, replace, adjust constraints, etc.
- Minimal core: install only the plugins you need.

## Roadmap

- First release will support Vision Camera as a source.
- Skia GPU compositor and other processors coming as plugins.

![VisionRTC demo preview](https://github.com/user-attachments/assets/b30a3955-32d8-4b9d-8c48-4276b7dd1014)


Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
