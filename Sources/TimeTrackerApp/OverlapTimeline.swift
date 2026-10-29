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
                    y: 2,
                    width: x(end) - x(start),
                    height: 14
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(bandColor)
                )
            }

            for h in 0..<24 {
                let tickX = x(dayStart.addingTimeInterval(3600 * Double(h)))
                let isMajor = h % 3 == 0
                let tick = CGRect(x: tickX, y: isMajor ? 16 : 18, width: 1, height: isMajor ? 4 : 2)
                context.fill(Path(tick), with: .color(Color(white: 0.6)))
                if isMajor {
                    let label = Text(String(format: "%02d", h))
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    if h == 0 {
                        context.draw(label, at: CGPoint(x: tickX + 1, y: 25.5), anchor: .leading)
                    } else {
                        context.draw(label, at: CGPoint(x: tickX, y: 25.5), anchor: .center)
                    }
                }
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
