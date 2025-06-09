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
  
  let startTime: Int64
  
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
    
    // Create the start time, for reference.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    self.startTime = largeInteger.QuadPart
  }
  
  func renderFrame() {
    // Fetch the current time.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    let currentTime = largeInteger.QuadPart
    
    // Display the time difference.
    let elapsedTime = Double(currentTime - startTime) / Double(10e6)
    let frameID = Int(elapsedTime * 60)
    print("frame ID:", frameID)
    
    // Fetch the ring index.
    let ringIndex = Int(
      try! swapChain.d3d12SwapChain.GetCurrentBackBufferIndex())
    
    // Send the render target to the DWM.
    try! swapChain.d3d12SwapChain.Present(1, 0)
  }
}

#endif
