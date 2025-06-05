#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let device: Device
  let commandQueue: CommandQueue
  let window: HWND
  
  // var shader: Shader
  
  
  
  init() {
    self.device = Device()
    self.commandQueue = CommandQueue()
    self.window = WindowUtilities.createWindow()
  }
  
  // TODO: Next, set up the swap chain.
}

#endif
