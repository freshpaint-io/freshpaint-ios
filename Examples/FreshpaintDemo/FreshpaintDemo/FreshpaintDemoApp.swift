//
//  FreshpaintDemoApp.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 20/06/2025.
//

import SwiftUI
import Freshpaint

@main
struct FreshpaintDemoApp: App {
    init() {
        let config = FreshpaintConfiguration(writeKey: "ca88c2f6-ec3d-4ebc-964b-af0fb2f9cfe5")
        
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
