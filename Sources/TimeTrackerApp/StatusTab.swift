import SwiftUI
import TimeTrackerCore

struct StatusTab: View {
    @EnvironmentObject private var store: CheckStore

    var body: some View {
        // 1s ticks drive the H:MM:SS countdown while the panel is open.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if store.checks.isEmpty {
                Text("No zonas yet — add one in the Edit tab.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.checks) { check in
                            CheckStatusRow(check: check, now: now)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
}

struct CheckStatusRow: View {
    let check: Check
    let now: Date

    private var state: OverlapState { OverlapEngine.evaluate(check: check, now: now) }
    private var styles: CheckStates { check.displayStates }
    private var currentStyle: StateStyle { state.isOverlapping ? styles.active : styles.inactive }

    private var remoteFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        f.timeZone = check.timeZone
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if check.states != nil {
                    StateChip(style: currentStyle)
                } else {
                    Circle()
                        .fill(state.isOverlapping ? Color.green : Color(white: 0.6))
                        .frame(width: 8, height: 8)
                }
                Text(check.name).fontWeight(.semibold)
                Spacer()
                Text(remoteFormatter.string(from: now))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            OverlapTimeline(
                bands: state.bands,
                now: now,
                isOverlapping: state.isOverlapping,
                activeColor: styles.active.color.swatch
            )
            .frame(height: 18)
            if let transition = state.nextTransition {
                HStack(spacing: 8) {
                    Text(countdownText(to: transition))
                    if let start = state.windowStart, transition > start {
                        ProgressView(value: now.timeIntervalSince(start), total: transition.timeIntervalSince(start))
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 140)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            if state.isOverlapping, let interval = state.activeInterval {
                Label(warningText(until: interval.end), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            upcomingTable
            if !check.details.isEmpty {
                detailsDisclosure
            }
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(white: 0.85), lineWidth: 1)
        )
    }

    /// Next 4 windows (the first contains `now`) as compact rows.
    private var upcomingTable: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(state.upcoming.prefix(4).enumerated()), id: \.offset) { index, slice in
                HStack(spacing: 6) {
                    StateChip(
                        style: slice.isActive ? styles.active : styles.inactive,
                        compact: true
                    )
                    Text(sliceLabel(slice))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(index == 0 ? remainingText(slice) : durationText(slice.end.timeIntervalSince(slice.start)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(index == 0 ? .primary : .secondary)
                }
            }
        }
    }

    private var detailsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(check.details.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text(state.isOverlapping ? row.active : row.inactive)
                            .foregroundStyle(.secondary)
                        if let transition = state.nextTransition {
                            Text("→ \(state.isOverlapping ? row.inactive : row.active) from \(timeOnly(transition))")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption2)
                }
            }
        } label: {
            Text("Details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func countdownText(to transition: Date) -> String {
        let total = max(0, Int(transition.timeIntervalSince(now)))
        return String(format: "Next in %d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "HH:mm – HH:mm" in the check's zone; adds the weekday when the slice crosses days.
    private func sliceLabel(_ slice: WindowSlice) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = check.timeZone
        let crossesDays = !calendar.isDate(slice.start, inSameDayAs: slice.end)
        let fmt = DateFormatter()
        fmt.timeZone = check.timeZone
        fmt.dateFormat = crossesDays ? "EEE HH:mm" : "HH:mm"
        return "\(fmt.string(from: slice.start)) – \(fmt.string(from: slice.end))"
    }

    private func remainingText(_ slice: WindowSlice) -> String {
        "\(durationText(max(0, slice.end.timeIntervalSince(now)))) left"
    }

    /// Compact "1h 5m" / "45m" duration.
    private func durationText(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = check.timeZone
        return f.string(from: date)
    }

    private func warningText(until end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "Overlap now — until \(f.string(from: end))"
    }
}
