import type {ReactNode} from 'react';
import {
  requireNativeComponent,
  StyleSheet,
  View,
  type ViewStyle,
  type StyleProp,
} from 'react-native';

type Props = {
  trackId?: string | null;
  style?: StyleProp<ViewStyle>;
  children?: ReactNode;
};

const NativeView = requireNativeComponent<{
  trackId: string;
  style?: StyleProp<ViewStyle>;
}>('VisionRTCView');

export default function VisionRTCView({trackId, style, children}: Props) {
  return (
    <View style={[styles.container, style]}>
      <NativeView
        trackId={trackId ?? ''}
        style={StyleSheet.absoluteFillObject}
      />
      {children}
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
