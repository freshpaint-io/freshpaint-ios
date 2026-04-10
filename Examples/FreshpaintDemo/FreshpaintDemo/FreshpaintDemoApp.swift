//
//  FreshpaintDemoApp.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 20/06/2025.
//

import SwiftUI
import AdSupport
import Freshpaint

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
        config.adSupportBlock = {
            ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
        config.shouldUseLocationServices = false  // Disabled by default
        config.shouldUseBluetooth = false  // Disabled by default
        
        // Advanced tracking features
        config.trackInAppPurchases = true
        config.trackPushNotifications = true
        config.trackDeepLinks = true
        
        // Enable debug logging and FRP-38 attribution UI in development only.
        #if DEBUG
        Freshpaint.debug(true)

        // Capture raw outgoing payloads and display attribution keys in the UI.
        config.experimental.rawFreshpaintModificationBlock = { payload in
            if let event = payload["event"] as? String {
                let ctx = payload["context"] as? [String: Any] ?? [:]
                let attrKeys = ctx.keys.filter { $0.hasPrefix("$") || $0.hasPrefix("utm_") }.sorted()
                var line = "EVENT: \(event)"
                if attrKeys.isEmpty {
                    line += "\n  [no click IDs / UTM in context]"
                } else {
                    for k in attrKeys {
                        line += "\n  \(k) = \(ctx[k] ?? "(nil)")"
                    }
                }
                AttributionEventLog.shared.append(line)
            }
            return payload
        }
        #endif

        Freshpaint.setup(with: config)
    }
    
    // MARK: - Configuration Loading
    private static func loadWriteKey() -> String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let writeKey = plist["FreshpaintWriteKey"] as? String,
              writeKey != "YOUR_WRITE_KEY_HERE" else {
            // No write key configured — run in demo mode (events won't be delivered)
            return "demo-mode-no-key"
        }
        return writeKey
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Freshpaint.shared().open(url, options: [:])
                }
        }
    }
}
