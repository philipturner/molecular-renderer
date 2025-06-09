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
    
    // Create the swap chain [encapsulating in a temporary scope].
    do {
      // Create the swap chain descritor.
      let swapChainDesc = Self.createSwapChainDescriptor()
      
      // Create the factory.
      let factory: SwiftCOM.IDXGIFactory4 =
        try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
      
      // Create the swap chain.
      
    }
    
    fatalError("Not implemented.")
  }
}

extension SwapChain {
  // An experiment with abstracting away some code that appears unwieldy
  // otherwise.
  static func createSwapChainDescriptor() -> DXGI_SWAP_CHAIN_DESC1 {
    var swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
    swapChainDesc.Width = 1440
    swapChainDesc.Height = 1440
    swapChainDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
    swapChainDesc.Stereo = false
    swapChainDesc.SampleDesc = DXGI_SAMPLE_DESC(Count: 1, Quality: 0)
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
    swapChainDesc.BufferCount = 3
    swapChainDesc.Scaling = DXGI_SCALING_NONE
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED
    swapChainDesc.Flags = 0
    
    return swapChainDesc
  }
}

#endif
