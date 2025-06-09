#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let device: Device
  let window: HWND
  let swapChain: SwapChain
  
  init() {
    // Create the device.
    var deviceDesc = DeviceDescriptor()
    deviceDesc.deviceID = Device.fastestDeviceID
    self.device = Device(descriptor: deviceDesc)
    
    // Create the window.
    self.window = WindowUtilities.createWindow()
    
    // Create the swap chain.
    var swapChainDesc = SwapChainDescriptor()
    swapChainDesc.device = device
    swapChainDesc.window = window
    self.swapChain = SwapChain(descriptor: swapChainDesc)
  }
  
  func renderFrame() {
    let ringIndex = Int(
      try! swapChain.d3d12SwapChain.GetCurrentBackBufferIndex())
    print("ring index:", ringIndex)
  }
}

#endif
