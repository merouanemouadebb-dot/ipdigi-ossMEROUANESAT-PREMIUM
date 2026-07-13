import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    RegisterGeneratedPlugins(registry: flutterViewController)

    let screen = NSScreen.main?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    let w: CGFloat = min(1920, screen.width)
    let h: CGFloat = min(1080, screen.height)
    let frame = NSRect(
      x: screen.midX - w / 2,
      y: screen.midY - h / 2,
      width: w,
      height: h)

    self.minSize = NSSize(width: 1024, height: 720)
    self.setFrame(frame, display: false, animate: false)

    super.awakeFromNib()
  }
}
