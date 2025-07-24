//
//  FreshpaintDemoApp.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 20/06/2025.
//

import SwiftUI
import FreshpaintSDK

@main
struct FreshpaintDemoApp: App {
    init() {
        // Load write key from Config.plist
        let writeKey = Self.loadWriteKey()
        let config = FreshpaintConfiguration(writeKey: writeKey)
        
        // Core tracking features
        config.trackApplicationLifecycleEvents = true
        config.recordScreenViews = true
        
        // Performance and batching configuration
        config.flushAt = 20  // Send after 20 events
        config.flushInterval = 30  // Send every 30 seconds
        config.maxQueueSize = 1000  // Max events in queue
        
        // Session configuration
        config.sessionTimeout = 1800  // 30 minutes session timeout
        
        // Privacy and tracking settings
        config.enableAdvertisingTracking = true
        config.shouldUseLocationServices = false  // Disabled by default
        config.shouldUseBluetooth = false  // Disabled by default
        
        // Advanced tracking features
        config.trackInAppPurchases = true
        config.trackPushNotifications = true
        config.trackDeepLinks = true
        
        // Enable debug logging for development
        #if DEBUG
        Freshpaint.debug(true)
        #endif
        
        Freshpaint.setup(with: config)
    }
    
    // MARK: - Configuration Loading
    private static func loadWriteKey() -> String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let writeKey = plist["FreshpaintWriteKey"] as? String,
              writeKey != "YOUR_WRITE_KEY_HERE" else {
            fatalError("❌ Please set your Freshpaint write key in Config.plist")
        }
        return writeKey
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
