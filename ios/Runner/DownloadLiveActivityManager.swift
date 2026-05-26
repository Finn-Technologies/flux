import Flutter
import UIKit
import ActivityKit

@available(iOS 16.1, *)
class DownloadLiveActivityManager {
    static let shared = DownloadLiveActivityManager()

    private var activity: Activity<DownloadActivityAttributes>?

    private init() {}

    func start(modelName: String, totalBytes: Int64) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled on this device")
            return
        }

        let initialState = DownloadActivityAttributes.ContentState(
            progress: 0.0,
            downloadedBytes: 0,
            totalBytes: totalBytes,
            speed: 0.0
        )

        let attributes = DownloadActivityAttributes(
            modelName: modelName,
            totalBytes: totalBytes
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            self.activity = activity
            print("Live Activity started: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func update(progress: Double, downloadedBytes: Int64, totalBytes: Int64, speed: Double) {
        Task {
            let contentState = DownloadActivityAttributes.ContentState(
                progress: progress,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                speed: speed
            )

            await self.activity?.update(
                using: contentState
            )
        }
    }

    func end() {
        Task {
            let finalState = DownloadActivityAttributes.ContentState(
                progress: 1.0,
                downloadedBytes: self.activity?.attributes.totalBytes ?? 0,
                totalBytes: self.activity?.attributes.totalBytes ?? 0,
                speed: 0.0
            )

            await self.activity?.end(
                using: finalState,
                dismissalPolicy: .default
            )
            self.activity = nil
        }
    }

    @objc func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let modelName = args["modelName"] as? String,
                  let totalBytes = args["totalBytes"] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing modelName or totalBytes", details: nil))
                return
            }
            start(modelName: modelName, totalBytes: totalBytes)
            result(true)

        case "update":
            guard let args = call.arguments as? [String: Any],
                  let progress = args["progress"] as? Double,
                  let downloadedBytes = args["downloadedBytes"] as? Int64,
                  let totalBytes = args["totalBytes"] as? Int64,
                  let speed = args["speed"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing progress parameters", details: nil))
                return
            }
            update(progress: progress, downloadedBytes: downloadedBytes, totalBytes: totalBytes, speed: speed)
            result(true)

        case "end":
            end()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
