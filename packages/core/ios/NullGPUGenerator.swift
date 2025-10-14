import Foundation
import CoreImage
import CoreVideo

class NullGPUGenerator {
  struct Resolution { let width: Int; let height: Int }

  private let queue = DispatchQueue(label: "com.visionrtc.nullgpu", qos: .userInitiated)
  private var timer: DispatchSourceTimer?
  private var fps: Int
  private var res: Resolution
  private var framesThisSecond: Int = 0
  private var lastSecondTs: CFTimeInterval = CACurrentMediaTime()
  private var droppedFrames: Int = 0

  private var ciContext: CIContext
  private var pixelPool: CVPixelBufferPool?

  private let onFrame: (_ pixelBuffer: CVPixelBuffer, _ timestampNs: Int64) -> Void
  private let onFps: (_ fps: Int, _ dropped: Int) -> Void

  init(width: Int, height: Int, fps: Int,
       onFrame: @escaping (_ pixelBuffer: CVPixelBuffer, _ timestampNs: Int64) -> Void,
       onFps: @escaping (_ fps: Int, _ dropped: Int) -> Void) {
    self.fps = max(1, fps)
    self.res = Resolution(width: max(1, width), height: max(1, height))
    self.onFrame = onFrame
    self.onFps = onFps

    if let device = MTLCreateSystemDefaultDevice() {
      self.ciContext = CIContext(mtlDevice: device)
    } else {
      self.ciContext = CIContext(options: nil)
    }
    self.pixelPool = makePool(width: self.res.width, height: self.res.height)
  }

  func start() {
    stop()
    let periodNs = UInt64(1_000_000_000) / UInt64(max(1, fps))
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: .nanoseconds(Int(periodNs)))
    timer.setEventHandler { [weak self] in self?.tick() }
    self.timer = timer
    timer.resume()
  }

  func pause() { timer?.suspend() }
  func resume() { timer?.resume() }
  func stop() {
    timer?.cancel(); timer = nil
  }

  func setResolution(width: Int, height: Int) {
    res = Resolution(width: max(1, width), height: max(1, height))
    pixelPool = makePool(width: res.width, height: res.height)
  }

  func setFps(_ next: Int) {
    guard next > 0, next != fps else { return }
    fps = next
    start()
  }

  private func tick() {
    let now = CACurrentMediaTime()
    if now - lastSecondTs >= 1.0 {
      onFps(framesThisSecond, droppedFrames)
      framesThisSecond = 0
      droppedFrames = 0
      lastSecondTs = now
    }

    guard let pool = pixelPool else { droppedFrames += 1; return }
    var pbOpt: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOpt)
    guard status == kCVReturnSuccess, let pb = pbOpt else { droppedFrames += 1; return }

    render(into: pb, t: now)

    let tsNs = Int64(now * 1_000_000_000.0)
    onFrame(pb, tsNs)
    framesThisSecond += 1
  }

  private func makePool(width: Int, height: Int) -> CVPixelBufferPool? {
    let pixelFormat = kCVPixelFormatType_32BGRA
    let attrs: [CFString: Any] = [
      kCVPixelBufferPixelFormatTypeKey: pixelFormat,
      kCVPixelBufferWidthKey: width,
      kCVPixelBufferHeightKey: height,
      kCVPixelFormatOpenGLESCompatibility: true,
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [:]
    ]
    var pool: CVPixelBufferPool?
    let res = CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
    if res != kCVReturnSuccess { return nil }
    return pool
  }

  private func render(into pixelBuffer: CVPixelBuffer, t: CFTimeInterval) {
    let w = res.width
    let h = res.height
    let rect = CGRect(x: 0, y: 0, width: w, height: h)
    let phase = CGFloat((t.truncatingRemainder(dividingBy: 5.0)) / 5.0)

    let c1 = CIColor(red: phase, green: 0.2, blue: 1.0 - phase, alpha: 1)
    let c2 = CIColor(red: 1.0 - phase, green: 0.8, blue: phase, alpha: 1)

    let start = CIVector(x: 0, y: 0)
    let end = CIVector(x: CGFloat(w), y: CGFloat(h))
    let gradient = CIFilter(name: "CILinearGradient", parameters: [
      "inputPoint0": start,
      "inputColor0": c1,
      "inputPoint1": end,
      "inputColor1": c2,
    ])?.outputImage?.cropped(to: rect) ?? CIImage(color: c1).cropped(to: rect)

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    ciContext.render(gradient, to: pixelBuffer)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
  }
}