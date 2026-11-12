import Flutter
import UIKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "be_lon_khon/photobooth_gallery",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "saveImage" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_file", message: "Image unavailable", details: nil)); return
      }
      let source = URL(fileURLWithPath: path).resolvingSymlinksInPath()
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .resolvingSymlinksInPath().path + "/"
      guard source.path.hasPrefix(documents), source.pathExtension.lowercased() == "png",
        FileManager.default.fileExists(atPath: source.path) else {
        result(FlutterError(code: "invalid_file", message: "Image unavailable", details: nil)); return
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async { result(FlutterError(code: "permission_denied", message: "Save permission denied", details: nil)) }
          return
        }
        PHPhotoLibrary.shared().performChanges({
          PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: source, options: nil)
        }) { success, _ in
          DispatchQueue.main.async {
            if success { result(true) }
            else { result(FlutterError(code: "save_failed", message: "Image not saved", details: nil)) }
          }
        }
      }
    }
  }
}
