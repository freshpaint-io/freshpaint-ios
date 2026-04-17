//
//  AttributionDemoView.swift
//  FreshpaintDemo
//
//  Showcases the attribution features added in FRP-34 (stable device ID)
//  and FRP-35/FRP-36 (ATT public API and attribution middleware).
//

import SwiftUI
import UIKit
import Freshpaint

// ---------------------------------------------------------------------------
// MARK: - Shared event log (used by DeepLinkTestView and DeepLinkScenariosView)
// ---------------------------------------------------------------------------

class AttributionEventLog: ObservableObject {
    static let shared = AttributionEventLog()
    @Published var entries: [String] = []

    func append(_ entry: String) {
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            if self.entries.count > 50 { self.entries.removeLast() }
        }
    }
}

struct AttributionDemoView: View {
    // MARK: - State

    @State private var attStatus: UInt = 0
    @State private var idfa: String = "Not available"
    @State private var idfv: String = "Not available"
    @State private var stableDeviceId: String = "Not available"
    @State private var persistentDeviceId: String = "Not available"
    @State private var appVersion: String = "Not available"
    @State private var isFirstLaunch: Bool = false

    @State private var autoRequestSimEnabled = false
    @State private var autoRequestLastResult: String = ""

    @State private var testURL: String = "freshpaintdemo://test?fp_click_id=test123&utm_source=facebook&utm_campaign=summer"
    @State private var lastDeepLinkURL: String = "None"
    @State private var lastFpClickId: String = "null"
    @State private var lastUtmSource: String = "null"
    @State private var lastUtmCampaign: String = "null"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                deviceIdentifiersCard
                attCard
                autoRequestCard
                deepLinkCard
                attributionDataCard
            }
            .padding()
        }
        .navigationTitle("Attribution Demo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refresh()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Freshpaint Attribution Demo")
                .font(.title2)
                .fontWeight(.bold)

            Text("Platform: iOS  |  First Launch: \(isFirstLaunch ? "Yes" : "No")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Device Identifiers Card

    private var deviceIdentifiersCard: some View {
        CardView(title: "Device Identifiers") {
            VStack(spacing: 12) {
                AttributionRow(label: "Device ID", value: stableDeviceId)
                AttributionRow(label: "Persistent ID", value: persistentDeviceId)
                AttributionRow(label: "IDFV", value: idfv)
                AttributionRow(label: "IDFA", value: idfa)
                AttributionRow(label: "ATT Status", value: attStatusString(attStatus))
            }
        }
    }

    // MARK: - ATT Card

    private var attCard: some View {
        CardView(title: "App Tracking Transparency (iOS)") {
            Button("Request ATT Authorization") {
                requestATT()
            }
            .foregroundColor(attStatus == 0 ? .blue : .secondary)
            .disabled(attStatus != 0)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Auto-Request ATT Card

    private var autoRequestCard: some View {
        CardView(title: "Auto-Request ATT (FRP-36)") {
            VStack(alignment: .leading, spacing: 14) {
                Text("When autoRequestATT = YES, the SDK calls requestTrackingAuthorization automatically on every UIApplicationDidBecomeActiveNotification — but only when status is notDetermined. Subsequent foregrounds are no-ops once the user has responded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Toggle("Simulate autoRequestATT = YES", isOn: $autoRequestSimEnabled)
                    .font(.subheadline)

                Button("Simulate app didBecomeActive") {
                    simulateAutoRequest()
                }
                .foregroundColor(autoRequestSimEnabled ? .blue : .secondary)
                .disabled(!autoRequestSimEnabled)
                .frame(maxWidth: .infinity)

                if !autoRequestLastResult.isEmpty {
                    Text(autoRequestLastResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Deep Link Card

    private var deepLinkCard: some View {
        CardView(title: "Deep Link Testing") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Test URL:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Deep link URL", text: $testURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Process Test Deep Link") {
                    processDeepLink()
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)

                if lastDeepLinkURL != "None" {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Deep Link:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("URL: \(lastDeepLinkURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        Text("fp_click_id: \(lastFpClickId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Attribution Data Card

    private var attributionDataCard: some View {
        CardView(title: "Attribution Data") {
            VStack(spacing: 12) {
                Button("Refresh Attribution Data") {
                    refresh()
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)

                AttributionJSONBlock(fields: attributionFields)
            }
        }
    }

    // MARK: - Attribution fields

    private var attributionFields: [(key: String, value: AttributionValue)] {
        [
            ("att_status",    .string(attStatusString(attStatus))),
            ("idfv",          .string(idfv)),
            ("app_version",   .string(appVersion)),
            ("idfa",          .string(idfa)),
            ("fp_click_id",   lastFpClickId == "null"    ? .null : .string(lastFpClickId)),
            ("utm_source",    lastUtmSource == "null"    ? .null : .string(lastUtmSource)),
            ("utm_campaign",  lastUtmCampaign == "null"  ? .null : .string(lastUtmCampaign)),
            ("device_id",              .string(stableDeviceId)),
            ("persistent_device_id",   .string(persistentDeviceId)),
            ("first_launch",           .bool(isFirstLaunch)),
        ]
    }

    // MARK: - Actions

    private func refresh() {
        attStatus = Freshpaint.trackingAuthorizationStatus()
        stableDeviceId = "Auto-enriched in event context"
        persistentDeviceId = Freshpaint.stableDeviceId()
        idfv = UIDevice.current.identifierForVendor?.uuidString ?? "Not available"
        idfa = Freshpaint.advertisingIdentifier() ?? "Not available"
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let sessionInfo = Freshpaint.shared().sessionInfo(forAction: "attribution_demo_view")
        isFirstLaunch = (sessionInfo["isFirstEventInSession"] as? Bool) ?? false
    }

    private func requestATT() {
        Freshpaint.requestTrackingAuthorization { newStatus in
            attStatus = newStatus
            idfa = Freshpaint.advertisingIdentifier() ?? "Not available"
        }
    }

    /// Mirrors the logic in _handleDidBecomeActiveForATT to demonstrate
    /// what autoRequestATT = YES does on each didBecomeActive firing.
    private func simulateAutoRequest() {
        let status = Freshpaint.trackingAuthorizationStatus()
        if status == 0 {
            autoRequestLastResult = "Status is notDetermined — requesting authorization..."
            Freshpaint.requestTrackingAuthorization { newStatus in
                attStatus = newStatus
                idfa = Freshpaint.advertisingIdentifier() ?? "Not available"
                autoRequestLastResult = "ATT prompt shown. Final status: \(attStatusString(newStatus))"
            }
        } else {
            autoRequestLastResult = "Status already determined (\(attStatusString(status))) — prompt skipped. Duplicate prevention works correctly."
        }
    }

    private func processDeepLink() {
        guard let url = URL(string: testURL) else { return }

        Freshpaint.shared().open(url, options: [:])

        lastDeepLinkURL = testURL
        lastFpClickId    = urlQueryItem("fp_click_id",   from: url) ?? "null"
        lastUtmSource    = urlQueryItem("utm_source",    from: url) ?? "null"
        lastUtmCampaign  = urlQueryItem("utm_campaign",  from: url) ?? "null"

        Freshpaint.shared().track("Deep Link Processed", properties: [
            "url": testURL,
            "fp_click_id": lastFpClickId,
            "utm_source": lastUtmSource,
            "utm_campaign": lastUtmCampaign,
        ])
    }

    // MARK: - Helpers

    private func attStatusString(_ status: UInt) -> String {
        switch status {
        case 0: return "notDetermined"
        case 1: return "restricted"
        case 2: return "denied"
        case 3: return "authorized"
        default: return "unavailable"
        }
    }

    private func urlQueryItem(_ name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

// MARK: - Attribution value type

enum AttributionValue {
    case string(String)
    case bool(Bool)
    case null
}

// MARK: - JSON block view

struct AttributionJSONBlock: View {
    let fields: [(key: String, value: AttributionValue)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("{")
                .jsonBase()

            ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                HStack(alignment: .top, spacing: 0) {
                    Text("  ")
                        .jsonBase()
                    Text("\"\(field.key)\"")
                        .jsonKey()
                    Text(": ")
                        .jsonBase()
                    valueText(field.value)
                    if index < fields.count - 1 {
                        Text(",")
                            .jsonBase()
                    }
                }
            }

            Text("}")
                .jsonBase()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.11, green: 0.13, blue: 0.17))
        )
    }

    @ViewBuilder
    private func valueText(_ value: AttributionValue) -> some View {
        switch value {
        case .string(let s):
            Text("\"\(s)\"")
                .jsonString()
        case .bool(let b):
            Text(b ? "true" : "false")
                .jsonBool()
        case .null:
            Text("null")
                .jsonNull()
        }
    }
}

// MARK: - JSON text modifiers

private extension Text {
    func jsonBase() -> some View {
        self.font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.82))
    }

    func jsonKey() -> some View {
        self.font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.98))
    }

    func jsonString() -> some View {
        self.font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(red: 0.98, green: 0.73, blue: 0.44))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    func jsonBool() -> some View {
        self.font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(red: 0.82, green: 0.6, blue: 0.95))
    }

    func jsonNull() -> some View {
        self.font(.system(.caption, design: .monospaced))
            .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
    }
}

// MARK: - Reusable Card

struct CardView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Attribution Row

struct AttributionRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    NavigationView {
        AttributionDemoView()
    }
}
