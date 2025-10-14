import type {Frame} from "react-native-vision-camera";
import {deliverFrame} from "react-native-vision-rtc";

let sourceId: string | null = null;
let frameCount = 0;

export function setSourceId(id: string) {
  sourceId = id;
  frameCount = 0;
}

export function clearSourceId() {
  sourceId = null;
  frameCount = 0;
}

export function processFrame(frame: Frame): void {
  "worklet";

  if (!sourceId) {
    console.log("VisionCamera: No source ID set, skipping frame delivery");
    return;
  }

  frameCount++;

  // Only deliver every 2nd frame to avoid overwhelming the system during testing
  if (frameCount % 2 !== 0) {
    return;
  }

  try {
    // Get the native pixel buffer reference
    const pixelBufferRef = (frame as Frame).getNativeBuffer();
    const timestampNs = frame.timestamp * 1000000; // Convert to nanoseconds

    if (pixelBufferRef) {
      deliverFrame(sourceId, pixelBufferRef, timestampNs).catch(
        (error: unknown) => {
          console.warn("VisionCamera: Failed to deliver frame:", error);
        }
      );
    }
  } catch (error) {
    console.warn("VisionCamera: Error processing frame:", error);
  }
}

export function getFrameCount(): number {
  return frameCount;
}
