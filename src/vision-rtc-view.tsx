import {View, Text} from 'react-native';

export default function VisionRTCView({trackId}: {trackId: string}) {
  return (
    <View style={{flex: 1}}>
      <Text>{trackId}</Text>
    </View>
  );
}
