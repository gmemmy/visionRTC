package com.visionrtc

import android.os.SystemClock
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import org.webrtc.CapturerObserver
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.EglBase
import org.webrtc.JavaI420Buffer
import org.webrtc.PeerConnectionFactory
import org.webrtc.TimestampAligner
import org.webrtc.VideoFrame
import org.webrtc.VideoSource
import org.webrtc.VideoTrack
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

@ReactModule(name = VisionRTCModule.NAME)
class VisionRTCModule(reactContext: ReactApplicationContext) : NativeVisionRtcSpec(reactContext) {

  private val eglBaseLazy = lazy { EglBase.create() }
  private val eglBase: EglBase get() = eglBaseLazy.value
  private val encoderFactoryLazy = lazy { DefaultVideoEncoderFactory(eglBase.eglBaseContext, true, true) }
  private val encoderFactory get() = encoderFactoryLazy.value
  private val decoderFactoryLazy = lazy { DefaultVideoDecoderFactory(eglBase.eglBaseContext) }
  private val decoderFactory get() = decoderFactoryLazy.value
  private val factoryLazy = lazy {
    PeerConnectionFactory.initialize(
      PeerConnectionFactory.InitializationOptions.builder(reactApplicationContext)
        .createInitializationOptions()
    )
    PeerConnectionFactory.builder()
      .setVideoEncoderFactory(encoderFactory)
      .setVideoDecoderFactory(decoderFactory)
      .createPeerConnectionFactory()
  }
  private val factory: PeerConnectionFactory get() = factoryLazy.value

  private data class TrackHandle(
    val source: VideoSource,
    val track: VideoTrack,
    val cpuCapturer: GradientCapturer?,
    val glCapturer: GlNullGenerator?
  )

  private val tracks: MutableMap<String, TrackHandle> = ConcurrentHashMap()
  private val cleanupExecutor: java.util.concurrent.ExecutorService = Executors.newSingleThreadExecutor()

  @Volatile private var targetFps: Int = 30
  @Volatile private var lastReportedFps: Int = 0

  override fun getName(): String = NAME

  override fun createVisionCameraSource(viewTag: Double, promise: Promise) {
    val id = UUID.randomUUID().toString()
    val result = com.facebook.react.bridge.Arguments.createMap()
    result.putString("__nativeSourceId", id)
    promise.resolve(result)
  }

  override fun createTrack(source: ReadableMap?, opts: ReadableMap?, promise: Promise) {
    var width: Int = 1280
    var height: Int = 720
    var fps: Int = 30
    val mode: String = if (opts != null && opts.hasKey("mode")) opts.getString("mode") ?: "null-gpu" else "null-gpu"

    if (opts != null) {
      if (opts.hasKey("resolution")) {
        val resolution = opts.getMap("resolution")
        if (resolution != null) {
          if (resolution.hasKey("width")) {
            val w = resolution.getDouble("width")
            if (!w.isNaN()) width = w.roundToInt()
          }
          if (resolution.hasKey("height")) {
            val h = resolution.getDouble("height")
            if (!h.isNaN()) height = h.roundToInt()
          }
        }
      }

      if (opts.hasKey("fps")) {
        val f = opts.getDouble("fps")
        if (!f.isNaN()) fps = f.roundToInt()
      }
    }

    targetFps = fps

    val videoSource = factory.createVideoSource(false)
    val trackId = UUID.randomUUID().toString()
    val track = factory.createVideoTrack(trackId, videoSource)

    val useGl = mode == "null-gpu"
    var cpuCap: GradientCapturer? = null
    var glCap: GlNullGenerator? = null
    if (useGl) {
      glCap = GlNullGenerator(eglBase, videoSource.capturerObserver, width, height, fps) { deliveredFps ->
        lastReportedFps = deliveredFps
      }
      glCap.start()
    } else {
      cpuCap = GradientCapturer(videoSource.capturerObserver, width, height, fps) { deliveredFps ->
        lastReportedFps = deliveredFps
      }
      cpuCap.start()
    }

    tracks[trackId] = TrackHandle(videoSource, track, cpuCap, glCap)

    val result = com.facebook.react.bridge.Arguments.createMap()
    result.putString("trackId", trackId)
    promise.resolve(result)
  }

  fun eglContext(): EglBase.Context = eglBase.eglBaseContext

  fun findTrack(trackId: String?): TrackHandle? {
    if (trackId == null) return null
    return tracks[trackId]
  }

  override fun replaceSenderTrack(senderId: String?, newTrackId: String?, promise: Promise) {
    promise.resolve(null)
  }

  override fun pauseTrack(trackId: String, promise: Promise) {
    val handle = tracks[trackId]
    if (handle == null) { promise.reject("ERR_UNKNOWN_TRACK", "Unknown trackId: $trackId"); return }
    handle.cpuCapturer?.pause()
    handle.glCapturer?.pause()
    promise.resolve(null)
  }

  override fun resumeTrack(trackId: String, promise: Promise) {
    val handle = tracks[trackId]
    if (handle == null) { promise.reject("ERR_UNKNOWN_TRACK", "Unknown trackId: $trackId"); return }
    handle.cpuCapturer?.resume()
    handle.glCapturer?.resume()
    promise.resolve(null)
  }

  override fun setTrackConstraints(trackId: String, opts: ReadableMap, promise: Promise) {
    val handle = tracks[trackId]
    if (handle == null) {
      promise.reject("ERR_UNKNOWN_TRACK", "Unknown trackId: $trackId")
      return
    }

    val cpuCap = handle.cpuCapturer
    val glCap = handle.glCapturer

    var nextWidth: Int? = null
    var nextHeight: Int? = null
    var nextFps: Int? = null

    if (opts.hasKey("resolution")) {
      val resolution = opts.getMap("resolution")
      if (resolution != null) {
        if (resolution.hasKey("width")) {
          val w = resolution.getDouble("width")
          if (!w.isNaN()) nextWidth = w.roundToInt()
        }
        if (resolution.hasKey("height")) {
          val h = resolution.getDouble("height")
          if (!h.isNaN()) nextHeight = h.roundToInt()
        }
      }
    }

    if (opts.hasKey("fps")) {
      val f = opts.getDouble("fps")
      if (!f.isNaN()) nextFps = f.roundToInt()
    }

    if (nextWidth != null && nextHeight != null) {
      cpuCap?.setResolution(nextWidth, nextHeight)
      glCap?.setResolution(nextWidth, nextHeight)
    }
    if (nextFps != null) {
      cpuCap?.setFps(nextFps)
      glCap?.setFps(nextFps)
    }

    targetFps = cpuCap?.fps ?: (glCap?.fps ?: targetFps)
    promise.resolve(null)
  }

  override fun disposeTrack(trackId: String, promise: Promise) {
    tracks.remove(trackId)?.let { handle ->
      handle.cpuCapturer?.stop()
      handle.glCapturer?.stop()
      handle.track.setEnabled(false)
      handle.track.dispose()
      handle.source.dispose()
    }
    promise.resolve(null)
  }

  override fun getStats(promise: Promise) {
    val result = com.facebook.react.bridge.Arguments.createMap()
    result.putInt("fps", lastReportedFps)
    result.putInt("droppedFrames", 0)
    promise.resolve(result)
  }

  companion object { const val NAME = "VisionRTC" }

  override fun invalidate() {
    super.invalidate()
    cleanupExecutor.execute {
      tracks.values.forEach { handle ->
        try { handle.capturer.stop() } catch (_: Throwable) {}
        try { handle.track.setEnabled(false) } catch (_: Throwable) {}
        try { handle.track.dispose() } catch (_: Throwable) {}
        try { handle.source.dispose() } catch (_: Throwable) {}
      }
      tracks.clear()

      if (factoryLazy.isInitialized()) {
        try { factory.dispose() } catch (_: Throwable) {}
        try { PeerConnectionFactory.shutdownInternal() } catch (_: Throwable) {}
      }

      if (eglBaseLazy.isInitialized()) {
        try { eglBase.release() } catch (_: Throwable) {}
      }
      try { cleanupExecutor.shutdown() } catch (_: Throwable) {}
    }
  }
}

private class GradientCapturer(
  private val observer: CapturerObserver,
  width: Int,
  height: Int,
  fps: Int,
  private val onFps: (Int) -> Unit,
) {
  @Volatile var width: Int = width; private set
  @Volatile var height: Int = height; private set
  @Volatile var fps: Int = fps; private set

  private val executor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
  private var scheduled: ScheduledFuture<*>? = null

  @Volatile private var running: Boolean = false
  private var framesThisSecond: Int = 0
  private var lastSecondTs: Long = SystemClock.elapsedRealtime()

  fun start() {
    if (running) return
    running = true
    val periodNs = (1_000_000_000L / fps.toLong())
    scheduled = executor.scheduleAtFixedRate({ tick() }, 0L, periodNs, TimeUnit.NANOSECONDS)
  }

  fun pause() { running = false }
  fun resume() { running = true }
  fun stop() {
    running = false
    scheduled?.cancel(true)
    executor.shutdownNow()
  }

  fun setResolution(w: Int, h: Int) { width = w; height = h }
  fun setFps(next: Int) {
    if (next <= 0 || next == fps) return
    fps = next
    if (running) {
      scheduled?.cancel(false)
      val periodNs = (1_000_000_000L / fps.toLong())
      scheduled = executor.scheduleAtFixedRate({ tick() }, 0L, periodNs, TimeUnit.NANOSECONDS)
    }
  }

  private fun tick() {
    if (!running) return
    val now = SystemClock.elapsedRealtime()
    if (now - lastSecondTs >= 1000) {
      onFps(framesThisSecond)
      framesThisSecond = 0
      lastSecondTs = now
    }

    val w = width
    val h = height
    val buffer = JavaI420Buffer.allocate(w, h)

    val yPlane: ByteBuffer = buffer.dataY
    val uPlane: ByteBuffer = buffer.dataU
    val vPlane: ByteBuffer = buffer.dataV
    val ts = (now % 5000).toInt()

    for (y in 0 until h) {
      for (x in 0 until w) {
        val yVal = (((x + ts / 10) % w).toFloat() / w * 255f).roundToInt().coerceIn(0, 255)
        yPlane.put(y * buffer.strideY + x, yVal.toByte())
      }
    }
    val chromaW = (w + 1) / 2
    val chromaH = (h + 1) / 2
    for (y in 0 until chromaH) {
      for (x in 0 until chromaW) {
        uPlane.put(y * buffer.strideU + x, 128.toByte())
        vPlane.put(y * buffer.strideV + x, 128.toByte())
      }
    }

    val timestampNs = TimestampAligner.getRtcTimeNanos()
    val frame = VideoFrame(buffer, 0, timestampNs)
    observer.onFrameCaptured(frame)
    frame.release()
    framesThisSecond += 1
  }
}