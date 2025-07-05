# Freshpaint iOS SDK Demo

A comprehensive demonstration of the Freshpaint iOS SDK featuring all core functionality, advanced features, and best practices for implementation.

## 📱 Demo Features

This demo app showcases the complete range of Freshpaint iOS SDK capabilities through an interactive interface divided into three main sections:

### 1. **Core Features Tab** 🎯
- **Basic Event Tracking**: Send custom events with properties
- **Screen View Tracking**: Manual and automatic screen view recording
- **User Identification**: Anonymous and identified user tracking with traits
- **User Aliasing**: Link anonymous activity to identified users
- **Group Tracking**: Associate users with organizations/groups
- **Session Management**: Manual flush and reset functionality

### 2. **User Journey Tab** 👤
- **Complete User Lifecycle**: Step-by-step progression from anonymous visitor to power user
- **Journey Stages**:
  - Anonymous Visitor → Basic page views and interactions
  - Sign Up Interest → CTA tracking and form engagement
  - Account Creation → User identification and aliasing
  - Onboarding → Feature discovery and completion tracking
  - Active User → Regular engagement and feature usage
  - Premium Upgrade → Conversion and subscription tracking
  - Power User → Advanced feature usage and advocacy

### 3. **Advanced Features Tab** ⚙️
- **SDK Configuration**: Real-time configuration monitoring and testing
- **Session Information**: Anonymous ID, session ID, and device token display
- **Performance Testing**: Batch events, stress tests, and performance monitoring
- **Network Simulation**: Test various network conditions
- **Debug Logging**: Comprehensive logging with filtering and search
- **Memory Testing**: Large payload and nested data structure handling

## 🚀 Getting Started

### Prerequisites

- **iOS 15.0+** / **tvOS 12.0+**
- **Swift 5.9+**
- **Xcode 15.0+**

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone [repository-url]
   cd FreshpaintDemo
   ```

2. **Open in Xcode**:
   ```bash
   open FreshpaintDemo.xcodeproj
   ```

3. **The demo is pre-configured** with the Freshpaint iOS SDK via Swift Package Manager. The SDK dependency is already included in the project.

4. **Build and run** the project on your device or simulator.

## 🔧 SDK Configuration

The demo showcases comprehensive SDK configuration in `FreshpaintDemoApp.swift`:

```swift
let config = FreshpaintConfiguration(writeKey: "your-write-key")

// Core tracking features
config.trackApplicationLifecycleEvents = true
config.recordScreenViews = true

// Performance and batching
config.flushAt = 20  // Send after 20 events
config.flushInterval = 30  // Send every 30 seconds
config.maxQueueSize = 1000  // Max events in queue

// Session management
config.sessionTimeout = 1800  // 30 minutes

// Privacy settings
config.enableAdvertisingTracking = true
config.shouldUseLocationServices = false
config.shouldUseBluetooth = false

// Advanced features
config.trackInAppPurchases = true
config.trackPushNotifications = true
config.trackDeepLinks = true

Freshpaint.setup(with: config)
```

## 📊 Core SDK Methods Demonstrated

### Event Tracking
```swift
// Basic event tracking
Freshpaint.shared().track("Event Name", properties: [
    "property1": "value1",
    "property2": 123,
    "timestamp": Date()
])
```

### Screen Tracking
```swift
// Manual screen tracking
Freshpaint.shared().screen("Screen Name", properties: [
    "category": "demo",
    "manual": true
])
```

### User Identification
```swift
// Identify user with traits
Freshpaint.shared().identify("user-id", traits: [
    "name": "John Doe",
    "email": "john@example.com",
    "plan": "premium"
])
```

### User Aliasing
```swift
// Link anonymous user to identified user
Freshpaint.shared().alias("new-user-id")
```

### Group Tracking
```swift
// Associate user with group
Freshpaint.shared().group("group-id", traits: [
    "name": "Company Inc",
    "industry": "Technology",
    "employees": 100
])
```

### Session Management
```swift
// Force send queued events
Freshpaint.shared().flush()

// Reset user session
Freshpaint.shared().reset()
```

## 🧪 Testing Features

The demo includes comprehensive testing capabilities:

### Performance Testing
- **Batch Events**: Send multiple events simultaneously
- **Stress Testing**: Concurrent event sending across multiple threads
- **Memory Testing**: Large payloads and nested data structures

### Network Testing
- **Connection Simulation**: Test different network conditions
- **Offline Handling**: Queue events when offline

### Debug Features
- **Real-time Logging**: View all SDK activity with timestamps
- **Session Information**: Monitor anonymous ID, session ID, and device tokens
- **Configuration Monitoring**: Real-time SDK configuration display

## 📋 Demo Workflow

### For Beginners:
1. **Start with Core Features tab** to understand basic SDK functionality
2. **Use the User Journey tab** to see how analytics fit into a complete user lifecycle
3. **Explore Advanced Features** to understand configuration and debugging

### For Advanced Users:
1. **Review the codebase** to see implementation patterns
2. **Test performance scenarios** using the stress testing features
3. **Experiment with configuration options** in real-time
4. **Use debug logs** to understand SDK behavior

## 🏗️ Code Structure

```
FreshpaintDemo/
├── FreshpaintDemoApp.swift      # App initialization and SDK configuration
├── ContentView.swift            # Main tab interface and core features
├── UserJourneyView.swift        # Complete user lifecycle demonstration
├── AdvancedFeaturesView.swift   # Configuration and testing tools
└── DebugLogView.swift          # Debug log viewer with search/filter
```

## 🎯 Key Learning Points

### 1. **Event Properties Best Practices**
- Use consistent naming conventions
- Include relevant context (timestamps, user status, etc.)
- Structure data logically with nested objects when appropriate

### 2. **User Identity Management**
- Start with anonymous tracking
- Use `alias()` when transitioning from anonymous to identified
- Update user traits as you learn more about users

### 3. **Performance Considerations**
- Events are batched and sent automatically
- Use `flush()` sparingly for immediate delivery needs
- Configure batch size and intervals based on your needs

### 4. **Privacy Compliance**
- Control tracking permissions (location, bluetooth, advertising)
- Use `reset()` when users log out or opt out
- Filter sensitive data before sending

## 🔍 Debug and Troubleshooting

### Debug Logging
Enable debug logging to see SDK activity:
```swift
Freshpaint.debug(true)  // Enable in development only
```

### Common Issues
1. **Events not appearing**: Check network connectivity and write key
2. **User identity issues**: Ensure proper `alias()` usage during account creation
3. **Performance concerns**: Monitor batch configuration and queue sizes

### Debug Log Categories
- ✅ **Event Tracking**: Standard event and screen tracking
- 👤 **User Identity**: Identification, traits, and aliasing
- 🏢 **Group Operations**: Group association and properties
- 🔄 **Session Management**: Reset, flush, and session changes
- ⚡ **Performance**: Batch operations and stress testing
- ❌ **Errors**: Error simulation and handling

## 📚 Additional Resources

- [Freshpaint iOS SDK Documentation](https://docs.freshpaint.io/getting-started/ios-quickstart-guide/)
- [Freshpaint iOS SDK GitHub Repository](https://github.com/freshpaint-io/freshpaint-ios)
- [Analytics Best Practices](https://docs.freshpaint.io/best-practices/)

## 🤝 Contributing

This demo is designed to be educational and comprehensive. If you find issues or want to add features:

1. Fork the repository
2. Create a feature branch
3. Add your improvements
4. Submit a pull request

## 📄 License

This demo project follows the same license as the Freshpaint iOS SDK (MIT License).

---

## 💡 Quick Start Checklist

- [ ] Clone and open the project
- [ ] Build and run on device/simulator
- [ ] Explore the Core Features tab
- [ ] Walk through the User Journey flow
- [ ] Test Advanced Features and debugging tools
- [ ] Review the source code for implementation patterns
- [ ] Adapt patterns to your own project

**Ready to implement Freshpaint in your own app?** Use this demo as a reference for best practices and complete feature coverage!