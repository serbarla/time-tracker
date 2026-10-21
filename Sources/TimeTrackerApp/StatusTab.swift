import SwiftUI
import TimeTrackerCore

struct StatusTab: View {
    @EnvironmentObject private var store: CheckStore

    var body: some View {
        TimelineView(.everyMinute) { context in
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

    private var remoteFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        f.timeZone = check.timeZone
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(state.isOverlapping ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(check.name).fontWeight(.semibold)
                Spacer()
                Text(remoteFormatter.string(from: now))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            OverlapTimeline(bands: state.bands, now: now, isOverlapping: state.isOverlapping)
                .frame(height: 18)
            if state.isOverlapping, let interval = state.activeInterval {
                Label(warningText(until: interval.end), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func warningText(until end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "Overlap now — until \(f.string(from: end))"
    }
}
