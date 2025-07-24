# FreshpaintPodDemo - CocoaPods Integration

A comprehensive demo iOS application showing how to integrate the Freshpaint SDK using **CocoaPods**.

> **💡 We recommend using Swift Package Manager** whenever possible for easier setup and better Xcode integration. Use this CocoaPods example only if your project requires CocoaPods or you prefer this dependency management approach.

## 🚀 Quick Start

### Prerequisites
- iOS 15.1+
- Xcode 16.4+
- CocoaPods installed (`gem install cocoapods`)

### Installation

1. **Clone or download the project**
2. **Install dependencies**:
   ```bash
   cd FreshpaintPodDemo
   pod install
   ```
3. **Open the workspace** (not the .xcodeproj):
   ```bash
   open FreshpaintPodDemo.xcworkspace
   ```
4. **Build and run** - the SDK is already configured!

## 📱 What's Included

This demo showcases **identical functionality** to the Swift Package Manager version, demonstrating all major Freshpaint SDK features:

### Core Features Tab 🎯
- **Event Tracking**: Custom events with properties
- **Screen Tracking**: Automatic and manual screen views
- **User Identity**: Anonymous and identified user management
- **User Aliasing**: Link anonymous activity to identified users
- **Group Analytics**: Organization/team tracking
- **Session Management**: Flush and reset functionality

### User Journey Tab 👤
- **Complete User Lifecycle**: From anonymous visitor to power user
- **7 Journey Stages**: Each with specific tracking examples
- **Real-world Scenarios**: Onboarding, feature adoption, conversions

### Advanced Features Tab ⚙️
- **SDK Configuration**: Real-time settings monitoring
- **Performance Testing**: Batch events and stress testing
- **Debug Logging**: Comprehensive event inspection
- **Session Information**: Anonymous ID, session details

## 🔧 SDK Integration Guide

### For Your Own Project

**Important**: This demo uses a local SDK reference for development. For your production app:

#### 1. Add to Podfile

Create or update your `Podfile`:

```ruby
platform :ios, '15.1'

target 'YourApp' do
  use_frameworks!
  
  # Add Freshpaint SDK
  pod 'Freshpaint', '~> 0.3.0'
  
  # Your other dependencies...
end
```

#### 2. Install Dependencies

```bash
pod install
```

#### 3. Get Your API Key

1. **Create a Freshpaint Account**: Sign up at [https://freshpaint.io](https://freshpaint.io)
2. **Get Your Write Key**: Navigate to your project settings to find your unique write key
3. **Replace the Demo Key**: The demo uses a placeholder key that won't send real data

#### 4. Import and Initialize

```swift
import SwiftUI
import FreshpaintSDK  // Note: CocoaPods uses 'FreshpaintSDK' module name

@main
struct YourApp: App {
    init() {
        let config = FreshpaintConfiguration(writeKey: "YOUR_WRITE_KEY_HERE")
        
        // Configure tracking features
        config.trackApplicationLifecycleEvents = true
        config.recordScreenViews = true
        
        // Performance settings
        config.flushAt = 20
        config.flushInterval = 30
        config.maxQueueSize = 1000
        
        // Initialize SDK
        Freshpaint.setup(with: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 5. Start Tracking

```swift
// Track events
Freshpaint.shared().track("Button Tapped", properties: [
    "button_name": "get_started",
    "screen": "home"
])

// Identify users
Freshpaint.shared().identify("user_123", traits: [
    "name": "John Doe",
    "email": "john@example.com"
])

// Track screens
Freshpaint.shared().screen("Home Screen", properties: [
    "tab": "main"
])
```

## ⚠️ CocoaPods-Specific Setup

### User Script Sandboxing Fix

If you encounter this build error:
```
Sandbox: rsync(xxxxx) deny(1) file-write-create /Users/.../FreshpaintSDK.framework/.FreshpaintSDK.xxxxxx
```

**Solution**: Disable User Script Sandboxing in your project settings:

1. Open your project settings in Xcode
2. Select your app target
3. Go to **Build Settings**
4. Search for "User Script Sandboxing"
5. Set **"Enable User Script Sandboxing"** to **No** for both Debug and Release

**Why this happens**: Xcode's User Script Sandboxing blocks CocoaPods framework embedding scripts from writing to the app bundle.

### Module Import Differences

| Integration Method | Import Statement |
|-------------------|------------------|
| **Swift Package Manager** | `import Freshpaint` |
| **CocoaPods** | `import FreshpaintSDK` |

## 📊 Key SDK Methods

### Essential Tracking Methods
- `track()` - Custom events with properties
- `screen()` - Screen view tracking
- `identify()` - User identification with traits
- `alias()` - Link anonymous to identified users
- `group()` - Associate users with organizations
- `flush()` - Force send queued events
- `reset()` - Clear user session data

### Configuration Options
- **Batch Settings**: Control when events are sent
- **Privacy Controls**: Location, Bluetooth, advertising tracking
- **Session Management**: Timeout and lifecycle tracking
- **Debug Features**: Development logging and testing

## 🔍 Debug and Testing

### Enable Debug Logging
```swift
#if DEBUG
Freshpaint.debug(true)  // Development only
#endif
```

### Testing Features in Demo
- **Real-time Logs**: See all SDK activity
- **Performance Tests**: Batch events, stress testing
- **Network Simulation**: Test offline scenarios
- **Session Monitoring**: Track user state changes

## 🏗️ Project Structure

```
FreshpaintPodDemo/
├── FreshpaintPodDemo.xcworkspace    # Use this to open project
├── FreshpaintPodDemo.xcodeproj      # Xcode project file
├── Podfile                          # CocoaPods dependencies
├── Pods/                            # Generated CocoaPods files
└── FreshpaintPodDemo/
    ├── FreshpaintPodDemoApp.swift   # SDK initialization
    ├── ContentView.swift            # Core features demo
    ├── UserJourneyView.swift        # User lifecycle examples
    ├── AdvancedFeaturesView.swift   # Testing and configuration
    └── DebugLogView.swift          # Debug log viewer
```

## 💡 Best Practices

### 1. Event Naming
- Use consistent naming conventions
- Include relevant context in properties
- Structure data logically

### 2. User Identity
- Start with anonymous tracking
- Use `alias()` when users sign up
- Update traits as you learn more

### 3. Performance
- Let the SDK batch events automatically
- Use `flush()` only when needed
- Configure batch size for your use case

### 4. Privacy
- Control tracking permissions appropriately
- Use `reset()` when users log out
- Filter sensitive data

## 🚨 Important Notes

- **API Key Required**: You **must** replace the demo write key with your own from [freshpaint.io](https://freshpaint.io) - the demo key won't send real data
- **Always use `.xcworkspace`**: Open `FreshpaintPodDemo.xcworkspace`, not the `.xcodeproj`
- **Module Import**: Use `import FreshpaintSDK` (this differs from Swift Package Manager)
- **Local Reference**: This demo uses `:path => '../..'` - use `pod 'Freshpaint', '~> 0.3.0'` for your project
- **User Script Sandboxing**: Disable if you encounter framework embedding errors
- **Account Setup**: Create a free account at [https://freshpaint.io](https://freshpaint.io) to get started

## 📚 Next Steps

1. **Create Freshpaint Account**: Sign up at [https://freshpaint.io](https://freshpaint.io) to get your write key
2. **Explore the Demo**: Try all features to understand capabilities
3. **Review Source Code**: See implementation patterns and best practices
4. **Integrate in Your App**: Follow the integration guide above
5. **Configure Build Settings**: Ensure User Script Sandboxing is disabled
6. **Test Thoroughly**: Use debug logging to verify tracking

## 📖 Additional Resources

- [Freshpaint Documentation](https://docs.freshpaint.io)
- [iOS SDK GitHub Repository](https://github.com/freshpaint-io/freshpaint-ios)
- [CocoaPods Documentation](https://guides.cocoapods.org)
- [Analytics Best Practices](https://docs.freshpaint.io/best-practices)

---

**Need CocoaPods integration?** This demo provides a complete reference implementation, including solutions for common CocoaPods-specific issues.