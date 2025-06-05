#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  // var device: Device
  // var commandQueue: CommandQueue
  // var shader: Shader
  var window: HWND
  // var swapChain: SwiftCOM.IDXGISwapChain4
  
  // var frameBuffer: SwiftCOM.ID3D12Resource
  // var swapChainBuffers: [SwiftCOM.ID3D12Resource] = []
  // var descriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  // var ringBufferFence: SwiftCOM.ID3D12Fence
  
  init() {
    self.window = WindowUtilities.createWindow()
  }
}

#endif
