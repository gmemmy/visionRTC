import * as React from 'react';
import {Button, Text, StyleSheet, View} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {
  createWebRTCTrack,
  disposeTrack,
  getStats,
  VisionRTCView,
} from 'react-native-vision-rtc';

export default function App() {
  const [trackId, setTrackId] = React.useState<string | null>(null);
  const [stats, setStats] = React.useState<{
    fps: number;
    droppedFrames: number;
  } | null>(null);
  const [creating, setCreating] = React.useState(false);

  const onStart = async () => {
    if (creating || trackId) return;
    setCreating(true);
    let newId: string | null = null;
    try {
      const {trackId: id} = await createWebRTCTrack(
        {__nativeSourceId: 'null'},
        {
          fps: 30,
          resolution: {width: 1280, height: 720},
        }
      );
      newId = id;
      setTrackId(id);
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
    if (!trackId) return;
    try {
      await disposeTrack(trackId);
    } catch (e) {
      console.warn('Failed to dispose track', e);
    } finally {
      setTrackId(null);
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

  const onGetStats = async () => {
    const s = await getStats();
    if (s) setStats({fps: s.fps, droppedFrames: s.droppedFrames});
  };

  return (
    <SafeAreaView edges={['top']} style={styles.container}>
      <View style={styles.controls}>
        <Button title="Start" onPress={onStart} />
        <Button title="Stop" onPress={onStop} />
        <Button title="Get Stats" onPress={onGetStats} />
      </View>
      <View style={styles.preview}>
        <VisionRTCView trackId={trackId ?? ''} />
        <View style={styles.hud} pointerEvents="none">
          <Text style={styles.hudText}>
            {`fps: ${stats?.fps ?? 0} drops: ${stats?.droppedFrames ?? 0}`}
          </Text>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffff',
  },
  controls: {
    padding: 12,
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  preview: {
    flex: 1,
    alignItems: 'stretch',
    justifyContent: 'center',
  },
  fill: {flex: 1},
  hud: {
    position: 'absolute',
    bottom: 8,
    right: 8,
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  hudText: {
    color: '#fff',
    fontSize: 12,
  },
});
