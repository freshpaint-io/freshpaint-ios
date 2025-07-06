# FreshpaintPodDemo

This is a demo iOS application that demonstrates how to integrate the Freshpaint SDK using CocoaPods 

## Project Setup

This project uses **CocoaPods** to integrate the Freshpaint SDK.

### Prerequisites

- Xcode 16.4+
- iOS 15.1+
- CocoaPods installed (`gem install cocoapods`)

### Installation

1. **Open the workspace** (not the `.xcodeproj`):
   ```bash
   open FreshpaintPodDemo.xcworkspace
   ```

2. **Local SDK Integration**: The project is configured to use the local Freshpaint SDK via CocoaPods:
   ```ruby
   pod 'Freshpaint', :path => '../..'
   ```

3. **Build and Run**: The project should build and run directly from Xcode.

## Key Configuration

### CocoaPods Setup

- **Podfile**: References the Freshpaint SDK using `:path => '../..'` (You should use `pod 'Freshpaint', '0.3.0'` instead)
- **Module Name**: Uses `FreshpaintSDK` (as defined in the podspec)
- **Import Statement**: `import FreshpaintSDK` (not `import Freshpaint`)

### CocoaPods Sandbox Error

**Problem**: Build fails with error:
```
Sandbox: rsync(xxxxx) deny(1) file-write-create /Users/.../FreshpaintSDK.framework/.FreshpaintSDK.xxxxxx
```

**Solution**: The project is pre-configured with `ENABLE_USER_SCRIPT_SANDBOXING = NO` to prevent this issue. If you encounter this error:

1. Open the project settings in Xcode
2. Select the FreshpaintPodDemo target
3. Go to Build Settings
4. Search for "User Script Sandboxing"
5. Set "Enable User Script Sandboxing" to **No** for both Debug and Release

**Why this happens**: Xcode's User Script Sandboxing feature blocks CocoaPods framework embedding scripts from writing to the app bundle directory.

### Module Import Issues

**Problem**: `import Freshpaint` doesn't work

**Solution**: Use `import FreshpaintSDK` instead. The module name is defined in the podspec as `FreshpaintSDK`.



## Project Structure

- **FreshpaintPodDemo.xcworkspace**: Main workspace file (use this to open the project)
- **FreshpaintPodDemo.xcodeproj**: Xcode project file
- **Podfile**: CocoaPods dependency configuration
- **Pods/**: CocoaPods generated files and local SDK integration
- **FreshpaintPodDemo/**: Source code directory

## SDK Features Demonstrated

This demo app showcases various Freshpaint SDK features:

- Basic SDK initialization and configuration
- Event tracking examples
- User journey tracking
- Advanced features and configurations
- Debug logging and development tools

## Bundle Identifier

- **App**: `io.freshpaint.FreshpaintPodDemo`

## Notes

- This project is specifically designed for **local development** with CocoaPods
- The project `FreshpaintDemo` project uses Swift Package Manager
- Both demo projects coexist and serve different integration methods
- Always use the `.xcworkspace` file when opening this project in Xcode
