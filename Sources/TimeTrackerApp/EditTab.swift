import SwiftUI
import TimeTrackerCore

struct EditTab: View {
    @EnvironmentObject private var store: CheckStore
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
                Text("No zonas.")
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
                            .help("Edit check")
                            Button(role: .destructive) {
                                store.remove(id: check.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete check")
                        }
                    }
                }
            }
            Divider()
            Button {
                editing = EditorSession(
                    initial: Check(
                        name: "New check",
                        timeZoneIdentifier: TimeZone.current.identifier,
                        schedule: Check.emptySchedule
                    ),
                    isNew: true
                )
            } label: {
                Label("Add Zona", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(8)
        }
    }
}
