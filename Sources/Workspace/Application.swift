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
    // Create the device.
    var deviceDesc = DeviceDescriptor()
    deviceDesc.deviceID = Device.fastestDeviceID
    self.device = Device(descriptor: deviceDesc)
    
    // Create the other resources.
    self.window = WindowUtilities.createWindow()
  }
}

#endif
