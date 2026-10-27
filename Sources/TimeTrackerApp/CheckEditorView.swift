import SwiftUI
import TimeTrackerCore

@MainActor
struct CheckEditorView: View {
    private let initialID: UUID
    let onSave: (Check) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var loc: Localization
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
            ?? StateStyle(label: Localization.shared.t("state.active"), color: .green))
        _inactiveStyle = State(initialValue: initial.states?.inactive
            ?? StateStyle(label: Localization.shared.t("state.inactive"), color: .grey))
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
                Text(loc.t("editor.zona")).font(.headline)
                Spacer()
                Button(loc.t("editor.cancel")) { onCancel() }
                Button(loc.t("editor.save")) {
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

            TextField(loc.t("editor.name"), text: $name)
                .textFieldStyle(.roundedBorder)

            TextField(loc.t("editor.filter"), text: $filter)
                .textFieldStyle(.roundedBorder)

            Picker(loc.t("editor.timezone"), selection: $timeZoneID) {
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

                    Toggle(loc.t("editor.states"), isOn: $statesEnabled)
                        .font(.subheadline.weight(.semibold))
                    if statesEnabled {
                        StateStyleEditor(title: loc.t("editor.stateActive"), style: $activeStyle)
                        StateStyleEditor(title: loc.t("editor.stateInactive"), style: $inactiveStyle)
                    }

                    Toggle(loc.t("editor.notify"), isOn: $notifyOnFlip)
                        .font(.subheadline.weight(.semibold))

                    Divider()

                    HStack {
                        Text(loc.t("editor.details"))
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
                        Text(loc.t("editor.none"))
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
                        Text(loc.t("editor.specialDays"))
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
                        Text(loc.t("editor.none"))
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
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(loc.weekday(weekday))
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
                Text(loc.t("editor.off"))
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
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack {
            TextField(loc.t("editor.rangeStartPlaceholder"), text: $range.start)
            Text("–")
            TextField(loc.t("editor.rangeEndPlaceholder"), text: $range.end)
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
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField(loc.t("editor.label"), text: $style.label)
                    .textFieldStyle(.roundedBorder)
                Picker(loc.t("editor.color"), selection: $style.color) {
                    ForEach(StateColor.allCases, id: \.self) { color in
                        Label {
                            Text(loc.t("color.\(color.rawValue)"))
                        } icon: {
                            Image(nsImage: color.swatchImage)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            TextField(loc.t("editor.note"), text: Binding(
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
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack {
            TextField(loc.t("editor.name"), text: $row.name)
            TextField(loc.t("editor.activeValue"), text: $row.active)
            TextField(loc.t("editor.inactiveValue"), text: $row.inactive)
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
    @EnvironmentObject private var loc: Localization

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
                DatePicker(loc.t("editor.from"), selection: dayBinding(\.from), displayedComponents: .date)
                DatePicker(loc.t("editor.to"), selection: dayBinding(\.to), displayedComponents: .date)
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
            .datePickerStyle(.compact)
            HStack {
                Picker(loc.t("editor.mode"), selection: $override.mode) {
                    Text(loc.t("editor.forceInactive")).tag(DayOverride.Mode.forceInactive)
                    Text(loc.t("editor.forceActive")).tag(DayOverride.Mode.forceActive)
                }
                .pickerStyle(.menu)
                TextField(loc.t("editor.label"), text: $override.label)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .font(.subheadline)
    }
}
