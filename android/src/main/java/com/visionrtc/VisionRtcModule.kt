package com.visionrtc

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = VisionRtcModule.NAME)
class VisionRtcModule(reactContext: ReactApplicationContext) :
  NativeVisionRtcSpec(reactContext) {

  override fun getName(): String {
    return NAME
  }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = "VisionRtc"
  }
}
