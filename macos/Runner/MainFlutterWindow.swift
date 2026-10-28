import CFNetwork
import Cocoa
import DuanjuCore
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    ZgjEnsureCoreLinked()
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()
    let info = Bundle.main.localizedInfoDictionary ?? Bundle.main.infoDictionary
    if let name = info?["CFBundleDisplayName"] as? String {
      self.title = name
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "duanju/device", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "systemProxy" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] ?? [:]
      func address(_ prefix: String) -> String {
        guard (settings["\(prefix)Enable"] as? NSNumber)?.boolValue == true,
              let host = settings["\(prefix)Proxy"] as? String,
              let port = settings["\(prefix)Port"] as? NSNumber,
              !host.isEmpty, port.intValue > 0 else { return "" }
        let name = host.contains(":") ? "[\(host)]" : host
        return "http://\(name):\(port.intValue)"
      }
      let http = address("HTTP")
      let https = address("HTTPS")
      result(["http": http, "https": https.isEmpty ? http : https,
              "bypass": settings["ExceptionsList"] as? [String] ?? [],
              "pac": (settings["ProxyAutoConfigEnable"] as? NSNumber)?.boolValue == true])
    }

    super.awakeFromNib()
  }
}
