require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "VisionRtc"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/gmemmy/react-native-vision-rtc.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
  s.private_header_files = "ios/**/*.h"
  s.swift_version = "5.0"
  s.requires_arc = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.dependency 'WebRTC-SDK'

  install_modules_dependencies(s)
end
