import SwiftUI
import TimeTrackerCore

/// 24h local-time bar: shaded bands = overlap periods, vertical line = now.
/// Green while `now` is inside an overlap; grey otherwise.
struct OverlapTimeline: View {
    let bands: [DateInterval]
    let now: Date
    let isOverlapping: Bool
    /// Band/marker color while overlapping (v1 default: green).
    var activeColor: Color = .green

    private var localCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white)
            )

            let bandColor: Color = isOverlapping
                ? activeColor
                : Color(white: 0.75)

            let dayStart = localCalendar.startOfDay(for: now)
            let span: TimeInterval = 86400
            func x(_ d: Date) -> CGFloat {
                CGFloat(d.timeIntervalSince(dayStart) / span) * size.width
            }

            for band in bands {
                let start = max(band.start, dayStart)
                let end = min(band.end, dayStart.addingTimeInterval(span))
                guard end > start else { continue }
                let rect = CGRect(
                    x: x(start),
                    y: size.height * 0.2,
                    width: x(end) - x(start),
                    height: size.height * 0.6
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(bandColor)
                )
            }

            let nx = x(now)
            let marker = CGRect(x: nx - 1, y: 0, width: 2, height: size.height)
            context.fill(
                Path(marker),
                with: .color(isOverlapping ? activeColor : Color(white: 0.45))
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
