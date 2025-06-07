#if os(Windows)
import SwiftCOM
import WinSDK

// This file will merge with 'View', currently under 'macOS'.

public struct SwapChainDescriptor {
  public var commandQueue: CommandQueue?
  public var window: HWND?
  
  public init() {
    
  }
}

public class SwapChain {
  // var swapChain: SwiftCOM.IDXGISwapChain4
  
  // var frameBuffer: SwiftCOM.ID3D12Resource
  // var swapChainBuffers: [SwiftCOM.ID3D12Resource] = []
  // var descriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  // var ringBufferFence: SwiftCOM.ID3D12Fence
  
  public init(descriptor: SwapChainDescriptor) {
    fatalError("Not implemented.")
  }
}

#endif
