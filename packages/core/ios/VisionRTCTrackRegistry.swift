import Foundation
import WebRTC

@objc(VisionRTCTrackRegistry)
class VisionRTCTrackRegistry: NSObject {
  @objc static let shared = VisionRTCTrackRegistry()

  private var tracks: [String: RTCVideoTrack] = [:]
  private let queue = DispatchQueue(label: "com.visionrtc.trackregistry", attributes: .concurrent)

  @objc func register(trackId: String, track: RTCVideoTrack) {
    queue.async(flags: .barrier) {
      self.tracks[trackId] = track
    }
  }

  @objc func unregister(trackId: String) {
    queue.async(flags: .barrier) {
      self.tracks.removeValue(forKey: trackId)
    }
  }

  @objc func track(for trackId: String) -> RTCVideoTrack? {
    var t: RTCVideoTrack?
    queue.sync {
      t = self.tracks[trackId]
    }
    return t
  }
}
