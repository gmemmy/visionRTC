import * as React from 'react';
import {Button, Text, StyleSheet} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {
  createWebRTCTrack,
  disposeTrack,
  getStats,
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
      <Button title="Start" onPress={onStart} />
      <Button title="Stop" onPress={onStop} />
      <Button title="Get Stats" onPress={onGetStats} />
      {stats && (
        <Text>{`fps: ${stats.fps} dropped: ${stats.droppedFrames}`}</Text>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
