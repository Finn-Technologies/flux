import ActivityKit

@available(iOS 16.1, *)
struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var downloadedBytes: Int64
        var totalBytes: Int64
        var speed: Double
    }

    var modelName: String
    var totalBytes: Int64
}
