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
                .foregroundStyle(.secondary)
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

/// Third tab: the single language dropdown, persisted in `uiLocale`.
@MainActor
struct SettingsTab: View {
    @EnvironmentObject private var loc: Localization

    var body: some View {
        Picker(loc.t("settings.language"), selection: localeBinding) {
            Text(loc.t("lang.en")).tag("en")
            Text(loc.t("lang.es")).tag("es")
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var localeBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: Localization.localeKey) ?? loc.code },
            set: { loc.setLocale($0) }
        )
    }
}
