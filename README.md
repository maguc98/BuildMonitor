# Build Monitor

A native SwiftUI iOS app for monitoring GitHub Actions builds across repositories.

## Current milestone

The first SwiftUI interface follows the approved pastel blue / lavender glass-style design:
- Repository dashboard and build-status summary
- Build detail with step timeline, log preview, and artifact panel
- History, notifications, and settings tabs
- XcodeGen project configuration
- GitHub Actions workflow for simulator/device builds and unsigned IPA artifact packaging

Current screens use clearly labeled demonstration data. GitHub authorization, live workflow synchronization, real logs, artifact downloads, and notifications are not connected yet.

## Build

Requires Xcode 15+ and XcodeGen. Run brew install xcodegen, then xcodegen generate. Build with:
xcodebuild -project BuildMonitor.xcodeproj -scheme BuildMonitor -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build

The GitHub Actions workflow runs on pushes to main and can also be started manually. It builds for simulator and iPhone, packages an unsigned IPA, and uploads it as an Actions artifact.

## Security

Do not commit personal access tokens, .p12 certificates, provisioning profiles, or signing secrets. Future GitHub credentials will be stored in the iOS Keychain.
