package com.visionrtc

import android.opengl.GLES20
import android.os.SystemClock
import org.webrtc.EglBase
import org.webrtc.JavaI420Buffer
import org.webrtc.VideoFrame
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

class GlNullGenerator(
  private val eglBase: EglBase,
  private val observer: org.webrtc.CapturerObserver,
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
  private var framesThisSecond = 0
  private var lastSecondTs = SystemClock.elapsedRealtime()

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

    val timestampNs = org.webrtc.TimestampAligner.getRtcTimeNanos()
    val frame = VideoFrame(buffer, 0, timestampNs)
    observer.onFrameCaptured(frame)
    frame.release()
    framesThisSecond += 1
  }
}