//
//  AdvancedFeaturesView.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 27/06/2025.
//

import SwiftUI
import FreshpaintSDK

struct AdvancedFeaturesView: View {
    @State private var debugLogsEnabled = false
    @State private var flushInterval: Double = 30
    @State private var flushAt: Double = 20
    @State private var maxQueueSize: Double = 1000
    @State private var debugLogs: [String] = []
    @State private var showingDebugView = false
    @State private var sessionInfo: [String: Any] = [:]
    @State private var deviceToken = "Not available"
    @State private var anonymousId = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                configurationSection
                sessionInfoSection
                deviceInfoSection
                testingSection
                debugButton
            }
            .padding()
        }
        .navigationTitle("Advanced Features")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDebugView) {
            DebugLogView(logs: debugLogs)
        }
        .onAppear {
            loadCurrentConfiguration()
            trackScreenView("Advanced Features")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("SDK Configuration & Testing")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Explore advanced SDK features, configuration options, and debugging tools")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var configurationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Configuration")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack {
                    Text("Debug Logging")
                    Spacer()
                    Toggle("", isOn: $debugLogsEnabled)
                        .onChange(of: debugLogsEnabled) { _, value in
                            toggleDebugLogging(value)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Flush Interval: \(Int(flushInterval))s")
                        Spacer()
                    }
                    Slider(value: $flushInterval, in: 10...300, step: 10)
                        .onChange(of: flushInterval) { _, value in
                            updateFlushInterval(value)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Flush At: \(Int(flushAt)) events")
                        Spacer()
                    }
                    Slider(value: $flushAt, in: 1...100, step: 1)
                        .onChange(of: flushAt) { _, value in
                            updateFlushAt(value)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Queue Size: \(Int(maxQueueSize))")
                        Spacer()
                    }
                    Slider(value: $maxQueueSize, in: 100...5000, step: 100)
                        .onChange(of: maxQueueSize) { _, value in
                            updateMaxQueueSize(value)
                        }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var sessionInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Session Information")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    loadSessionInfo()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "Anonymous ID", value: anonymousId)
                
                if let sessionId = sessionInfo["sessionId"] as? String {
                    InfoRow(title: "Session ID", value: sessionId)
                }
                
                if let isFirstEvent = sessionInfo["isFirstEventInSession"] as? Bool {
                    InfoRow(title: "First Event in Session", value: isFirstEvent ? "Yes" : "No")
                }
                
                InfoRow(title: "Device Token", value: deviceToken)
            }
            
            Button("Generate New Session") {
                generateNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var deviceInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Device & App Information")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "SDK Version", value: Freshpaint.version())
                InfoRow(title: "Platform", value: "iOS")
                InfoRow(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                InfoRow(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                InfoRow(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var testingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Testing & Debugging")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                TestButton(
                    title: "Batch Events",
                    icon: "rectangle.stack.fill",
                    color: .blue
                ) {
                    sendBatchEvents()
                }
                
                TestButton(
                    title: "Error Event",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    sendErrorEvent()
                }
                
                TestButton(
                    title: "Performance Test",
                    icon: "speedometer",
                    color: .orange
                ) {
                    runPerformanceTest()
                }
                
                TestButton(
                    title: "Memory Test",
                    icon: "memorychip.fill",
                    color: .purple
                ) {
                    runMemoryTest()
                }
                
                TestButton(
                    title: "Network Simulation",
                    icon: "wifi.slash",
                    color: .gray
                ) {
                    simulateNetworkConditions()
                }
                
                TestButton(
                    title: "Stress Test",
                    icon: "flame.fill",
                    color: .red
                ) {
                    runStressTest()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var debugButton: some View {
        Button("View Debug Logs (\(debugLogs.count))") {
            showingDebugView = true
        }
        .foregroundColor(.blue)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
    
    // MARK: - Configuration Functions
    
    private func loadCurrentConfiguration() {
        loadSessionInfo()
        anonymousId = Freshpaint.shared().getAnonymousId()
        deviceToken = Freshpaint.shared().getDeviceToken()
        addDebugLog("📊 Loaded current SDK configuration")
    }
    
    private func loadSessionInfo() {
        sessionInfo = Freshpaint.shared().sessionInfo()
        addDebugLog("🔄 Session info refreshed")
        addDebugLog("Session info: \(sessionInfo)")
    }
    
    private func toggleDebugLogging(_ enabled: Bool) {
        Freshpaint.debug(enabled)
        addDebugLog(enabled ? "🔍 Debug logging enabled" : "🔇 Debug logging disabled")
    }
    
    private func updateFlushInterval(_ interval: Double) {
        addDebugLog("⏱️ Flush interval updated to \(Int(interval)) seconds")
        addDebugLog("Note: This demonstrates the configuration option, but changes require SDK restart")
    }
    
    private func updateFlushAt(_ count: Double) {
        addDebugLog("📊 Flush at count updated to \(Int(count)) events")
        addDebugLog("Note: This demonstrates the configuration option, but changes require SDK restart")
    }
    
    private func updateMaxQueueSize(_ size: Double) {
        addDebugLog("🗃️ Max queue size updated to \(Int(size))")
        addDebugLog("Note: This demonstrates the configuration option, but changes require SDK restart")
    }
    
    private func generateNewSession() {
        Freshpaint.shared().reset()
        loadSessionInfo()
        anonymousId = Freshpaint.shared().getAnonymousId()
        addDebugLog("🆕 New session generated")
        addDebugLog("New Anonymous ID: \(anonymousId)")
    }
    
    // MARK: - Testing Functions
    
    private func sendBatchEvents() {
        let eventNames = [
            "Product Viewed", "Add to Cart", "Checkout Started",
            "Payment Info Added", "Purchase Completed", "Review Submitted"
        ]
        
        for (index, eventName) in eventNames.enumerated() {
            let properties: [String: Any] = [
                "batch_test": true,
                "event_index": index,
                "batch_size": eventNames.count,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            Freshpaint.shared().track(eventName, properties: properties)
        }
        
        addDebugLog("📦 Sent batch of \(eventNames.count) events")
        addDebugLog("Events will be queued and sent based on flush configuration")
    }
    
    private func sendErrorEvent() {
        let properties: [String: Any] = [
            "error_type": "demo_error",
            "error_message": "This is a simulated error for testing",
            "error_code": 500,
            "stack_trace": "DemoView.swift:line 42",
            "user_action": "button_tap",
            "severity": "medium"
        ]
        
        Freshpaint.shared().track("Error Occurred", properties: properties)
        addDebugLog("❌ Error event sent for testing")
        addDebugLog("Properties: \(properties)")
    }
    
    private func runPerformanceTest() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 1...100 {
            let properties: [String: Any] = [
                "performance_test": true,
                "iteration": i,
                "test_type": "bulk_tracking"
            ]
            
            Freshpaint.shared().track("Performance Test Event", properties: properties)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        let summaryProperties: [String: Any] = [
            "events_count": 100,
            "time_elapsed_seconds": timeElapsed,
            "events_per_second": 100 / timeElapsed
        ]
        
        Freshpaint.shared().track("Performance Test Completed", properties: summaryProperties)
        
        addDebugLog("⚡ Performance test completed")
        addDebugLog("Tracked 100 events in \(String(format: "%.3f", timeElapsed)) seconds")
        addDebugLog("Rate: \(String(format: "%.1f", 100 / timeElapsed)) events/second")
    }
    
    private func runMemoryTest() {
        let properties: [String: Any] = [
            "memory_test": true,
            "large_payload": String(repeating: "A", count: 10000),
            "nested_data": [
                "level1": [
                    "level2": [
                        "level3": Array(1...1000)
                    ]
                ]
            ]
        ]
        
        Freshpaint.shared().track("Memory Test Event", properties: properties)
        addDebugLog("💾 Memory test event sent with large payload")
        addDebugLog("Payload size: ~10KB with nested data structures")
    }
    
    private func simulateNetworkConditions() {
        DispatchQueue.global(qos: .background).async {
            for condition in ["wifi", "cellular", "slow_cellular", "offline_simulation"] {
                let properties: [String: Any] = [
                    "network_simulation": true,
                    "connection_type": condition,
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                Freshpaint.shared().track("Network Condition Test", properties: properties)
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            DispatchQueue.main.async {
                self.addDebugLog("🌐 Network condition simulation completed")
                self.addDebugLog("Tested various connection scenarios")
            }
        }
    }
    
    private func runStressTest() {
        addDebugLog("🔥 Starting stress test...")
        
        DispatchQueue.global(qos: .background).async {
            let group = DispatchGroup()
            
            for threadIndex in 1...5 {
                group.enter()
                
                DispatchQueue.global(qos: .utility).async {
                    for eventIndex in 1...50 {
                        let properties: [String: Any] = [
                            "stress_test": true,
                            "thread_index": threadIndex,
                            "event_index": eventIndex,
                            "concurrent": true
                        ]
                        
                        Freshpaint.shared().track("Stress Test Event", properties: properties)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.addDebugLog("🏁 Stress test completed")
                self.addDebugLog("Sent 250 events across 5 concurrent threads")
                
                let completionProps: [String: Any] = [
                    "test_type": "stress_test",
                    "total_events": 250,
                    "concurrent_threads": 5,
                    "completed": true
                ]
                
                Freshpaint.shared().track("Stress Test Completed", properties: completionProps)
            }
        }
    }
    
    private func trackScreenView(_ screenName: String) {
        Freshpaint.shared().screen(screenName, properties: ["advanced_features": true])
        addDebugLog("📱 Screen view: \(screenName)")
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        debugLogs.append(logMessage)
        
        if debugLogs.count > 100 {
            debugLogs.removeFirst()
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        AdvancedFeaturesView()
    }
}
