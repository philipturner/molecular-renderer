#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let device: Device
  let window: HWND
  
  init() {
    self.device = Device()
    self.window = WindowUtilities.createWindow()
  }
}

#endif
