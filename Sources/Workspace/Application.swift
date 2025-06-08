#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let device: Device
  let window: HWND
  
  let startTime: Int64
  
  init() {
    // Create the device.
    var deviceDesc = DeviceDescriptor()
    deviceDesc.deviceID = Device.fastestDeviceID
    self.device = Device(descriptor: deviceDesc)
    
    // Create the other resources.
    self.window = WindowUtilities.createWindow()
    
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    self.startTime = largeInteger.QuadPart
  }
}

#endif
