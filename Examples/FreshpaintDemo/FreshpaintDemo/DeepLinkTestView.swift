//
//  DeepLinkTestView.swift
//  FreshpaintDemo
//
//  FRP-38: Comprehensive deep link attribution test harness.
//  Covers all 24 supported click ID platforms + UTM params + persistence + dedup.
//

import SwiftUI
import Freshpaint

// ---------------------------------------------------------------------------
// MARK: - Shared event log (populated by rawFreshpaintModificationBlock)
// ---------------------------------------------------------------------------

// NOTE: AttributionEventLog is defined in AttributionDemoView.swift.
// Both views share the same singleton.

// ---------------------------------------------------------------------------
// MARK: - DeepLinkTestView
// ---------------------------------------------------------------------------

struct DeepLinkTestView: View {

    // MARK: - Platform model

    struct Platform: Identifiable {
        let id: String          // URL param name, used as stable identity
        let name: String        // Human-readable platform name
        let urlParam: String    // Query param added to the deep link URL
        let storedKey: String   // Key expected in NSUserDefaults click ID dict (e.g. "$gclid")
        let extraParams: String? // Additional URL params required for this platform
    }

    enum TestStatus { case idle, pass, fail }

    // MARK: - All 24 supported platforms

    static let allPlatforms: [Platform] = [
        Platform(id: "aleid",          name: "AppLovin",            urlParam: "aleid",          storedKey: "$aleid",          extraParams: nil),
        Platform(id: "cntr_auctionId", name: "Basis",               urlParam: "cntr_auctionId", storedKey: "$cntr_auctionId", extraParams: nil),
        Platform(id: "msclkid",        name: "Bing",                urlParam: "msclkid",        storedKey: "$msclkid",        extraParams: nil),
        Platform(id: "fbclid",         name: "Facebook",            urlParam: "fbclid",         storedKey: "$fbclid",         extraParams: "ad_id=AD001&adset_id=ADSET001&campaign_id=CAMP001"),
        Platform(id: "gclid",          name: "Google (gclid)",      urlParam: "gclid",          storedKey: "$gclid",          extraParams: "gacid=GCAMPAIGN001"),
        Platform(id: "dclid",          name: "Google Display",      urlParam: "dclid",          storedKey: "$dclid",          extraParams: nil),
        Platform(id: "gclsrc",         name: "Google cross-acct",   urlParam: "gclsrc",         storedKey: "$gclsrc",         extraParams: nil),
        Platform(id: "wbraid",         name: "Google (wbraid)",     urlParam: "wbraid",         storedKey: "$wbraid",         extraParams: nil),
        Platform(id: "gbraid",         name: "Google (gbraid)",     urlParam: "gbraid",         storedKey: "$gbraid",         extraParams: nil),
        Platform(id: "irclickid",      name: "impact.com",          urlParam: "irclickid",      storedKey: "$irclickid",      extraParams: nil),
        Platform(id: "li_fat_id",      name: "LinkedIn",            urlParam: "li_fat_id",      storedKey: "$li_fat_id",      extraParams: nil),
        Platform(id: "ndclid",         name: "Nextdoor",            urlParam: "ndclid",         storedKey: "$ndclid",         extraParams: nil),
        Platform(id: "epik",           name: "Pinterest",           urlParam: "epik",           storedKey: "$epik",           extraParams: nil),
        Platform(id: "rdt_cid",        name: "Reddit",              urlParam: "rdt_cid",        storedKey: "$rdt_cid",        extraParams: nil),
        Platform(id: "ScCid",          name: "Snapchat",            urlParam: "ScCid",          storedKey: "$ScCid",          extraParams: nil),
        Platform(id: "spclid",         name: "Spotify",             urlParam: "spclid",         storedKey: "$spclid",         extraParams: nil),
        Platform(id: "sapid",          name: "StackAdapt",          urlParam: "sapid",          storedKey: "$sapid",          extraParams: nil),
        Platform(id: "ttdimp",         name: "TheTradeDesk",        urlParam: "ttdimp",         storedKey: "$ttdimp",         extraParams: nil),
        Platform(id: "ttclid",         name: "TikTok",              urlParam: "ttclid",         storedKey: "$ttclid",         extraParams: nil),
        Platform(id: "twclid",         name: "Twitter/X",           urlParam: "twclid",         storedKey: "$twclid",         extraParams: nil),
        Platform(id: "clid_src",       name: "Twitter/X (alt)",     urlParam: "clid_src",       storedKey: "$clid_src",       extraParams: nil),
        Platform(id: "viant_clid",     name: "Viant",               urlParam: "viant_clid",     storedKey: "$viant_clid",     extraParams: nil),
        Platform(id: "qclid",          name: "Quora",               urlParam: "qclid",          storedKey: "$qclid",          extraParams: nil),
    ]

    // MARK: - State

    @State private var results: [String: TestStatus] = [:]
    @State private var storedClickIds: [String: Any] = [:]
    @State private var storedUTM: [String: String] = [:]
    @State private var utmResult: TestStatus = .idle
    @State private var dedupResult: TestStatus = .idle
    @State private var log: [String] = []
    @State private var isRunningAll = false

    // How many platforms have been tested (pass or fail)
    private var testedCount: Int { results.values.filter { $0 != .idle }.count }
    private var passCount:   Int { results.values.filter { $0 == .pass }.count }
    private var allPlatforms: [Platform] { Self.allPlatforms }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryBanner
                controlsRow
                platformsSection
                utmSection
                dedupSection
                persistenceNote
                logSection
            }
            .padding()
        }
        .navigationTitle("Deep Link Tests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshState() }
    }

    // MARK: - Summary banner

    private var summaryBanner: some View {
        VStack(spacing: 6) {
            Text("All 24 Ad Platforms")
                .font(.headline)
            HStack(spacing: 16) {
                Label("\(passCount) passed", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("\(testedCount - passCount) failed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                Label("\(allPlatforms.count - testedCount) pending", systemImage: "circle")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Button {
                runAll()
            } label: {
                Label(isRunningAll ? "Running…" : "Run All 24", systemImage: "play.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningAll)

            Button {
                resetAll()
            } label: {
                Label("Reset", systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Platform rows

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Click ID Platforms")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ForEach(Self.allPlatforms) { platform in
                platformRow(platform)
            }
        }
    }

    private func platformRow(_ platform: Platform) -> some View {
        HStack {
            // Status indicator
            statusIcon(results[platform.id] ?? .idle)

            VStack(alignment: .leading, spacing: 2) {
                Text(platform.name)
                    .font(.subheadline)
                if let stored = storedClickIds[platform.storedKey] {
                    Text("\(platform.storedKey) = \(stored)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(platform.storedKey)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            Button("Run") { runPlatform(platform) }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(isRunningAll)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(rowBackground(results[platform.id] ?? .idle))
        .cornerRadius(8)
    }

    // MARK: - UTM section

    private var utmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon(utmResult)
                Text("UTM Parameters (all 5)")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Button("Run") { runUTMTest() }
                    .font(.caption).buttonStyle(.bordered)
                    .disabled(isRunningAll)
            }

            if !storedUTM.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(storedUTM.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        Text("\(key) = \(value)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Dedup section

    private var dedupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon(dedupResult)
                Text("Deduplication (same value preserves creation_time)")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Button("Run") { runDedupTest() }
                    .font(.caption).buttonStyle(.bordered)
                    .disabled(isRunningAll)
            }
            Text("Fires msclkid=DEDUP_TEST twice. The second fire must not update _creation_time.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Persistence note

    private var persistenceNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Persistence (manual)", systemImage: "externaldrive.badge.checkmark")
                .font(.subheadline).fontWeight(.medium)
            Text("After running any test above, stop the app in Xcode and re-run. All click IDs marked ✅ should still show their stored values — they survive app kills via NSUserDefaults.")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("UTM params survive up to 24 hours; re-running after > 24h will clear them.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Log section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Event Log").font(.caption).fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    log.removeAll()
                    AttributionEventLog.shared.entries.removeAll()
                }
                .font(.caption2)
            }

            if log.isEmpty {
                Text("(run a test to see output)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(6)
            } else {
                ForEach(Array(log.enumerated().reversed()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Helpers: visual

    @ViewBuilder
    private func statusIcon(_ status: TestStatus) -> some View {
        switch status {
        case .idle: Image(systemName: "circle").foregroundColor(.secondary)
        case .pass: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .fail: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }

    private func rowBackground(_ status: TestStatus) -> Color {
        switch status {
        case .idle: return Color(.tertiarySystemBackground)
        case .pass: return Color.green.opacity(0.08)
        case .fail: return Color.red.opacity(0.08)
        }
    }

    // MARK: - Test actions

    private func runPlatform(_ platform: Platform, value: String? = nil) {
        let testValue = value ?? "TEST_\(platform.id.uppercased())_\(Int.random(in: 1000...9999))"
        var urlStr = "freshpaintdemo://open?\(platform.urlParam)=\(testValue)"
        if let extras = platform.extraParams { urlStr += "&\(extras)" }
        guard let url = URL(string: urlStr) else { return }

        Freshpaint.shared().open(url, options: [:])
        appendLog("→ [\(platform.name)] \(urlStr)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshState()
            let found = storedClickIds[platform.storedKey] != nil
            results[platform.id] = found ? .pass : .fail
            appendLog(found
                ? "✅ \(platform.name): \(platform.storedKey) = \(storedClickIds[platform.storedKey]!)"
                : "❌ \(platform.name): \(platform.storedKey) not found in stored click IDs")
        }
    }

    private func runUTMTest() {
        let urlStr = "freshpaintdemo://open?utm_source=google&utm_medium=cpc&utm_campaign=spring_sale&utm_term=ios_sdk&utm_content=deeplink_test"
        guard let url = URL(string: urlStr) else { return }
        Freshpaint.shared().open(url, options: [:])
        appendLog("→ [UTM] \(urlStr)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshStoredUTM()
            let allPresent = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"]
                .allSatisfy { storedUTM[$0] != nil }
            utmResult = allPresent ? .pass : .fail
            appendLog(allPresent ? "✅ All 5 UTM params stored" : "❌ Some UTM params missing: \(storedUTM)")
        }
    }

    private func runDedupTest() {
        let firstURL  = URL(string: "freshpaintdemo://open?msclkid=DEDUP_TEST")!
        let secondURL = URL(string: "freshpaintdemo://open?msclkid=DEDUP_TEST")!

        Freshpaint.shared().open(firstURL, options: [:])
        appendLog("→ [Dedup] Fire 1: msclkid=DEDUP_TEST")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            refreshState()
            let creationTime1 = storedClickIds["$msclkid_creation_time"]

            Freshpaint.shared().open(secondURL, options: [:])
            appendLog("→ [Dedup] Fire 2: msclkid=DEDUP_TEST (same value)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                refreshState()
                let creationTime2 = storedClickIds["$msclkid_creation_time"]
                // Same value → creation_time must NOT change.
                let preserved = (creationTime1 as? NSNumber) == (creationTime2 as? NSNumber)
                dedupResult = preserved ? .pass : .fail
                appendLog(preserved
                    ? "✅ Dedup: creation_time preserved on second fire (\(creationTime1 ?? "?"))"
                    : "❌ Dedup: creation_time changed — \(creationTime1 ?? "?") → \(creationTime2 ?? "?")")
            }
        }
    }

    private func runAll() {
        isRunningAll = true
        resetAll()
        appendLog("▶ Running all 24 platforms + UTM + dedup…")

        // Run platforms sequentially with 0.7s spacing to avoid state-queue contention.
        let platforms = Self.allPlatforms
        for (index, platform) in platforms.enumerated() {
            let delay = Double(index) * 0.7
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                runPlatform(platform, value: "RUNALL_\(platform.id.uppercased())")
            }
        }

        // UTM test after all platforms
        let utmDelay = Double(platforms.count) * 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + utmDelay) {
            runUTMTest()
        }

        // Dedup test after UTM
        let dedupDelay = utmDelay + 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + dedupDelay) {
            runDedupTest()
        }

        // Mark complete
        let doneDelay = dedupDelay + 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + doneDelay) {
            isRunningAll = false
            appendLog("✔ Run complete — \(passCount)/\(allPlatforms.count) platforms passed")
        }
    }

    private func resetAll() {
        results.removeAll()
        utmResult = .idle
        dedupResult = .idle
        // NOTE: reads internal SDK keys — update here if FPState's storage keys change.
        UserDefaults.standard.removeObject(forKey: "com.freshpaint.clickIds")
        UserDefaults.standard.removeObject(forKey: "com.freshpaint.utmParams")
        UserDefaults.standard.removeObject(forKey: "com.freshpaint.utmExpiry")
        refreshState()
        appendLog("🗑 State cleared")
    }

    // MARK: - State refresh

    private func refreshState() {
        refreshStoredClickIds()
        refreshStoredUTM()
    }

    private func refreshStoredClickIds() {
        // NOTE: reads an internal SDK key — update if FPState's storage key changes.
        guard let data = UserDefaults.standard.data(forKey: "com.freshpaint.clickIds"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            storedClickIds = [:]
            return
        }
        storedClickIds = plist
    }

    private func refreshStoredUTM() {
        // NOTE: reads an internal SDK key — update if FPState's storage key changes.
        guard let data = UserDefaults.standard.data(forKey: "com.freshpaint.utmParams"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            storedUTM = [:]
            return
        }
        storedUTM = plist
    }

    private func appendLog(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.append("[\(ts)] \(message)")
        if log.count > 100 { log.removeFirst() }
    }
}

#Preview {
    NavigationView { DeepLinkTestView() }
}
