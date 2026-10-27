import SwiftUI
import TimeTrackerCore

struct EditTab: View {
    @EnvironmentObject private var store: CheckStore
    @EnvironmentObject private var loc: Localization
    @State private var editing: EditorSession?

    struct EditorSession {
        var initial: Check
        var isNew: Bool
    }

    var body: some View {
        if let session = editing {
            CheckEditorView(initial: session.initial) { saved in
                if session.isNew { store.add(saved) } else { store.update(saved) }
                editing = nil
            } onCancel: {
                editing = nil
            }
        } else {
            listView
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if store.checks.isEmpty {
                Text(loc.t("edit.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.checks) { check in
                        HStack {
                            Button {
                                editing = EditorSession(initial: check, isNew: false)
                            } label: {
                                HStack {
                                    Text(check.name)
                                    Spacer()
                                    Text(check.timeZoneIdentifier)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                editing = EditorSession(initial: check, isNew: false)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help(loc.t("edit.helpEdit"))
                            Button(role: .destructive) {
                                store.remove(id: check.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help(loc.t("edit.helpDelete"))
                        }
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                Button {
                    editing = EditorSession(
                        initial: Check(
                            name: loc.t("edit.newName"),
                            timeZoneIdentifier: TimeZone.current.identifier,
                            schedule: Check.emptySchedule
                        ),
                        isNew: true
                    )
                } label: {
                    Label(loc.t("edit.addZona"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button(loc.t("preset.deepseek.name")) {
                        store.add(CheckPresets.deepSeekPricing())
                    }
                    Button(loc.t("preset.mimo.name")) {
                        store.add(CheckPresets.xiaomiMiMoPricing())
                    }
                } label: {
                    Label(loc.t("edit.addPreset"), systemImage: "wand.and.stars")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .controlSize(.small)
            .padding(8)
        }
    }
}
