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
    @State private var statesEnabled: Bool
    @State private var activeStyle: StateStyle
    @State private var inactiveStyle: StateStyle
    @State private var details: [DetailRow]
    @State private var dayOverrides: [DayOverride]
    @State private var notifyOnFlip: Bool

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
        _statesEnabled = State(initialValue: initial.states != nil)
        _activeStyle = State(initialValue: initial.states?.active
            ?? StateStyle(label: "In range", color: .green))
        _inactiveStyle = State(initialValue: initial.states?.inactive
            ?? StateStyle(label: "Out", color: .grey))
        _details = State(initialValue: initial.details)
        _dayOverrides = State(initialValue: initial.dayOverrides)
        _notifyOnFlip = State(initialValue: initial.notifyOnFlip)
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
                    onSave(Check(
                        id: initialID,
                        name: name,
                        timeZoneIdentifier: timeZoneID,
                        schedule: schedule,
                        states: statesEnabled
                            ? CheckStates(active: activeStyle, inactive: inactiveStyle)
                            : nil,
                        details: details,
                        dayOverrides: dayOverrides,
                        notifyOnFlip: notifyOnFlip
                    ))
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

                    Divider()

                    Toggle("Estados personalizados", isOn: $statesEnabled)
                        .font(.subheadline.weight(.semibold))
                    if statesEnabled {
                        StateStyleEditor(title: "Activo", style: $activeStyle)
                        StateStyleEditor(title: "Inactivo", style: $inactiveStyle)
                    }

                    Toggle("Notificar cambios de estado", isOn: $notifyOnFlip)
                        .font(.subheadline.weight(.semibold))

                    Divider()

                    HStack {
                        Text("Detalles")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            details.append(DetailRow(name: "", active: "", inactive: ""))
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    if details.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(details.indices), id: \.self) { idx in
                            DetailRowEditor(row: $details[idx]) {
                                details.remove(at: idx)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Días especiales")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            let today = overrideDayKey()
                            dayOverrides.append(DayOverride(
                                from: today, to: today, mode: .forceInactive, label: ""
                            ))
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    if dayOverrides.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(dayOverrides.indices), id: \.self) { idx in
                            OverrideRowEditor(
                                override: $dayOverrides[idx],
                                calendar: checkCalendar
                            ) {
                                dayOverrides.remove(at: idx)
                            }
                        }
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

    /// Gregorian calendar in the currently selected zone (override dates live there).
    private var checkCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return c
    }

    /// Today's "yyyy-MM-dd" in the check's zone; default for new overrides.
    private func overrideDayKey() -> String {
        OverrideRowEditor.dayFormatter(timeZone: checkCalendar.timeZone)
            .string(from: Date())
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

/// Label / palette color / optional note for one state.
struct StateStyleEditor: View {
    let title: String
    @Binding var style: StateStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("Label", text: $style.label)
                    .textFieldStyle(.roundedBorder)
                Picker("Color", selection: $style.color) {
                    ForEach(StateColor.allCases, id: \.self) { color in
                        Label(color.rawValue.capitalized, systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                            .tag(color)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            TextField("Note", text: Binding(
                get: { style.note ?? "" },
                set: { style.note = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }
}

/// One display-only detail row: name plus its active/inactive values.
struct DetailRowEditor: View {
    @Binding var row: DetailRow
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Name", text: $row.name)
            TextField("Active", text: $row.active)
            TextField("Inactive", text: $row.inactive)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .textFieldStyle(.roundedBorder)
    }
}

/// One day-level override: inclusive date range, forced mode, optional label.
struct OverrideRowEditor: View {
    @Binding var override: DayOverride
    let calendar: Calendar
    let onDelete: () -> Void

    static func dayFormatter(timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private func dayBinding(_ keyPath: WritableKeyPath<DayOverride, String>) -> Binding<Date> {
        let formatter = Self.dayFormatter(timeZone: calendar.timeZone)
        return Binding(
            get: { formatter.date(from: override[keyPath: keyPath]) ?? Date() },
            set: { override[keyPath: keyPath] = formatter.string(from: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                DatePicker("From", selection: dayBinding(\.from), displayedComponents: .date)
                DatePicker("To", selection: dayBinding(\.to), displayedComponents: .date)
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
            .datePickerStyle(.compact)
            HStack {
                Picker("Mode", selection: $override.mode) {
                    Text("Force inactive").tag(DayOverride.Mode.forceInactive)
                    Text("Force active").tag(DayOverride.Mode.forceActive)
                }
                .pickerStyle(.menu)
                TextField("Label", text: $override.label)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .font(.subheadline)
    }
}
