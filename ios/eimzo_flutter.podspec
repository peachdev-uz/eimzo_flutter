Pod::Spec.new do |s|
  s.name             = 'eimzo_flutter'
  s.version          = '1.1.8'
  s.summary          = 'Flutter plugin wrapping the E-IMZO Mobile SDK (iOS).'
  s.description      = <<-DESC
    Flutter plugin wrapping the official E-IMZO Mobile SDK for Uzbekistan
    electronic signatures. Bundles the closed-source EimzoSDK.xcframework
    (downloaded from the public release on pod install).
  DESC
  s.homepage         = 'https://github.com/peachdev-uz/eimzo_flutter'
  s.license          = { :type => 'Closed-source', :text => 'See LICENSE in the github repo.' }
  s.author           = { 'PeachDev' => 'info@peachdev.uz' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'

  # Pull the pre-built xcframeworks from the public GitHub release on every
  # `pod install`. Keeps the pub.dev package small (no 24 MB of binaries
  # checked in) and lets us roll the SDK independently of the plugin.
  #
  # 1.1.5+ ships TWO sibling xcframeworks instead of one nested one —
  # App Store rejects nested frameworks (errors 90205/90206/90035).
  # Both go into App.app/Frameworks/ at the top level.
  EIMZO_SDK_VERSION = '1.1.6'
  EIMZO_SDK_URL  = "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/#{EIMZO_SDK_VERSION}/EimzoSDK.xcframework.zip"
  PFX2QR_URL     = "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/#{EIMZO_SDK_VERSION}/Pfx2qr.xcframework.zip"

  s.prepare_command = <<-CMD
    set -e
    # Detect a stale pre-1.1.5 EimzoSDK that has Pfx2qr nested inside —
    # that layout is rejected by App Store. Wipe and re-download both.
    if [ -d EimzoSDK.xcframework ] && \
       find EimzoSDK.xcframework -path '*/EimzoSDK.framework/Frameworks/Pfx2qr.framework' -maxdepth 5 | grep -q .; then
      echo ">> Removing stale nested EimzoSDK.xcframework (pre-1.1.5)..."
      rm -rf EimzoSDK.xcframework Pfx2qr.xcframework
    fi
    if [ ! -d EimzoSDK.xcframework ]; then
      echo ">> Downloading EimzoSDK #{EIMZO_SDK_VERSION}..."
      curl -sSL -o EimzoSDK.xcframework.zip "#{EIMZO_SDK_URL}"
      unzip -q EimzoSDK.xcframework.zip
      rm EimzoSDK.xcframework.zip
    fi
    if [ ! -d Pfx2qr.xcframework ]; then
      echo ">> Downloading Pfx2qr #{EIMZO_SDK_VERSION}..."
      curl -sSL -o Pfx2qr.xcframework.zip "#{PFX2QR_URL}"
      unzip -q Pfx2qr.xcframework.zip
      rm Pfx2qr.xcframework.zip
    fi
  CMD

  s.vendored_frameworks = 'EimzoSDK.xcframework', 'Pfx2qr.xcframework'

  # Disable bitcode (Apple removed bitcode support in Xcode 14; our xcframework
  # is built without it).
  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'ENABLE_BITCODE'                => 'NO',
  }

  # NFC entitlement + camera permission are the integrator's responsibility,
  # documented in the plugin's README. No Info.plist injection here — the
  # host app declares its own NSCameraUsageDescription etc.
end
