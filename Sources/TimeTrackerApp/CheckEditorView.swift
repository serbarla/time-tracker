import SwiftUI
import TimeTrackerCore

struct CheckEditorView: View {
    private let initialID: UUID
    let onSave: (Check) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var timeZoneID: String
    @State private var schedule: [String: [HourRange]]
    @State private var filter = ""

    init(initial: Check, onSave: @escaping (Check) -> Void, onCancel: @escaping () -> Void) {
        self.initialID = initial.id
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        let initialZone = TimeZone(identifier: initial.timeZoneIdentifier)?.identifier
            ?? TimeZone.current.identifier
        _timeZoneID = State(initialValue: initialZone)
        var normalized = Check.emptySchedule
        for (key, ranges) in initial.schedule { normalized[key] = ranges }
        _schedule = State(initialValue: normalized)
    }

    private var allZoneIDs: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    private var filteredZoneIDs: [String] { matchingZoneIDs(for: filter) }

    private func matchingZoneIDs(for query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allZoneIDs }
        return allZoneIDs.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Zona").font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Save") {
                    onSave(Check(id: initialID, name: name, timeZoneIdentifier: timeZoneID, schedule: schedule))
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !allZoneIDs.contains(timeZoneID))
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Filtrar Zonas", text: $filter)
                .textFieldStyle(.roundedBorder)

            Picker("Time zone", selection: $timeZoneID) {
                ForEach(filteredZoneIDs, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Weekday.allCases) { weekday in
                        WeekdayRow(weekday: weekday, ranges: rangesBinding(for: weekday))
                    }
                }
                // 20% of the 380pt popover width — keeps the "+" buttons clear of the overlay scrollbar.
                .padding(.trailing, 76)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: filter) { _, newFilter in
            let query = newFilter.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty, let first = matchingZoneIDs(for: query).first else { return }
            timeZoneID = first
        }
    }

    private func rangesBinding(for weekday: Weekday) -> Binding<[HourRange]> {
        let key = weekday.jsonKey
        return Binding(
            get: { schedule[key] ?? [] },
            set: { schedule[key] = $0 }
        )
    }
}

struct WeekdayRow: View {
    let weekday: Weekday
    @Binding var ranges: [HourRange]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(weekday.shortName)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 40, alignment: .leading)
                Spacer()
                Button {
                    ranges.append(HourRange(start: "09:00", end: "17:00"))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            if ranges.isEmpty {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(ranges.indices), id: \.self) { idx in
                    RangeRow(range: $ranges[idx]) {
                        ranges.remove(at: idx)
                    }
                }
            }
        }
    }
}

struct RangeRow: View {
    @Binding var range: HourRange
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("09:00", text: $range.start)
            Text("–")
            TextField("17:00", text: $range.end)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .textFieldStyle(.roundedBorder)
    }
}
