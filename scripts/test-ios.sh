#!/bin/bash

# VisionRTC iOS Testing Script
# This script helps build and test the iOS implementation

set -e

echo "🧪 VisionRTC iOS Testing Script"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "VisionRtc.podspec" ]; then
    print_error "Please run this script from the root directory of the VisionRTC project"
    exit 1
fi

# Check if example directory exists
if [ ! -d "example" ]; then
    print_error "Example directory not found"
    exit 1
fi

print_status "Starting iOS testing process..."

# Step 1: Install dependencies
print_status "Installing dependencies..."
cd example

if [ ! -f "package.json" ]; then
    print_error "Example package.json not found"
    exit 1
fi

print_status "Installing npm dependencies..."
yarn install

# Step 2: Install iOS dependencies
print_status "Installing iOS dependencies..."
cd ios

if [ ! -f "Podfile" ]; then
    print_error "Podfile not found in example/ios"
    exit 1
fi

print_status "Running pod install..."
pod install

cd ..

# Step 3: Build the project
print_status "Building iOS project..."

# Check if we can build
if command -v xcodebuild &> /dev/null; then
    print_status "Building with xcodebuild..."
    xcodebuild -workspace ios/VisionRtcExample.xcworkspace \
               -scheme VisionRtcExample \
               -configuration Debug \
               -sdk iphonesimulator \
               -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
               build
    
    if [ $? -eq 0 ]; then
        print_success "iOS build completed successfully!"
    else
        print_error "iOS build failed"
        exit 1
    fi
else
    print_warning "xcodebuild not found. Please build manually in Xcode."
fi

# Step 4: Run static analysis
print_status "Running static analysis..."

# Check for common issues in Swift files
print_status "Checking Swift files for potential issues..."

# Check for retain cycles
if grep -r "self\." ../ios/*.swift | grep -v "weak self" | grep -v "unowned self" > /dev/null; then
    print_warning "Potential retain cycles found in Swift files. Review closures for [weak self] usage."
fi

# Check for force unwrapping
if grep -r "!" ../ios/*.swift | grep -v "// Force unwrap OK" > /dev/null; then
    print_warning "Force unwrapping found in Swift files. Consider using safe unwrapping."
fi

# Check for TODO/FIXME comments
if grep -r "TODO\|FIXME" ../ios/*.swift > /dev/null; then
    print_warning "TODO/FIXME comments found in Swift files:"
    grep -r "TODO\|FIXME" ../ios/*.swift || true
fi

# Step 5: Validate TypeScript types
print_status "Validating TypeScript types..."
cd ..

if command -v npx &> /dev/null; then
    npx tsc --noEmit
    if [ $? -eq 0 ]; then
        print_success "TypeScript validation passed!"
    else
        print_error "TypeScript validation failed"
        exit 1
    fi
else
    print_warning "TypeScript compiler not found. Skipping type checking."
fi

# Step 6: Run linting
print_status "Running linting..."
if command -v npx &> /dev/null; then
    npx eslint "**/*.{js,ts,tsx}" --max-warnings 0
    if [ $? -eq 0 ]; then
        print_success "Linting passed!"
    else
        print_warning "Linting found issues. Please fix them."
    fi
else
    print_warning "ESLint not found. Skipping linting."
fi

# Step 7: Generate test report template
print_status "Generating test report template..."

cat > TEST_RESULTS.md << EOF
# VisionRTC iOS Test Results - $(date)

## Environment
- iOS Version: [Fill in]
- Device: [Fill in]
- React Native Version: $(cd example && node -p "require('./package.json').dependencies['react-native']")
- Vision Camera Version: $(cd example && node -p "require('./package.json').dependencies['react-native-vision-camera']")

## Test Results

### Core Integration: ⏳ PENDING
- [ ] Create Vision Camera Source
- [ ] Create WebRTC Track  
- [ ] Setup Frame Processor
- [ ] Test Frame Delivery
- [ ] Dispose Resources

### Memory Management: ⏳ PENDING
- [ ] Multiple Track Creation/Disposal
- [ ] Source Disposal Cleanup
- [ ] Track Pause/Resume Cleanup

### Performance: ⏳ PENDING
- [ ] Frame Delivery Latency: ___ms
- [ ] Statistics Accuracy
- [ ] High FPS Handling

### Error Handling: ⏳ PENDING
- [ ] Invalid Source ID
- [ ] Invalid Pixel Buffer
- [ ] Unsupported Pixel Format

## Manual Testing Checklist

### Basic Functionality
- [ ] App launches without crashes
- [ ] Camera preview displays correctly
- [ ] Can create WebRTC tracks
- [ ] Statistics display updates
- [ ] Camera controls work (flip, torch, FPS)

### Memory Testing
- [ ] Memory usage stable over 5+ minutes
- [ ] No memory warnings in Xcode
- [ ] Track creation/disposal doesn't leak

### Performance Testing
- [ ] Smooth video at 30 FPS
- [ ] No frame drops under normal conditions
- [ ] Statistics update in real-time

## Overall Status: ⏳ TESTING IN PROGRESS

## Notes:
[Add any additional observations]

---
Generated by test-ios.sh on $(date)
EOF

print_success "Test report template generated: TEST_RESULTS.md"

# Step 8: Final instructions
echo ""
print_success "🎉 Build and validation completed!"
echo ""
print_status "Next steps:"
echo "1. Open example/ios/VisionRtcExample.xcworkspace in Xcode"
echo "2. Run the app on a device or simulator"
echo "3. Tap the '🧪 Tests' button to run automated tests"
echo "4. Fill out the TEST_RESULTS.md file with your findings"
echo "5. If tests pass, commit your changes!"
echo ""
print_status "Test framework location: example/src/TestFramework.tsx"
print_status "Test plan: TEST_PLAN.md"
print_status "Results template: TEST_RESULTS.md"
echo ""
print_warning "Remember: Test on a real device for best results!"