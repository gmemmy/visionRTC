import Foundation
import WebRTC
import React

@objc(VisionRTC)
class VisionRTC: NSObject {

  private lazy var encoderFactory = RTCDefaultVideoEncoderFactory()
  private lazy var decoderFactory = RTCDefaultVideoDecoderFactory()
  private lazy var factory: RTCPeerConnectionFactory = {
    RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
  }()

  private struct TrackState {
    var width: Int32
    var height: Int32
    var fps: Int
  }

  private var sources: [String: RTCVideoSource] = [:]
  private var tracks: [String: RTCVideoTrack] = [:]
  private var capturers: [String: RTCVideoCapturer] = [:]

  private var trackStates: [String: TrackState] = [:]
  private var activeTrackIds: Set<String> = []
  private let stateQueue = DispatchQueue(label: "com.visionrtc.state", attributes: .concurrent)
  private var lastSent: [String: CFTimeInterval] = [:]

  private var captureTimer: DispatchSourceTimer?
  private let timerQueue = DispatchQueue(label: "com.visionrtc.capture", qos: .userInitiated)

  @objc(createVisionCameraSource:resolver:rejecter:)
  func createVisionCameraSource(viewTag: NSNumber,
                                resolver: RCTPromiseResolveBlock,
                                rejecter: RCTPromiseRejectBlock) {
    let id = UUID().uuidString
    resolver(["__nativeSourceId": id])
  }

  @objc(createTrack:opts:resolver:rejecter:)
  func createTrack(sourceDict: NSDictionary?, opts: NSDictionary?,
                   resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    let source = factory.videoSource()
    var width: Int32 = 1280
    var height: Int32 = 720
    var fps: Int = 30
    if let res = opts?["resolution"] as? [String: Any],
       let w = res["width"] as? NSNumber, let h = res["height"] as? NSNumber {
      width = w.int32Value; height = h.int32Value
    }
    if let f = opts?["fps"] as? NSNumber { fps = f.intValue }

    source.adaptOutputFormat(toWidth: width, height: height, fps: Int32(fps))

    let trackId = UUID().uuidString
    let track = factory.videoTrack(with: source, trackId: trackId)

    stateQueue.async(flags: .barrier) {
      self.sources[trackId] = source
      self.tracks[trackId] = track
      self.capturers[trackId] = RTCVideoCapturer(delegate: source)
      self.trackStates[trackId] = TrackState(width: width, height: height, fps: fps)
      self.activeTrackIds.insert(trackId)
      self.lastSent[trackId] = 0
    }
    startNullCapturer()

    resolver(["trackId": trackId])
  }

  @objc(replaceSenderTrack:newTrackId:resolver:rejecter:)
  func replaceSenderTrack(senderId: NSString, newTrackId: NSString,
                          resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    resolver(NSNull())
  }

  @objc(pauseTrack:resolver:rejecter:)
  func pauseTrack(trackId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      self.activeTrackIds.remove(trackId as String)
    }
    stateQueue.sync {
      if self.activeTrackIds.isEmpty { self.stopNullCapturer() }
    }
    resolver(NSNull())
  }

  @objc(resumeTrack:resolver:rejecter:)
  func resumeTrack(trackId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      self.activeTrackIds.insert(trackId as String)
    }
    startNullCapturer()
    resolver(NSNull())
  }

  @objc(setTrackConstraints:opts:resolver:rejecter:)
  func setTrackConstraints(trackId: NSString, opts: NSDictionary,
                           resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    var nextWidth: Int32?
    var nextHeight: Int32?
    var nextFps: Int?

    if let res = opts["resolution"] as? [String: Any] {
      if let w = res["width"] as? NSNumber { nextWidth = w.int32Value }
      if let h = res["height"] as? NSNumber { nextHeight = h.int32Value }
    }
    if let f = opts["fps"] as? NSNumber { nextFps = f.intValue }

    stateQueue.async(flags: .barrier) {
      if var st = self.trackStates[trackId as String] {
        if let w = nextWidth { st.width = w }
        if let h = nextHeight { st.height = h }
        if let f = nextFps { st.fps = f }
        self.trackStates[trackId as String] = st
        if let src = self.sources[trackId as String] {
          src.adaptOutputFormat(toWidth: st.width, height: st.height, fps: Int32(st.fps))
        }
      }
    }
    updateDisplayLinkFps()
    resolver(NSNull())
  }

  @objc(disposeTrack:resolver:rejecter:)
  func disposeTrack(trackId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      self.activeTrackIds.remove(trackId as String)
      self.trackStates.removeValue(forKey: trackId as String)
      self.tracks.removeValue(forKey: trackId as String)
      self.sources.removeValue(forKey: trackId as String)
      self.capturers.removeValue(forKey: trackId as String)
      self.lastSent.removeValue(forKey: trackId as String)
    }
    stateQueue.sync {
      if self.activeTrackIds.isEmpty { self.stopNullCapturer() }
    }
    resolver(NSNull())
  }

  @objc(getStats:rejecter:)
  func getStats(resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    var fpsMax = 0
    stateQueue.sync {
      fpsMax = self.activeTrackIds.compactMap { self.trackStates[$0]?.fps }.max() ?? 0
    }
    resolver(["fps": fpsMax, "droppedFrames": 0])
  }

  private func startNullCapturer() {
    stopNullCapturer()
    let fps = max(1, computeMaxFps())
    let interval = DispatchTimeInterval.nanoseconds(Int(1_000_000_000 / fps))
    let timer = DispatchSource.makeTimerSource(queue: timerQueue)
    timer.schedule(deadline: .now(), repeating: interval)
    timer.setEventHandler { [weak self] in
      self?.tick()
    }
    captureTimer = timer
    timer.resume()
  }

  private func stopNullCapturer() {
    captureTimer?.cancel()
    captureTimer = nil
  }

  private func computeMaxFps() -> Int {
    var maxFps = 30
    stateQueue.sync {
      let current = self.activeTrackIds.compactMap { self.trackStates[$0]?.fps }.max()
      if let m = current { maxFps = m }
    }
    return maxFps
  }

  private func updateDisplayLinkFps() {
    if captureTimer != nil { startNullCapturer() }
  }

  @objc private func tick() {
    var ids: [String] = []
    stateQueue.sync {
      ids = Array(self.activeTrackIds)
    }
    if ids.isEmpty { return }

    for trackId in ids {
      var srcOpt: RTCVideoSource?
      stateQueue.sync {
        srcOpt = self.sources[trackId]
      }
      guard let src = srcOpt else { continue }
      var stOpt: TrackState?
      stateQueue.sync {
        stOpt = self.trackStates[trackId]
      }
      guard let st = stOpt else { continue }

      let nowSec = CACurrentMediaTime()
      let intervalSec = 1.0 / Double(max(1, st.fps))
      var shouldEmit = false
      stateQueue.sync(flags: .barrier) {
        let last = self.lastSent[trackId] ?? 0
        if nowSec - last >= intervalSec {
          self.lastSent[trackId] = nowSec
          shouldEmit = true
        }
      }
      if !shouldEmit { continue }

      let width = Int(st.width)
      let height = Int(st.height)
      let bytesPerPixel = 4
      let bytesPerRow = width * bytesPerPixel
      let dataSize = bytesPerRow * height
      var data = [UInt8](repeating: 0, count: dataSize)
      let t = CACurrentMediaTime().truncatingRemainder(dividingBy: 5.0)

      for y in 0..<height {
        for x in 0..<width {
          let idx = (y * width + x) * 4
          let r = UInt8((Double(x) / Double(width)) * 255.0)
          let g = UInt8((Double(y) / Double(height)) * 255.0)
          let b = UInt8((t / 5.0) * 255.0)
          // Write BGRA order for kCVPixelFormatType_32BGRA
          data[idx + 0] = b
          data[idx + 1] = g
          data[idx + 2] = r
          data[idx + 3] = 255
        }
      }

      var pixelBuffer: CVPixelBuffer?
      let attrs = [
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
      ] as CFDictionary

      CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
      guard let pb = pixelBuffer else { continue }
      CVPixelBufferLockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: 0))
      if let base = CVPixelBufferGetBaseAddress(pb) {
        let dstBytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        data.withUnsafeBytes { srcRaw in
          guard let srcBase = srcRaw.baseAddress else { return }
          let srcPtr = srcBase.assumingMemoryBound(to: UInt8.self)
          let dstPtr = base.assumingMemoryBound(to: UInt8.self)
          let copyPerRow = min(bytesPerRow, dstBytesPerRow)
          for y in 0..<height {
            let srcRow = srcPtr + y * bytesPerRow
            let dstRow = dstPtr + y * dstBytesPerRow
            memcpy(dstRow, srcRow, copyPerRow)
          }
        }
      }
      CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: 0))

      let rtcBuf = RTCCVPixelBuffer(pixelBuffer: pb)
      let nowNs = Int64(CACurrentMediaTime() * 1_000_000_000.0)
      let frame = RTCVideoFrame(buffer: rtcBuf, rotation: ._0, timeStampNs: nowNs)
      var capOpt: RTCVideoCapturer?
      stateQueue.sync {
        capOpt = self.capturers[trackId]
      }
      if let cap = capOpt {
        src.capturer(cap, didCapture: frame)
      } else {
        src.capturer(RTCVideoCapturer(delegate: src), didCapture: frame)
      }
    }
  }
}
