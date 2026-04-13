import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.example.flux/storage", binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getStorageSpace" {
          let fileManager = FileManager.default
          do {
              let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
              let free = attrs[.systemFreeSize] as? Int64 ?? 0
              let total = attrs[.systemSize] as? Int64 ?? 0
              result(["total": total, "free": free])
          } catch {
              result(FlutterError(code: "STORAGE_ERROR", message: "Failed to get storage info", details: nil))
          }
      } else if call.method == "getDeviceRAM" {
          let physicalMemory = ProcessInfo.processInfo.physicalMemory
          result(Int64(physicalMemory))
      } else {
          result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
