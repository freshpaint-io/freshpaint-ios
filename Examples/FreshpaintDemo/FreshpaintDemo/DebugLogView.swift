//
//  DebugLogView.swift
//  FreshpaintDemo
//
//  Created by Fernando Putallaz on 27/06/2025.
//

import SwiftUI

struct DebugLogView: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredLogs: [String] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if filteredLogs.isEmpty {
                    ContentUnavailableView(
                        "No Debug Logs",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(searchText.isEmpty ? "No logs available yet" : "No logs match your search")
                    )
                } else {
                    List {
                        ForEach(Array(filteredLogs.enumerated().reversed()), id: \.offset) { index, log in
                            LogEntryView(log: log, index: filteredLogs.count - index)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search logs...")
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        // This would need to be passed as a binding if we want to clear logs
                    }
                    .disabled(logs.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LogEntryView: View {
    let log: String
    let index: Int
    
    private var logComponents: (timestamp: String, icon: String, message: String, color: Color) {
        let components = log.components(separatedBy: "] ")
        let timestamp = components.first?.replacingOccurrences(of: "[", with: "") ?? ""
        let message = components.dropFirst().joined(separator: "] ")
        
        var icon = "circle.fill"
        var color = Color.blue
        
        if message.contains("✅") || message.contains("Tracked Event") {
            icon = "checkmark.circle.fill"
            color = .green
        } else if message.contains("📱") || message.contains("Screen") {
            icon = "iphone"
            color = .blue
        } else if message.contains("👤") || message.contains("User") {
            icon = "person.fill"
            color = .orange
        } else if message.contains("🏢") || message.contains("Group") {
            icon = "building.2.fill"
            color = .purple
        } else if message.contains("🔄") || message.contains("Reset") || message.contains("Flush") {
            icon = "arrow.clockwise"
            color = .teal
        } else if message.contains("❌") || message.contains("Error") {
            icon = "exclamationmark.triangle.fill"
            color = .red
        } else if message.contains("⚡") || message.contains("Performance") {
            icon = "bolt.fill"
            color = .yellow
        } else if message.contains("🔗") || message.contains("Alias") {
            icon = "link"
            color = .indigo
        }
        
        return (timestamp, icon, message, color)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: logComponents.icon)
                    .foregroundColor(logComponents.color)
                    .font(.caption)
                
                Text("#\(index)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray5))
                    )
                
                Spacer()
                
                Text(logComponents.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(logComponents.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DebugLogView(logs: [
        "[2025-06-27 10:30:15] ✅ Tracked Event: Demo Button Tapped",
        "[2025-06-27 10:30:20] 📱 Screen View: Manual Screen View",
        "[2025-06-27 10:30:25] 👤 User Identified: demo_user_12345",
        "[2025-06-27 10:30:30] 🏢 Group Joined: company_demo_123",
        "[2025-06-27 10:30:35] 🔄 Session Reset - All user data cleared",
        "[2025-06-27 10:30:40] ❌ Error event sent for testing"
    ])
}