//
//  DeepLinkScenariosView.swift
//  FreshpaintDemo
//
//  FRP-38 named scenario tests: T1–T9, T6 persistence, T8 install simulation.
//  Complements DeepLinkTestView (which tests all 24 platforms with pass/fail).
//

import SwiftUI
import Freshpaint

struct DeepLinkScenariosView: View {

    // NOTE: AttributionEventLog is defined in AttributionDemoView.swift.
    @ObservedObject private var eventLog = AttributionEventLog.shared

    private let tests: [(id: String, label: String, url: String)] = [
        ("T1",  "T1 — Regression (no click IDs)",
         "freshpaintdemo://open?ref=test"),
        ("T2",  "T2 — Single gclid",
         "freshpaintdemo://open?gclid=ABC123XYZ"),
        ("T3",  "T3 — All 5 UTM params",
         "freshpaintdemo://open?utm_source=google&utm_medium=cpc&utm_campaign=spring_sale&utm_term=analytics&utm_content=banner"),
        ("T4",  "T4 — Google gacid → campaign_id",
         "freshpaintdemo://open?gclid=GCLID_VALUE&gacid=CAMPAIGN_456"),
        ("T5",  "T5 — Facebook extras",
         "freshpaintdemo://open?fbclid=FB123&ad_id=AD99&adset_id=ADSET77&campaign_id=CAMP55"),
        ("T7a", "T7a — Dedup: first fire (msclkid)",
         "freshpaintdemo://open?msclkid=BING_SAME_VALUE"),
        ("T7b", "T7b — Dedup: second fire (same value)",
         "freshpaintdemo://open?msclkid=BING_SAME_VALUE"),
        ("T9",  "T9 — Multiple platforms",
         "freshpaintdemo://open?gclid=G1&fbclid=FB2&ttclid=TT3&msclkid=MS4&twclid=TW5"),
        ("T10", "T10 — No recognized params",
         "freshpaintdemo://open?ref=homepage&section=deals"),
    ]

    @State private var storedClickIds: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Header
                VStack(spacing: 4) {
                    Text("FRP-38 Scenario Tests")
                        .font(.headline)
                    Text("Tap a test → fires deep link + track event. Check 'Stored Click IDs' and 'Event Log' below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // T1–T10 test buttons
                VStack(spacing: 8) {
                    ForEach(tests, id: \.id) { test in
                        Button { runTest(test) } label: {
                            HStack {
                                Text(test.label).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "play.circle.fill").foregroundColor(.blue)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // T6 — persistence (requires manual app restart)
                VStack(alignment: .leading, spacing: 8) {
                    Text("T6 — Persistence Across Restart").font(.caption).fontWeight(.semibold)
                    Text("1. Tap 'Store ttclid'  2. Stop app in Xcode  3. Re-run  4. Tap 'Refresh' — $ttclid must still be present")
                        .font(.caption2).foregroundColor(.secondary)
                    Button("Store ttclid") {
                        fireDeepLink("freshpaintdemo://open?ttclid=TIKTOK_PERSIST_99")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshStoredIds() }
                    }.buttonStyle(.bordered)
                }

                Divider()

                // T8 — first install simulation
                VStack(alignment: .leading, spacing: 8) {
                    Text("T8 — First-Install Simulation").font(.caption).fontWeight(.semibold)
                    Text("1. Tap 'Clear Install Guard'  2. Stop + re-run app  3. app_install fires  4. If click IDs were stored, they are merged in")
                        .font(.caption2).foregroundColor(.secondary)
                    Button("Clear Install Guard (FPBuildKeyV2)") {
                        UserDefaults.standard.removeObject(forKey: "FPBuildKeyV2")
                        UserDefaults.standard.removeObject(forKey: "FPVersionKey")
                        UserDefaults.standard.synchronize()
                        AttributionEventLog.shared.append("T8: install guard cleared — restart app to trigger app_install")
                    }.buttonStyle(.bordered).tint(.orange)
                }

                Divider()

                // Stored click IDs panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stored Click IDs (NSUserDefaults)").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Button("Refresh") { refreshStoredIds() }.font(.caption2)
                        Button("Clear All") {
                            UserDefaults.standard.removeObject(forKey: "com.freshpaint.clickIds")
                            UserDefaults.standard.synchronize()
                            refreshStoredIds()
                        }.font(.caption2).foregroundColor(.red)
                    }
                    Text(storedClickIds.isEmpty ? "(none)" : storedClickIds)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }

                // Event log panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Event Log").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Button("Clear") { AttributionEventLog.shared.entries.removeAll() }.font(.caption2)
                    }
                    if eventLog.entries.isEmpty {
                        Text("(no events yet — run a test)")
                            .font(.caption2).foregroundColor(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    } else {
                        ForEach(Array(eventLog.entries.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Deep Link Scenarios")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshStoredIds() }
    }

    // MARK: - Logic

    private func runTest(_ test: (id: String, label: String, url: String)) {
        fireDeepLink(test.url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Freshpaint.shared().track("Attribution Test \(test.id)", properties: ["test_id": test.id])
            refreshStoredIds()
        }
    }

    private func fireDeepLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        Freshpaint.shared().open(url, options: [:])
        AttributionEventLog.shared.append("→ openURL: \(urlString)")
    }

    private func refreshStoredIds() {
        guard let data = UserDefaults.standard.data(forKey: "com.freshpaint.clickIds"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              !plist.isEmpty
        else {
            storedClickIds = "(none)"
            return
        }
        storedClickIds = plist
            .sorted { $0.key < $1.key }
            .map { k, v in "\(k): \(v)" }
            .joined(separator: "\n")
    }
}

#Preview {
    NavigationView { DeepLinkScenariosView() }
}
