package com.visionrtc

import android.content.Context
import android.view.View
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import org.webrtc.SurfaceViewRenderer

@ReactModule(name = VisionRtcViewManager.NAME)
class VisionRtcViewManager(private val context: ReactApplicationContext) : SimpleViewManager<SurfaceViewRenderer>() {

  companion object { const val NAME = "VisionRTCView" }

  override fun getName(): String = NAME

  override fun createViewInstance(reactContext: ThemedReactContext): SurfaceViewRenderer {
    val view = SurfaceViewRenderer(reactContext)
    val eglBase = (reactContext.getNativeModule(VisionRTCModule::class.java) as? VisionRTCModule)?.let { it }?.let { it } // will init later
    // We use a lazy global egl in VisionRTCModule; init when attaching track
    view.setEnableHardwareScaler(true)
    view.setMirror(false)
    return view
  }

  @ReactProp(name = "trackId")
  fun setTrackId(view: SurfaceViewRenderer, trackId: String?) {
    val module = view.context.applicationContext.let { (it as? Context)?.let { _ -> null } }
    val mod = (context.getNativeModule(VisionRTCModule::class.java)) ?: return
    val handle = mod.findTrack(trackId)
    view.release()
    view.init(mod.eglContext(), null)
    handle?.track?.addSink(view)
  }

  override fun onDropViewInstance(view: SurfaceViewRenderer) {
    super.onDropViewInstance(view)
    view.release()
  }
}