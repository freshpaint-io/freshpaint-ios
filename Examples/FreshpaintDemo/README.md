# FreshpaintDemo - Swift Package Manager Integration

A comprehensive demo iOS application showing how to integrate the Freshpaint SDK using **Swift Package Manager** (recommended approach).

> **💡 We recommend using Swift Package Manager** for Freshpaint SDK integration whenever possible, as it provides simpler setup, better Xcode integration, and automatic dependency resolution.

## 🚀 Quick Start

### Prerequisites
- iOS 15.1+
- Xcode 16.4+
- Swift 5.0+

### Installation

1. **Clone or download the project**
2. **Open the project**:
   ```bash
   open FreshpaintDemo.xcodeproj
   ```
3. **Build and run** - the SDK is already configured!

## 📱 What's Included

This demo showcases **all major Freshpaint SDK features** through an interactive interface:

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

#### 1. Add Swift Package Dependency

In Xcode:
1. Go to **File → Add Package Dependencies**
2. Enter: `https://github.com/freshpaint-io/freshpaint-ios`
3. Select version `0.3.0` or latest
4. Add to your target

#### 2. Import and Initialize

```swift
import SwiftUI
import Freshpaint  // Note: Use 'Freshpaint', not 'FreshpaintSDK'

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

#### 3. Start Tracking

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
FreshpaintDemo/
├── FreshpaintDemoApp.swift      # SDK initialization
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

- **Module Import**: For production apps, use `import Freshpaint` (this demo uses `import FreshpaintSDK` due to local development setup)
- **Write Key**: Replace the demo write key with your actual Freshpaint write key
- **Local Reference**: This demo uses a local SDK reference - use the GitHub URL for your project

## 📚 Next Steps

1. **Explore the Demo**: Try all features to understand capabilities
2. **Review Source Code**: See implementation patterns and best practices
3. **Integrate in Your App**: Follow the integration guide above
4. **Test Thoroughly**: Use debug logging to verify tracking

## 📖 Additional Resources

- [Freshpaint Documentation](https://docs.freshpaint.io)
- [iOS SDK GitHub Repository](https://github.com/freshpaint-io/freshpaint-ios)
- [Analytics Best Practices](https://docs.freshpaint.io/best-practices)

---

**Ready to add Freshpaint to your app?** This demo provides a complete reference implementation using Swift Package Manager - the recommended integration method!