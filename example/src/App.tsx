import * as React from 'react';
import {Button, Text, StyleSheet, View, findNodeHandle} from 'react-native';
import {SafeAreaView, useSafeAreaInsets} from 'react-native-safe-area-context';
import {Camera, useCameraDevice} from 'react-native-vision-camera';
import {
  createVisionCameraSource,
  createWebRTCTrack,
  updateSource,
  updateTrack,
  disposeSource,
  disposeTrack,
  getStats,
  VisionRTCView,
} from 'react-native-vision-rtc';

export default function App() {
  const insets = useSafeAreaInsets();
  const cameraRef = React.useRef<Camera>(null);
  const device = useCameraDevice('back');
  const [trackId, setTrackId] = React.useState<string | null>(null);
  const [sourceId, setSourceId] = React.useState<string | null>(null);
  const [stats, setStats] = React.useState<{
    producedFps: number;
    deliveredFps: number;
    droppedFrames: number;
  } | null>(null);
  const [creating, setCreating] = React.useState(false);
  const [torch, setTorch] = React.useState(false);
  const [facing, setFacing] = React.useState<'front' | 'back'>('back');
  const [backpressure, setBackpressure] = React.useState<
    'drop-late' | 'latest-wins' | 'throttle'
  >('drop-late');

  const ensurePermissions = React.useCallback(async () => {
    const cam = await Camera.getCameraPermissionStatus();
    if (cam !== 'granted') {
      const res = await Camera.requestCameraPermission();
      if (res !== 'granted') throw new Error('Camera permission not granted');
    }
  }, []);

  const onStart = async () => {
    if (creating || trackId) return;
    setCreating(true);
    let newId: string | null = null;
    try {
      await ensurePermissions();
      const node = findNodeHandle(cameraRef.current);
      if (!node) throw new Error('Camera view not ready');
      const {__nativeSourceId} = await createVisionCameraSource(node);
      setSourceId(__nativeSourceId);
      const created = await createWebRTCTrack(
        {__nativeSourceId},
        {
          fps: 30,
          resolution: {width: 1280, height: 720},
          backpressure,
        }
      );
      newId = created.trackId;
      setTrackId(created.trackId);
    } catch (err) {
      if (newId) {
        try {
          await disposeTrack(newId);
        } catch {}
      }
      console.error('Failed to start WebRTC track', err);
    } finally {
      setCreating(false);
    }
  };

  const onStop = async () => {
    if (!trackId && !sourceId) return;
    try {
      if (trackId) await disposeTrack(trackId);
      if (sourceId) await disposeSource(sourceId);
    } catch (e) {
      console.warn('Failed to dispose track', e);
    } finally {
      setTrackId(null);
      setSourceId(null);
      setStats(null);
    }
  };

  React.useEffect(() => {
    return () => {
      if (trackId) {
        disposeTrack(trackId).catch(() => {});
      }
    };
  }, [trackId]);

  const onGetStats = React.useCallback(async () => {
    const s = await getStats(trackId ?? undefined);
    if (s)
      setStats({
        producedFps: s.producedFps,
        deliveredFps: s.deliveredFps,
        droppedFrames: s.droppedFrames,
      });
  }, [trackId]);

  React.useEffect(() => {
    if (!trackId) return;
    const t = setInterval(onGetStats, 1000);
    return () => clearInterval(t);
  }, [trackId, onGetStats]);

  const onFlip = async () => {
    if (!sourceId) return;
    const next = facing === 'back' ? 'front' : 'back';
    setFacing(next);
    // Turning torch off when flipping avoids devices without torch (e.g., front)
    setTorch(false);
    await updateSource(sourceId, {position: next});
  };

  const onTorch = async () => {
    if (!sourceId) return;
    const next = !torch;
    setTorch(next);
    await updateSource(sourceId, {torch: next});
  };

  const onFps = async (fps: number) => {
    if (!trackId) return;
    console.log('onFps', fps);
    await updateTrack(trackId, {fps});
  };

  const onToggleBackpressure = async () => {
    const order: Array<'drop-late' | 'latest-wins' | 'throttle'> = [
      'drop-late',
      'latest-wins',
      'throttle',
    ];
    const currentIndex = order.indexOf(backpressure);
    const idx = currentIndex === -1 ? 0 : (currentIndex + 1) % order.length;
    const next = order[idx] as 'drop-late' | 'latest-wins' | 'throttle';
    setBackpressure(next);
    if (trackId) {
      await updateTrack(trackId, {backpressure: next});
    }
  };

  return (
    <SafeAreaView edges={['top']} style={styles.container}>
      <View style={styles.preview}>
        {device && (
          <Camera
            ref={cameraRef}
            style={StyleSheet.absoluteFill}
            device={device}
            isActive={true}
            torch={torch && device?.hasTorch ? 'on' : 'off'}
          />
        )}
        <VisionRTCView trackId={trackId ?? ''}>
          <Text style={[styles.trackId, {marginTop: insets.top + 20}]}>
            {trackId ?? 'No track id'}
          </Text>
        </VisionRTCView>
        <View style={styles.hud}>
          <Text style={styles.hudText}>
            {`prod: ${stats?.producedFps ?? 0} deliv: ${stats?.deliveredFps ?? 0} drops: ${stats?.droppedFrames ?? 0}`}
          </Text>
        </View>
      </View>
      <View style={styles.controls}>
        <View style={styles.btn}>
          <Button title="Start" onPress={onStart} />
        </View>
        <View style={styles.btn}>
          <Button title="Stop" onPress={onStop} />
        </View>
        <View style={styles.btn}>
          <Button title="Flip" onPress={onFlip} />
        </View>
        <View style={styles.btn}>
          <Button
            title={torch ? 'Torch Off' : 'Torch On'}
            onPress={onTorch}
            disabled={!device?.hasTorch}
          />
        </View>
        <View style={styles.btn}>
          <Button title="15 fps" onPress={() => onFps(15)} />
        </View>
        <View style={styles.btn}>
          <Button title="30 fps" onPress={() => onFps(30)} />
        </View>
        <View style={styles.btn}>
          <Button
            title={`BP: ${backpressure}`}
            onPress={onToggleBackpressure}
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffff',
    justifyContent: 'center',
    alignItems: 'center',
  },
  controls: {
    padding: 12,
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  btn: {minWidth: 120, margin: 6},
  preview: {
    flex: 1,
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  hud: {
    position: 'absolute',
    bottom: 30,
    right: 0,
    left: 0,
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  hudText: {
    color: '#fff',
    fontSize: 14,
  },
  trackId: {
    color: 'gray',
    fontSize: 14,
    textAlign: 'center',
  },
});
