//
//  ContentView.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 20/06/2025.
//

import SwiftUI
import Freshpaint

struct ContentView: View {
    @State private var tapCount = 0
    @State private var isUserIdentified = false
    @State private var currentUserId: String? = nil
    @State private var selectedTab = 0
    @State private var debugLogs: [String] = []
    @State private var showingDebugView = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Core Features Tab
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        userStatusView
                        coreTrackingGrid
                        debugButton
                    }
                    .padding()
                }
                .navigationTitle("Core Features")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "target")
                Text("Core")
            }
            .tag(0)
            
            // User Journey Tab
            NavigationView {
                UserJourneyView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("User Journey")
            }
            .tag(1)
            
            // Advanced Features Tab
            NavigationView {
                AdvancedFeaturesView()
            }
            .tabItem {
                Image(systemName: "gearshape.2")
                Text("Advanced")
            }
            .tag(2)
        }
        .sheet(isPresented: $showingDebugView) {
            DebugLogView(logs: debugLogs)
        }
        .onAppear {
            trackScreenView("Freshpaint Demo Home")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Freshpaint Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Comprehensive SDK Feature Showcase")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var userStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: isUserIdentified ? "person.fill.checkmark" : "person.crop.circle.badge.questionmark")
                    .foregroundColor(isUserIdentified ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isUserIdentified ? "Identified User" : "Anonymous User")
                        .font(.headline)
                    
                    if let userId = currentUserId {
                        Text("ID: \(userId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Anonymous ID: \(getAnonymousId())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(tapCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
    }
    
    private var coreTrackingGrid: some View {
        VStack(spacing: 16) {
            Text("Core SDK Features")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                
                // Basic Track Events
                MetricButton(
                    title: "Track Event",
                    icon: "target",
                    color: .blue
                ) {
                    trackBasicEvent()
                }
                
                MetricButton(
                    title: "Screen View",
                    icon: "rectangle.stack",
                    color: .green
                ) {
                    trackScreenManually()
                }
                
                // User Identity
                MetricButton(
                    title: isUserIdentified ? "Update Traits" : "Identify User",
                    icon: "person.crop.circle.fill",
                    color: .orange
                ) {
                    identifyUser()
                }
                
                MetricButton(
                    title: "Alias User",
                    icon: "person.2.crop.square.stack",
                    color: .purple
                ) {
                    aliasUser()
                }
                
                // Group Tracking
                MetricButton(
                    title: "Join Group",
                    icon: "person.3.fill",
                    color: .indigo
                ) {
                    trackGroupJoin()
                }
                
                MetricButton(
                    title: "Group Event",
                    icon: "building.2.fill",
                    color: .teal
                ) {
                    trackGroupEvent()
                }
                
                // Session Management
                MetricButton(
                    title: "Flush Events",
                    icon: "arrow.up.circle.fill",
                    color: .red
                ) {
                    flushEvents()
                }
                
                MetricButton(
                    title: "Reset Session",
                    icon: "arrow.counterclockwise.circle.fill",
                    color: .pink
                ) {
                    resetSession()
                }
            }
        }
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
    
    // MARK: - Core Tracking Functions
    
    private func trackBasicEvent() {
        tapCount += 1
        let eventName = "Demo Button Tapped"
        let properties: [String: Any] = [
            "button_type": "track_event",
            "tap_count": tapCount,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "user_status": isUserIdentified ? "identified" : "anonymous"
        ]
        
        Freshpaint.shared().track(eventName, properties: properties)
        addDebugLog("✅ Tracked Event: \(eventName)")
        addDebugLog("Properties: \(properties)")
    }
    
    private func trackScreenManually() {
        let screenName = "Manual Screen View"
        let properties: [String: Any] = [
            "screen_category": "demo",
            "manual_tracking": true,
            "tap_count": tapCount
        ]
        
        Freshpaint.shared().screen(screenName, properties: properties)
        addDebugLog("📱 Screen Tracked: \(screenName)")
        addDebugLog("Properties: \(properties)")
    }
    
    private func identifyUser() {
        tapCount += 1
        
        if !isUserIdentified {
            // First time identification
            let userId = "demo_user_\(UUID().uuidString.prefix(8))"
            let traits: [String: Any] = [
                "name": "Demo User",
                "email": "demo@freshpaint.io",
                "plan": "premium",
                "signup_date": ISO8601DateFormatter().string(from: Date()),
                "demo_user": true
            ]
            
            Freshpaint.shared().identify(userId, traits: traits)
            currentUserId = userId
            isUserIdentified = true
            addDebugLog("👤 User Identified: \(userId)")
            addDebugLog("Traits: \(traits)")
        } else {
            // Update existing user traits
            let updatedTraits: [String: Any] = [
                "last_active": ISO8601DateFormatter().string(from: Date()),
                "session_count": tapCount,
                "feature_usage": "high"
            ]
            
            Freshpaint.shared().identify(currentUserId, traits: updatedTraits)
            addDebugLog("🔄 User Traits Updated")
            addDebugLog("Updated Traits: \(updatedTraits)")
        }
    }
    
    private func aliasUser() {
        tapCount += 1
        let newUserId = "aliased_user_\(UUID().uuidString.prefix(8))"
        
        Freshpaint.shared().alias(newUserId)
        
        // Update our local state
        let oldUserId = currentUserId ?? "anonymous"
        currentUserId = newUserId
        
        addDebugLog("🔗 User Aliased: \(oldUserId) → \(newUserId)")
        addDebugLog("This links the previous anonymous/identified activity to the new user ID")
    }
    
    private func trackGroupJoin() {
        tapCount += 1
        let groupId = "company_demo_\(Int.random(in: 100...999))"
        let traits: [String: Any] = [
            "name": "Demo Company Inc",
            "industry": "Technology",
            "employees": Int.random(in: 50...500),
            "plan": "enterprise",
            "joined_date": ISO8601DateFormatter().string(from: Date())
        ]
        
        Freshpaint.shared().group(groupId, traits: traits)
        addDebugLog("🏢 Group Joined: \(groupId)")
        addDebugLog("Group Traits: \(traits)")
    }
    
    private func trackGroupEvent() {
        tapCount += 1
        let eventName = "Team Collaboration"
        let properties: [String: Any] = [
            "action": "document_shared",
            "team_size": Int.random(in: 3...12),
            "document_type": "analytics_report",
            "collaboration_tool": "freshpaint_demo"
        ]
        
        Freshpaint.shared().track(eventName, properties: properties)
        addDebugLog("👥 Group Event Tracked: \(eventName)")
        addDebugLog("Properties: \(properties)")
    }
    
    private func flushEvents() {
        Freshpaint.shared().flush()
        addDebugLog("⬆️ Manual flush triggered - sending queued events immediately")
        addDebugLog("Normally events are batched and sent automatically")
    }
    
    private func resetSession() {
        Freshpaint.shared().reset()
        
        // Reset local state
        isUserIdentified = false
        currentUserId = nil
        tapCount = 0
        
        addDebugLog("🔄 Session Reset - All user data cleared")
        addDebugLog("User is now anonymous again with new anonymous ID")
        addDebugLog("New Anonymous ID: \(getAnonymousId())")
    }
    
    private func trackScreenView(_ screenName: String) {
        let properties: [String: Any] = [
            "automatic_tracking": false,
            "manual_call": true,
            "app_section": "demo"
        ]
        
        Freshpaint.shared().screen(screenName, properties: properties)
        addDebugLog("📱 Screen View: \(screenName)")
    }
    
    // MARK: - Helper Functions
    
    private func getAnonymousId() -> String {
        return Freshpaint.shared().getAnonymousId() ?? "unknown"
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        debugLogs.append(logMessage)
        
        // Keep only last 50 logs
        if debugLogs.count > 50 {
            debugLogs.removeFirst()
        }
    }
}

struct MetricButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
