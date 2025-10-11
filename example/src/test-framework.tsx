import * as React from "react";
import {View, Text, Button, StyleSheet, ScrollView, Alert} from "react-native";
import {SafeAreaView, useSafeAreaInsets} from "react-native-safe-area-context";
import {
  Camera,
  useCameraDevice,
  useFrameProcessor,
} from "react-native-vision-camera";
import {
  createVisionCameraSource,
  createWebRTCTrack,
  disposeTrack,
  disposeSource,
  getStats,
} from "react-native-vision-rtc";
import {findNodeHandle} from "react-native";
import {
  processFrame,
  setSourceId,
  clearSourceId,
  getFrameCount,
} from "./vision-camera-frame-processor";

type TestResult = {
  name: string;
  status: "pending" | "running" | "passed" | "failed";
  message?: string;
  duration?: number;
};

type TestSuite = {
  name: string;
  tests: TestResult[];
};

type TestFrameworkProps = {
  onBack?: () => void;
};

export default function TestFramework({onBack}: TestFrameworkProps = {}) {
  const [testSuites, setTestSuites] = React.useState<TestSuite[]>([]);
  const [isRunning, setIsRunning] = React.useState(false);
  const cameraRef = React.useRef<Camera>(null);
  const device = useCameraDevice("back");

  const insets = useSafeAreaInsets();

  // Test state
  const [currentSourceId, setCurrentSourceId] = React.useState<string | null>(
    null
  );
  const [currentTrackId, setCurrentTrackId] = React.useState<string | null>(
    null
  );

  // Frame processor for testing actual frame delivery
  const frameProcessor = useFrameProcessor((frame) => {
    processFrame(frame);
  }, []);

  const updateTestResult = React.useCallback(
    (suiteName: string, testName: string, result: Partial<TestResult>) => {
      setTestSuites((prev) =>
        prev.map((suite) =>
          suite.name === suiteName
            ? {
                ...suite,
                tests: suite.tests.map((test) =>
                  test.name === testName ? {...test, ...result} : test
                ),
              }
            : suite
        )
      );
    },
    []
  );

  const runTest = React.useCallback(
    async (
      suiteName: string,
      testName: string,
      testFn: () => Promise<void>
    ) => {
      const startTime = Date.now();
      updateTestResult(suiteName, testName, {status: "running"});

      try {
        await testFn();
        const duration = Date.now() - startTime;
        updateTestResult(suiteName, testName, {
          status: "passed",
          message: `✅ Passed in ${duration}ms`,
          duration,
        });
      } catch (error) {
        const duration = Date.now() - startTime;
        updateTestResult(suiteName, testName, {
          status: "failed",
          message: `❌ ${error instanceof Error ? error.message : String(error)}`,
          duration,
        });
      }
    },
    [updateTestResult]
  );

  // Initialize test suites
  React.useEffect(() => {
    setTestSuites([
      {
        name: "Core Integration",
        tests: [
          {name: "Create Vision Camera Source", status: "pending"},
          {name: "Create WebRTC Track", status: "pending"},
          {name: "Setup Frame Processor", status: "pending"},
          {name: "Test Frame Delivery", status: "pending"},
          {name: "Dispose Resources", status: "pending"},
        ],
      },
      {
        name: "Memory Management",
        tests: [
          {name: "Multiple Track Creation/Disposal", status: "pending"},
          {name: "Source Disposal Cleanup", status: "pending"},
          {name: "Track Pause/Resume Cleanup", status: "pending"},
        ],
      },
      {
        name: "Performance",
        tests: [
          {name: "Frame Delivery Latency", status: "pending"},
          {name: "Statistics Accuracy", status: "pending"},
          {name: "High FPS Handling", status: "pending"},
        ],
      },
      {
        name: "Error Handling",
        tests: [
          {name: "Invalid Source ID", status: "pending"},
          {name: "Invalid Pixel Buffer", status: "pending"},
          {name: "Unsupported Pixel Format", status: "pending"},
        ],
      },
    ]);
  }, []);

  // Test implementations
  const testCreateVisionCameraSource = React.useCallback(async () => {
    const node = findNodeHandle(cameraRef.current);
    if (!node) throw new Error("Camera ref not available");

    const result = await createVisionCameraSource(node);
    if (!result.__nativeSourceId) throw new Error("No source ID returned");

    setCurrentSourceId(result.__nativeSourceId);
  }, []);

  const testCreateWebRTCTrack = React.useCallback(async () => {
    if (!currentSourceId) throw new Error("No source ID available");

    const result = await createWebRTCTrack(
      {__nativeSourceId: currentSourceId},
      {
        fps: 30,
        resolution: {width: 1280, height: 720},
        backpressure: "drop-late",
        mode: "external",
      }
    );

    if (!result.trackId) throw new Error("No track ID returned");
    setCurrentTrackId(result.trackId);
  }, [currentSourceId]);

  const testSetupFrameProcessor = React.useCallback(async () => {
    if (!currentSourceId) throw new Error("No source ID available");

    setSourceId(currentSourceId);

    const NativeVisionRTC =
      require("react-native-vision-rtc/src/NativeVisionRtc").default;
    if (!NativeVisionRTC.deliverFrame) {
      throw new Error("deliverFrame method not available");
    }

    console.log("✅ Frame processor setup complete");
  }, [currentSourceId]);

  const testFrameDelivery = React.useCallback(async () => {
    if (!currentSourceId || !currentTrackId) {
      throw new Error("Source ID and Track ID required");
    }

    // Wait for frames to be processed
    const initialFrameCount = getFrameCount();

    // Wait up to 3 seconds for frames to be delivered
    let attempts = 0;
    const maxAttempts = 30; // 3 seconds at 100ms intervals

    while (attempts < maxAttempts) {
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 100));
      const currentFrameCount = getFrameCount();

      if (currentFrameCount > initialFrameCount) {
        // Get stats to verify frames are being delivered to WebRTC
        const stats = await getStats(currentTrackId);
        if (stats && (stats.producedFps > 0 || stats.deliveredFps > 0)) {
          console.log(
            `✅ Frame delivery working! Processed ${currentFrameCount} frames, Stats:`,
            stats
          );
          return;
        }
      }

      attempts++;
    }

    throw new Error(
      `No frames delivered after ${maxAttempts * 100}ms. Frame count: ${getFrameCount()}`
    );
  }, [currentSourceId, currentTrackId]);

  const testDisposeResources = React.useCallback(async () => {
    // Clear frame processor first
    clearSourceId();

    if (currentTrackId) {
      await disposeTrack(currentTrackId);
      setCurrentTrackId(null);
    }
    if (currentSourceId) {
      await disposeSource(currentSourceId);
      setCurrentSourceId(null);
    }
  }, [currentTrackId, currentSourceId]);

  const testMultipleTrackCreationDisposal = React.useCallback(async () => {
    if (!currentSourceId) throw new Error("No source ID available");

    const trackIds: string[] = [];

    // Create multiple tracks
    for (let i = 0; i < 3; i++) {
      const result = await createWebRTCTrack(
        {__nativeSourceId: currentSourceId},
        {fps: 15, resolution: {width: 640, height: 480}}
      );
      trackIds.push(result.trackId);
    }

    // Dispose all tracks
    for (const trackId of trackIds) {
      await disposeTrack(trackId);
    }
  }, [currentSourceId]);

  const testFrameDeliveryLatency = React.useCallback(async () => {
    if (!currentTrackId) throw new Error("No track ID available");

    const startTime = Date.now();
    const stats = await getStats(currentTrackId);
    const latency = Date.now() - startTime;

    if (latency > 50) {
      throw new Error(`Stats query too slow: ${latency}ms`);
    }

    console.log(`Stats query latency: ${latency}ms`, stats);
  }, [currentTrackId]);

  const testInvalidSourceId = React.useCallback(async () => {
    const NativeVisionRTC =
      require("react-native-vision-rtc/src/NativeVisionRtc").default;

    try {
      // This should fail with validation error
      await NativeVisionRTC.deliverFrame("", null, 0);
      throw new Error("Should have failed with invalid source ID");
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.includes("INVALID_SOURCE_ID")
      ) {
        return; // Expected error
      }
      throw error;
    }
  }, []);

  const runCoreIntegrationTests = React.useCallback(async () => {
    await runTest(
      "Core Integration",
      "Create Vision Camera Source",
      testCreateVisionCameraSource
    );
    await runTest(
      "Core Integration",
      "Create WebRTC Track",
      testCreateWebRTCTrack
    );
    await runTest(
      "Core Integration",
      "Setup Frame Processor",
      testSetupFrameProcessor
    );
    await runTest("Core Integration", "Test Frame Delivery", testFrameDelivery);
    await runTest(
      "Core Integration",
      "Dispose Resources",
      testDisposeResources
    );
  }, [
    runTest,
    testCreateVisionCameraSource,
    testCreateWebRTCTrack,
    testSetupFrameProcessor,
    testFrameDelivery,
    testDisposeResources,
  ]);

  const runMemoryManagementTests = React.useCallback(async () => {
    await runTest(
      "Core Integration",
      "Create Vision Camera Source",
      testCreateVisionCameraSource
    );

    await runTest(
      "Memory Management",
      "Multiple Track Creation/Disposal",
      testMultipleTrackCreationDisposal
    );
    await runTest(
      "Memory Management",
      "Source Disposal Cleanup",
      testDisposeResources
    );
  }, [
    runTest,
    testCreateVisionCameraSource,
    testMultipleTrackCreationDisposal,
    testDisposeResources,
  ]);

  const runPerformanceTests = React.useCallback(async () => {
    await runTest(
      "Core Integration",
      "Create Vision Camera Source",
      testCreateVisionCameraSource
    );
    await runTest(
      "Core Integration",
      "Create WebRTC Track",
      testCreateWebRTCTrack
    );

    await runTest(
      "Performance",
      "Frame Delivery Latency",
      testFrameDeliveryLatency
    );

    await runTest(
      "Core Integration",
      "Dispose Resources",
      testDisposeResources
    );
  }, [
    runTest,
    testCreateVisionCameraSource,
    testCreateWebRTCTrack,
    testFrameDeliveryLatency,
    testDisposeResources,
  ]);

  const runErrorHandlingTests = React.useCallback(async () => {
    await runTest("Error Handling", "Invalid Source ID", testInvalidSourceId);
  }, [runTest, testInvalidSourceId]);

  const runAllTests = React.useCallback(async () => {
    if (isRunning) return;

    setIsRunning(true);

    try {
      await Camera.requestCameraPermission();

      await runCoreIntegrationTests();
      await runMemoryManagementTests();
      await runPerformanceTests();
      await runErrorHandlingTests();

      Alert.alert("Tests Complete", "All test suites have finished running");
    } catch (error) {
      Alert.alert("Test Error", `Failed to run tests: ${error}`);
    } finally {
      setIsRunning(false);
    }
  }, [
    isRunning,
    runCoreIntegrationTests,
    runMemoryManagementTests,
    runPerformanceTests,
    runErrorHandlingTests,
  ]);

  const getOverallStatus = () => {
    const allTests = testSuites.flatMap((suite) => suite.tests);
    const passed = allTests.filter((t) => t.status === "passed").length;
    const failed = allTests.filter((t) => t.status === "failed").length;
    const total = allTests.length;

    return {passed, failed, total};
  };

  const {passed, failed, total} = getOverallStatus();

  return (
    <SafeAreaView edges={["left", "right", "bottom"]} style={styles.container}>
      <View style={styles.content}>
        <View style={[styles.header, {paddingTop: insets.top + 20}]}>
          <Text style={styles.title}>VisionRTC Test Framework</Text>
          <Text style={styles.subtitle}>
            {passed}/{total} passed • {failed} failed
          </Text>
          <View style={styles.buttonRow}>
            {onBack && (
              <Button title="← Back" onPress={onBack} disabled={isRunning} />
            )}
            <Button
              title={isRunning ? "Running..." : "Run All Tests"}
              onPress={runAllTests}
              disabled={isRunning}
            />
          </View>
        </View>

        {device && (
          <Camera
            ref={cameraRef}
            style={styles.camera}
            device={device}
            isActive={true}
            frameProcessor={frameProcessor}
          />
        )}

        <ScrollView style={styles.results}>
          {testSuites.map((suite) => (
            <View key={suite.name} style={styles.suite}>
              <Text style={styles.suiteName}>{suite.name}</Text>
              {suite.tests.map((test) => (
                <View key={test.name} style={styles.test}>
                  <View style={styles.testHeader}>
                    <Text style={styles.testName}>{test.name}</Text>
                    <Text style={[styles.status, styles[test.status]]}>
                      {test.status.toUpperCase()}
                    </Text>
                  </View>
                  {test.message && (
                    <Text style={styles.message}>{test.message}</Text>
                  )}
                </View>
              ))}
            </View>
          ))}
        </ScrollView>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  content: {
    flex: 1,
  },
  header: {
    padding: 20,
    backgroundColor: "#fff",
    borderBottomWidth: 1,
    borderBottomColor: "#ddd",
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    marginBottom: 5,
  },
  subtitle: {
    fontSize: 16,
    color: "#666",
    marginBottom: 15,
  },
  camera: {
    height: 100,
    backgroundColor: "#000",
  },
  results: {
    flex: 1,
    padding: 15,
  },
  suite: {
    backgroundColor: "#fff",
    marginBottom: 15,
    borderRadius: 8,
    padding: 15,
  },
  suiteName: {
    fontSize: 18,
    fontWeight: "bold",
    marginBottom: 10,
    color: "#333",
  },
  test: {
    marginBottom: 10,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#eee",
  },
  testHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  testName: {
    fontSize: 16,
    flex: 1,
  },
  status: {
    fontSize: 12,
    fontWeight: "bold",
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  pending: {
    backgroundColor: "#f0f0f0",
    color: "#666",
  },
  running: {
    backgroundColor: "#fff3cd",
    color: "#856404",
  },
  passed: {
    backgroundColor: "#d4edda",
    color: "#155724",
  },
  failed: {
    backgroundColor: "#f8d7da",
    color: "#721c24",
  },
  message: {
    fontSize: 14,
    color: "#666",
    marginTop: 5,
    fontFamily: "monospace",
  },
  buttonRow: {
    flexDirection: "row",
    gap: 10,
    justifyContent: "space-between",
  },
});
