#if os(Windows)
import SwiftCOM
import WinSDK

// This file will merge with 'View', currently under 'macOS'.

public struct SwapChainDescriptor {
  public var device: Device?
  public var window: HWND?
  
  public init() {
    
  }
}

public class SwapChain {
  var swapChain: SwiftCOM.IDXGISwapChain4
  
  // Hold the render targets as a state variable, just to follow the tutorials.
  // I feel inclined to change this API in the future.
  var renderTargets: [SwiftCOM.ID3D12Resource] = []
  
  // For simplicity, a separate descriptor heap per render target. I don't
  // see why we can't just reuse the same heap slot for each successive frame.
  // I want to try that at some point.
  var descriptorHeaps: [SwiftCOM.ID3D12DescriptorHeap] = []
  
  public init(descriptor: SwapChainDescriptor) {
    guard let device = descriptor.device,
          let window = descriptor.window else {
      fatalError("Descriptor was incomplete.")
    }
    
    fatalError("Not implemented.")
  }
}

#endif
