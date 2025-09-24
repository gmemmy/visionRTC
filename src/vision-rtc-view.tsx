import {View, Text, StyleSheet} from 'react-native';

export default function VisionRTCView({trackId}: {trackId: string}) {
  return (
    <View style={styles.container}>
      <Text>{trackId}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
});
