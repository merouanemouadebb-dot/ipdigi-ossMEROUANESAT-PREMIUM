import Cocoa
import Darwin
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    // macOS soft FD limiti default 256. mpv her açık HTTP stream
    // için birden fazla socket + cache + demuxer FD'si açıyor;
    // birkaç başarısız reconnect sonrası limit doluyor ve
    // media_kit'in TempFile.create() çağrısı "Too many open files"
    // ile patlıyor → o noktadan sonra hiçbir kanal açılamaz.
    // Hard limit'in altında kalmak şartıyla soft'u 10240'a çekiyoruz.
    var lim = rlimit(rlim_cur: 0, rlim_max: 0)
    if getrlimit(RLIMIT_NOFILE, &lim) == 0 {
      let target: rlim_t = 10240
      let newSoft = min(target, lim.rlim_max)
      if lim.rlim_cur < newSoft {
        lim.rlim_cur = newSoft
        setrlimit(RLIMIT_NOFILE, &lim)
      }
    }
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
