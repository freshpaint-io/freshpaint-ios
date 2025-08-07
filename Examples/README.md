# Freshpaint iOS SDK Examples

This directory contains example iOS applications demonstrating how to integrate the Freshpaint SDK into your projects using different dependency management approaches.

## Available Examples

### 🔸 FreshpaintDemo (Swift Package Manager) - **Recommended**
A complete demo app showing Freshpaint SDK integration using **Swift Package Manager**.

**We recommend using Swift Package Manager whenever possible** as it provides:
- Simpler setup and maintenance
- Better Xcode integration
- Automatic dependency resolution
- No additional tooling required

### 🔸 FreshpaintPodDemo (CocoaPods)
The same demo app functionality using **CocoaPods** integration for projects that require or prefer CocoaPods.

## Quick Start

### Option 1: Swift Package Manager (Recommended)

1. Open `FreshpaintDemo/FreshpaintDemo.xcodeproj`
2. **Set up your API key**:
   ```bash
   cd FreshpaintDemo/FreshpaintDemo/
   cp Config.plist.example Config.plist
   ```
   Edit `Config.plist` and replace `YOUR_WRITE_KEY_HERE` with your actual Freshpaint write key
3. Build and run the project

### Option 2: CocoaPods

1. Navigate to `FreshpaintPodDemo/`
2. Run `pod install`
3. Open `FreshpaintPodDemo.xcworkspace`
4. **Set up your API key**:
   ```bash
   cd FreshpaintPodDemo/FreshpaintPodDemo/
   cp Config.plist.example Config.plist
   ```
   Edit `Config.plist` and replace `YOUR_WRITE_KEY_HERE` with your actual Freshpaint write key
5. Build and run the project

## What's Included

Both demo apps showcase identical functionality:

- **SDK Initialization**: Proper configuration and setup
- **Event Tracking**: Custom events with properties
- **User Identification**: User identity management and traits
- **Screen Tracking**: Automatic and manual screen view tracking
- **Group Analytics**: Organization/team-level tracking
- **User Journeys**: Complete user lifecycle examples
- **Advanced Features**: Debugging, session management, and configuration options

## Integration Guide

### For Your Own Project

**Important**: These examples use local SDK references for development purposes. For your production app:

1. **Swift Package Manager**: Add the Freshpaint package from GitHub
2. **CocoaPods**: Use `pod 'Freshpaint', '~> 0.4.0'` in your Podfile

### 🔐 API Key Setup

Both example projects use a secure configuration approach to protect API keys:

1. **Copy the example config**:
   ```bash
   cp Config.plist.example Config.plist
   ```

2. **Edit `Config.plist`** and add your write key:
   ```xml
   <key>FreshpaintWriteKey</key>
   <string>your-actual-write-key-here</string>
   ```

3. **Important**: The `Config.plist` file is ignored by git to keep your API keys secure

See individual README files for detailed integration steps specific to each approach.

## Requirements

- iOS 15.1+
- Xcode 16.4+
- Swift 5.0+

## SDK Features Demonstrated

### Core Analytics
- Event tracking with custom properties
- Screen view tracking (automatic and manual)
- User identification and trait management
- Anonymous user tracking

### Advanced Features
- User aliasing and identity linking
- Group/organization analytics
- Session management and reset
- Debug logging and event inspection
- Batch event flushing
- Configuration options and privacy settings

### User Journey Tracking
- Onboarding flow analytics
- Feature adoption tracking
- Conversion funnel analysis
- User engagement metrics

## Support

For questions about the Freshpaint iOS SDK:

- 📖 [Full Documentation](https://docs.freshpaint.io)
- 💬 [Support Portal](https://support.freshpaint.io)
- 🐛 [Report Issues](https://github.com/freshpaint-io/freshpaint-ios/issues)

## License

These examples are provided under the same license as the Freshpaint iOS SDK.
