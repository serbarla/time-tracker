import AppKit
import ServiceManagement
import SwiftUI
import TimeTrackerCore

struct ContentView: View {
    @EnvironmentObject private var store: CheckStore
    @EnvironmentObject private var loc: Localization
    @State private var tab: Tab = .status

    enum Tab { case status, edit, settings }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(loc.t("tab.status")).tag(Tab.status)
                Text(loc.t("tab.edit")).tag(Tab.edit)
                Text(loc.t("tab.settings")).tag(Tab.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            switch tab {
            case .status: StatusTab()
            case .edit: EditTab()
            case .settings: SettingsTab()
            }

            Divider()

            Toggle(loc.t("app.launchAtLogin"), isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
                .tint(.green)
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            Button(loc.t("app.quit")) { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(6)
        }
        .frame(width: 380, height: 588)
        .background(Color.white)
        .preferredColorScheme(.light)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    print("Launch at login toggle failed: \(error)")
                }
            }
        )
    }
}

/// Third tab: language (`uiLocale`) and alert lead time (`alertLeadMinutes`).
@MainActor
struct SettingsTab: View {
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(loc.t("settings.language"), selection: localeBinding) {
                Text(loc.t("lang.en")).tag("en")
                Text(loc.t("lang.es")).tag("es")
            }
            .pickerStyle(.menu)

            Picker(loc.t("settings.alerts"), selection: alertLeadBinding) {
                ForEach([1, 2, 3, 5, 10, 15], id: \.self) { minutes in
                    Text(loc.format("settings.alerts.minutes", minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var localeBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: Localization.localeKey) ?? loc.code },
            set: { loc.setLocale($0) }
        )
    }

    /// Global lead time before a window starts; default 2 when unset.
    private var alertLeadBinding: Binding<Int> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "alertLeadMinutes") as? Int ?? 2 },
            set: { UserDefaults.standard.set($0, forKey: "alertLeadMinutes") }
        )
    }
}
