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
    var mode: String // 'null-gpu' | 'null-cpu' | 'external'
    var backpressure: String? // 'drop-late' | 'latest-wins' | 'throttle'
  }

  private var sources: [String: RTCVideoSource] = [:]
  private var tracks: [String: RTCVideoTrack] = [:]
  private var capturers: [String: RTCVideoCapturer] = [:]

  private var trackStates: [String: TrackState] = [:]
  private var activeTrackIds: Set<String> = []
  private let stateQueue = DispatchQueue(label: "com.visionrtc.state", attributes: .concurrent)
  private var lastSent: [String: CFTimeInterval] = [:]

  private struct SourceHandle {
    let viewTag: Int
    var position: String?
    var torch: Bool?
    var maxFps: Int?
  }
  private var cameraSources: [String: SourceHandle] = [:]
  private var sourceToTrackIds: [String: Set<String>] = [:]
  private var trackToSourceId: [String: String] = [:]

  // Backpressure and stats (per track)
  private var latestBufferByTrack: [String: (pb: CVPixelBuffer, tsNs: Int64)] = [:]
  private var producedThisSecond: [String: Int] = [:]
  private var deliveredThisSecond: [String: Int] = [:]
  private var lastSecondWallClock: [String: CFTimeInterval] = [:]
  private var deliveredFpsByTrack: [String: Int] = [:]
  private var producedFpsByTrack: [String: Int] = [:]
  private var droppedFramesByTrack: [String: Int] = [:]
  private var pausedForReconfig: Set<String> = []

  private var captureTimer: DispatchSourceTimer?
  private let timerQueue = DispatchQueue(label: "com.visionrtc.capture", qos: .userInitiated)
  private var gpuGenerators: [String: NullGPUGenerator] = [:]
  private var producedFps: Int = 0
  private var droppedFrames: Int = 0

  @objc(createVisionCameraSource:resolver:rejecter:)
  func createVisionCameraSource(viewTag: NSNumber,
                                resolver: RCTPromiseResolveBlock,
                                rejecter: RCTPromiseRejectBlock) {
    let id = UUID().uuidString
    let handle = SourceHandle(viewTag: viewTag.intValue, position: nil, torch: nil, maxFps: nil)
    stateQueue.async(flags: .barrier) {
      self.cameraSources[id] = handle
      self.sourceToTrackIds[id] = Set<String>()
    }
    resolver(["__nativeSourceId": id])
  }

  @objc(updateSource:opts:resolver:rejecter:)
  func updateSource(sourceId: NSString, opts: NSDictionary,
                    resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      if var s = self.cameraSources[sourceId as String] {
        if let pos = opts["position"] as? String { s.position = pos }
        if let torch = opts["torch"] as? NSNumber { s.torch = torch.boolValue }
        if let maxFps = opts["maxFps"] as? NSNumber { s.maxFps = maxFps.intValue }
        self.cameraSources[sourceId as String] = s
      }
      let tracksForSource = Array(self.sourceToTrackIds[sourceId as String] ?? [])
      for tid in tracksForSource {
        self.pausedForReconfig.insert(tid)
        self.latestBufferByTrack.removeValue(forKey: tid)
        self.lastSent.removeValue(forKey: tid)
        self.producedThisSecond[tid] = 0
        self.deliveredThisSecond[tid] = 0
        self.producedFpsByTrack[tid] = 0
        self.deliveredFpsByTrack[tid] = 0
        self.droppedFramesByTrack[tid] = 0
        self.lastSecondWallClock[tid] = CACurrentMediaTime()
      }
    }
    stateQueue.asyncAfter(deadline: .now() + 0.35, flags: .barrier) {
      let tracksForSource = Array(self.sourceToTrackIds[sourceId as String] ?? [])
      for tid in tracksForSource {
        self.pausedForReconfig.remove(tid)
      }
    }
    resolver(NSNull())
  }

  @objc(disposeSource:resolver:rejecter:)
  func disposeSource(sourceId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      self.cameraSources.removeValue(forKey: sourceId as String)
      self.sourceToTrackIds.removeValue(forKey: sourceId as String)
    }
    resolver(NSNull())
  }

  @objc(createTrack:opts:resolver:rejecter:)
  func createTrack(sourceDict: NSDictionary?, opts: NSDictionary?,
                   resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    let source = factory.videoSource()
    var width: Int32 = 1280
    var height: Int32 = 720
    var fps: Int = 30
    var mode = (opts?["mode"] as? String)
    var backpressure = opts?["backpressure"] as? String
    if let res = opts?["resolution"] as? [String: Any],
       let w = res["width"] as? NSNumber, let h = res["height"] as? NSNumber {
      width = w.int32Value; height = h.int32Value
    }
    if let f = opts?["fps"] as? NSNumber { fps = f.intValue }

    source.adaptOutputFormat(toWidth: width, height: height, fps: Int32(fps))

    let trackId = UUID().uuidString
    let track = factory.videoTrack(with: source, trackId: trackId)

    var boundSourceId: String?
    if let sd = sourceDict, let sid = sd["__nativeSourceId"] as? String {
      boundSourceId = sid
      if mode == nil { mode = "external" }
    }
    if mode == nil { mode = "null-gpu" }

    stateQueue.async(flags: .barrier) {
      self.sources[trackId] = source
      self.tracks[trackId] = track
      self.capturers[trackId] = RTCVideoCapturer(delegate: source)
      self.trackStates[trackId] = TrackState(width: width, height: height, fps: fps, mode: mode!, backpressure: backpressure)
      self.activeTrackIds.insert(trackId)
      self.lastSent[trackId] = 0
      if let sid = boundSourceId {
        self.trackToSourceId[trackId] = sid
        var set = self.sourceToTrackIds[sid] ?? Set<String>()
        set.insert(trackId)
        self.sourceToTrackIds[sid] = set
      }
    }
    VisionRTCTrackRegistry.shared.register(trackId: trackId, track: track)
    if mode == "null-gpu" {
      startGpuGenerator(for: trackId)
    } else if mode == "null-cpu" {
      startNullCapturer()
    } // 'external' emits frames from camera binding

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
      if let st = self.trackStates[trackId as String], st.mode == "null-gpu" {
        self.stopGpuGenerator(for: trackId as String)
      }
      if self.activeTrackIds.isEmpty { self.stopNullCapturer() }
    }
    resolver(NSNull())
  }

  @objc(resumeTrack:resolver:rejecter:)
  func resumeTrack(trackId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    stateQueue.async(flags: .barrier) {
      self.activeTrackIds.insert(trackId as String)
    }
    stateQueue.sync {
      if let st = self.trackStates[trackId as String] {
        if st.mode == "null-gpu" {
          self.startGpuGenerator(for: trackId as String)
        } else if st.mode == "null-cpu" {
          self.startNullCapturer()
        }
      }
    }
    resolver(NSNull())
  }

  @objc(setTrackConstraints:opts:resolver:rejecter:)
  func setTrackConstraints(trackId: NSString, opts: NSDictionary,
                           resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    var nextWidth: Int32?
    var nextHeight: Int32?
    var nextFps: Int?
    var nextBackpressure: String?

    if let res = opts["resolution"] as? [String: Any] {
      if let w = res["width"] as? NSNumber { nextWidth = w.int32Value }
      if let h = res["height"] as? NSNumber { nextHeight = h.int32Value }
    }
    if let f = opts["fps"] as? NSNumber { nextFps = f.intValue }
    if let bp = opts["backpressure"] as? String { nextBackpressure = bp }

    stateQueue.async(flags: .barrier) {
      if var st = self.trackStates[trackId as String] {
        if let w = nextWidth { st.width = w }
        if let h = nextHeight { st.height = h }
        if let f = nextFps { st.fps = f }
        if let bp = nextBackpressure { st.backpressure = bp }
        self.trackStates[trackId as String] = st
        if let src = self.sources[trackId as String] {
          src.adaptOutputFormat(toWidth: st.width, height: st.height, fps: Int32(st.fps))
        }
        if st.mode == "null-gpu" {
          if let gen = self.gpuGenerators[trackId as String] {
            if let w = nextWidth, let h = nextHeight { gen.setResolution(width: Int(w), height: Int(h)) }
            if let f = nextFps { gen.setFps(f) }
          }
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
    VisionRTCTrackRegistry.shared.unregister(trackId: trackId as String)
    stopGpuGenerator(for: trackId as String)
    stateQueue.sync {
      if self.activeTrackIds.isEmpty { self.stopNullCapturer() }
    }
    resolver(NSNull())
  }

  @objc(getStats:rejecter:)
  func getStats(resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    var deliveredSum = 0
    var droppedSum = 0
    stateQueue.sync {
      deliveredSum = self.deliveredFpsByTrack.values.reduce(0, +)
      droppedSum = self.droppedFramesByTrack.values.reduce(0, +)
      // If not yet rolled in this second, fall back to current counters
      if deliveredSum == 0 {
        deliveredSum = self.deliveredThisSecond.values.reduce(0, +)
      }
    }
    resolver(["fps": deliveredSum, "droppedFrames": droppedSum])
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
      if !shouldEmit {
        if policy == "latest-wins" {
          stateQueue.sync(flags: .barrier) {
            self.droppedFramesByTrack[trackId] = (self.droppedFramesByTrack[trackId] ?? 0) + 1
          }
        }
        continue
      }

      if st.mode != "null-cpu" { continue }
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
      // Update per-track stats for null-cpu: produced and delivered together
      self.stateQueue.sync(flags: .barrier) {
        self.producedThisSecond[trackId] = (self.producedThisSecond[trackId] ?? 0) + 1
        self.deliveredThisSecond[trackId] = (self.deliveredThisSecond[trackId] ?? 0) + 1
        if self.lastSecondWallClock[trackId] == nil {
          self.lastSecondWallClock[trackId] = nowSec
        }
        let lastSecond = self.lastSecondWallClock[trackId] ?? nowSec
        if nowSec - lastSecond >= 1.0 {
          self.producedFpsByTrack[trackId] = self.producedThisSecond[trackId] ?? 0
          self.deliveredFpsByTrack[trackId] = self.deliveredThisSecond[trackId] ?? 0
          self.producedThisSecond[trackId] = 0
          self.deliveredThisSecond[trackId] = 0
          self.lastSecondWallClock[trackId] = nowSec
        }
      }
    }
  }
}

extension VisionRTC {
  fileprivate func deliverExternalFrame(sourceId: String, pixelBuffer: CVPixelBuffer, timestampNs: Int64) {
    var trackIds: [String] = []
    stateQueue.sync { trackIds = Array(self.sourceToTrackIds[sourceId] ?? []) }
    if trackIds.isEmpty { return }
    for trackId in trackIds {
      var isPaused = false
      stateQueue.sync { isPaused = self.pausedForReconfig.contains(trackId) }
      if isPaused { continue }
      var stOpt: TrackState?
      var srcOpt: RTCVideoSource?
      var capOpt: RTCVideoCapturer?
      stateQueue.sync {
        stOpt = self.trackStates[trackId]
        srcOpt = self.sources[trackId]
        capOpt = self.capturers[trackId]
      }
      guard let st = stOpt, let src = srcOpt else { continue }
      let nowSec = CACurrentMediaTime()
      let intervalSec = 1.0 / Double(max(1, st.fps))

      // Update produced counters and per-second rollups
      stateQueue.sync(flags: .barrier) {
        self.producedThisSecond[trackId] = (self.producedThisSecond[trackId] ?? 0) + 1
        if self.lastSecondWallClock[trackId] == nil {
          self.lastSecondWallClock[trackId] = nowSec
        }
        let lastSecond = self.lastSecondWallClock[trackId] ?? nowSec
        if nowSec - lastSecond >= 1.0 {
          self.producedFpsByTrack[trackId] = self.producedThisSecond[trackId] ?? 0
          self.deliveredFpsByTrack[trackId] = self.deliveredThisSecond[trackId] ?? 0
          self.producedThisSecond[trackId] = 0
          self.deliveredThisSecond[trackId] = 0
          self.lastSecondWallClock[trackId] = nowSec
        }
      }

      let policy = st.backpressure ?? "drop-late"
      var shouldEmit = false
      var bufferToSend: CVPixelBuffer = pixelBuffer

      stateQueue.sync(flags: .barrier) {
        let last = self.lastSent[trackId] ?? 0
        if policy == "latest-wins" {
          // Always keep the latest; emit only on cadence. Count suppressed frames as drops.
          self.latestBufferByTrack[trackId] = (pixelBuffer, timestampNs)
          if nowSec - last >= intervalSec {
            self.lastSent[trackId] = nowSec
            if let latest = self.latestBufferByTrack[trackId] {
              bufferToSend = latest.pb
            }
            shouldEmit = true
          } else {
            self.droppedFramesByTrack[trackId] = (self.droppedFramesByTrack[trackId] ?? 0) + 1
          }
        } else if policy == "throttle" {
          self.latestBufferByTrack[trackId] = (pixelBuffer, timestampNs)
          if nowSec - last >= intervalSec {
            self.lastSent[trackId] = nowSec
            if let latest = self.latestBufferByTrack[trackId] {
              bufferToSend = latest.pb
            }
            shouldEmit = true
          }
        } else {
          if nowSec - last >= intervalSec {
            self.lastSent[trackId] = nowSec
            shouldEmit = true
          } else {
            self.droppedFramesByTrack[trackId] = (self.droppedFramesByTrack[trackId] ?? 0) + 1
          }
        }
      }

      if !shouldEmit { continue }

      let rtcBuf = RTCCVPixelBuffer(pixelBuffer: bufferToSend)
      let ts: Int64 = (policy == "latest-wins" ? (stateQueue.sync { self.latestBufferByTrack[trackId]?.tsNs } ?? timestampNs) : timestampNs)
      let frame = RTCVideoFrame(buffer: rtcBuf, rotation: ._0, timeStampNs: ts)
      if let cap = capOpt {
        src.capturer(cap, didCapture: frame)
      } else {
        src.capturer(RTCVideoCapturer(delegate: src), didCapture: frame)
      }

      stateQueue.sync(flags: .barrier) {
        self.deliveredThisSecond[trackId] = (self.deliveredThisSecond[trackId] ?? 0) + 1
        let lastSecond = self.lastSecondWallClock[trackId] ?? nowSec
        if nowSec - lastSecond >= 1.0 {
          self.producedFpsByTrack[trackId] = self.producedThisSecond[trackId] ?? 0
          self.deliveredFpsByTrack[trackId] = self.deliveredThisSecond[trackId] ?? 0
          self.producedThisSecond[trackId] = 0
          self.deliveredThisSecond[trackId] = 0
          self.lastSecondWallClock[trackId] = nowSec
        }
      }
    }
  }

  @objc(getStatsForTrack:resolver:rejecter:)
  func getStatsForTrack(trackId: NSString, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    var produced = 0
    var delivered = 0
    var dropped = 0
    stateQueue.sync {
      produced = self.producedFpsByTrack[trackId as String] ?? 0
      delivered = self.deliveredFpsByTrack[trackId as String] ?? 0
      dropped = self.droppedFramesByTrack[trackId as String] ?? 0
    }
    resolver(["producedFps": produced, "deliveredFps": delivered, "droppedFrames": dropped])
  }
  fileprivate func startGpuGenerator(for trackId: String) {
    var stOpt: TrackState?
    var srcOpt: RTCVideoSource?
    stateQueue.sync {
      stOpt = self.trackStates[trackId]
      srcOpt = self.sources[trackId]
    }
    guard let st = stOpt, let src = srcOpt else { return }
    let gen = NullGPUGenerator(width: Int(st.width), height: Int(st.height), fps: st.fps, onFrame: { [weak self] pb, tsNs in
      guard let self = self else { return }
      let rtcBuf = RTCCVPixelBuffer(pixelBuffer: pb)
      let frame = RTCVideoFrame(buffer: rtcBuf, rotation: ._0, timeStampNs: tsNs)
      var capOpt: RTCVideoCapturer?
      self.stateQueue.sync { capOpt = self.capturers[trackId] }
      if let cap = capOpt {
        src.capturer(cap, didCapture: frame)
      } else {
        src.capturer(RTCVideoCapturer(delegate: src), didCapture: frame)
      }
      let nowSec = CACurrentMediaTime()
      self.stateQueue.sync(flags: .barrier) {
        self.producedThisSecond[trackId] = (self.producedThisSecond[trackId] ?? 0) + 1
        self.deliveredThisSecond[trackId] = (self.deliveredThisSecond[trackId] ?? 0) + 1
        if self.lastSecondWallClock[trackId] == nil {
          self.lastSecondWallClock[trackId] = nowSec
        }
        let lastSecond = self.lastSecondWallClock[trackId] ?? nowSec
        if nowSec - lastSecond >= 1.0 {
          self.producedFpsByTrack[trackId] = self.producedThisSecond[trackId] ?? 0
          self.deliveredFpsByTrack[trackId] = self.deliveredThisSecond[trackId] ?? 0
          self.producedThisSecond[trackId] = 0
          self.deliveredThisSecond[trackId] = 0
          self.lastSecondWallClock[trackId] = nowSec
        }
      }
    }, onFps: { [weak self] fpsNow, dropped in
      guard let self = self else { return }
      self.stateQueue.sync(flags: .barrier) {
        self.droppedFramesByTrack[trackId] = dropped
      }
    })
    gpuGenerators[trackId] = gen
    gen.start()
  }

  fileprivate func stopGpuGenerator(for trackId: String) {
    if let g = gpuGenerators.removeValue(forKey: trackId) { g.stop() }
  }
}
