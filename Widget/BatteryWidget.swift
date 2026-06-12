import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BatteryEntry: TimelineEntry {
    let date: Date
    let data: BatteryData
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: Date(), data: BatteryData(level: 0.72, state: 1, timestamp: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(BatteryEntry(date: Date(), data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let entry = BatteryEntry(date: Date(), data: .load())
        // 15-minute fallback refresh; real updates come via WCSession → WidgetCenter.reloadAllTimelines()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:   CircularComplication(data: entry.data)
            case .accessoryRectangular: RectangularComplication(data: entry.data)
            case .accessoryCorner:     CornerComplication(data: entry.data)
            case .accessoryInline:     InlineComplication(data: entry.data)
            default:                   CircularComplication(data: entry.data)
            }
        }
        // Mandatory since watchOS 10 SDK — widgets without it are not rendered on device
        .containerBackground(for: .widget) { Color.clear }
    }
}

// Circular — gauge ring with % in centre
struct CircularComplication: View {
    let data: BatteryData

    var body: some View {
        if data.isUnknown {
            Image(systemName: "iphone.slash")
        } else {
            Gauge(value: Double(max(0, data.level))) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(data.percentage)")
                        .font(.system(size: 13, weight: .bold))
                    if data.isCharging {
                        Image(systemName: "bolt.fill").font(.system(size: 6))
                    }
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeColor)
        }
    }

    var gaugeColor: Color {
        if data.isCharging { return .green }
        if data.level < 0.2 { return .red }
        if data.level < 0.4 { return .orange }
        return .green
    }
}

// Rectangular — icon + % + label
struct RectangularComplication: View {
    let data: BatteryData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.isCharging ? "battery.100.bolt" : batterySymbol)
                .font(.title3)
                .foregroundStyle(levelColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(data.isUnknown ? "—" : "\(data.percentage)%")
                    .font(.headline)
                Text("iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    var batterySymbol: String {
        switch data.level {
        case ..<0:    return "battery.0"
        case ..<0.25: return "battery.25"
        case ..<0.50: return "battery.50"
        case ..<0.75: return "battery.75"
        default:      return "battery.100"
        }
    }

    var levelColor: Color {
        if data.isCharging { return .green }
        if data.level < 0.2 { return .red }
        if data.level < 0.4 { return .orange }
        return .green
    }
}

// Corner — iPhone icon + gauge bar label
struct CornerComplication: View {
    let data: BatteryData

    var body: some View {
        Image(systemName: "iphone")
            .widgetLabel {
                if data.isUnknown {
                    Text("—")
                } else {
                    Gauge(value: Double(max(0, data.level))) {
                        Text(data.isCharging ? "⚡" : "")
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(data.level < 0.2 ? .red : data.level < 0.4 ? .orange : .green)
                }
            }
    }
}

// Inline — text only
struct InlineComplication: View {
    let data: BatteryData

    var body: some View {
        Label(
            data.isUnknown ? "iPhone —" :
            data.isCharging ? "iPhone \(data.percentage)% ⚡" :
            "iPhone \(data.percentage)%",
            systemImage: "iphone"
        )
    }
}

// MARK: - Widget definition

struct BatteryWidget: Widget {
    let kind = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("iPhone Battery")
        .description("iPhone battery level on your watch face")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

@main
struct BatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
    }
}
