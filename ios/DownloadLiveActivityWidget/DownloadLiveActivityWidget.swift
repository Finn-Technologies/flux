import WidgetKit
import SwiftUI
import ActivityKit

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            DownloadLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        Text(context.attributes.modelName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                        HStack {
                            Text(formattedBytes(context.state.downloadedBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if context.state.speed > 0 {
                                Text(formattedSpeed(context.state.speed))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            } compactTrailing: {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
                    .scaleEffect(0.8)
            } minimal: {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
                    .scaleEffect(0.7)
            }
        }
    }
}

struct DownloadLockScreenView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading \(context.attributes.modelName)")
                    .font(.headline)
                    .lineLimit(1)

                ProgressView(value: context.state.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                HStack {
                    Text("\(formattedBytes(context.state.downloadedBytes)) / \(formattedBytes(context.state.totalBytes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .activityBackgroundTint(nil)
    }
}

private func formattedBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func formattedSpeed(_ speed: Double) -> String {
    if speed < 1_000_000 {
        return String(format: "%.1f KB/s", speed / 1_024)
    } else {
        return String(format: "%.1f MB/s", speed / 1_048_576)
    }
}
