import AppKit
import ServiceManagement
import SwiftUI
import TimeTrackerCore

struct ContentView: View {
    @EnvironmentObject private var store: CheckStore
    @State private var tab: Tab = .status

    enum Tab { case status, edit }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Status").tag(Tab.status)
                Text("Edit").tag(Tab.edit)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            switch tab {
            case .status: StatusTab()
            case .edit: EditTab()
            }

            Divider()

            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            Button("Quit TimeTracker") { NSApp.terminate(nil) }
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
