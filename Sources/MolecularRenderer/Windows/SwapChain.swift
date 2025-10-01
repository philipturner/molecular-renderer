#if os(Windows)
import SwiftCOM
import WinSDK

struct SwapChainDescriptor {
  var device: Device?
  var display: Display?
  var window: Window?
}

class SwapChain {
  let d3d12SwapChain: SwiftCOM.IDXGISwapChain4
  let waitableObject: HANDLE
  private(set) var backBuffers: [SwiftCOM.ID3D12Resource] = []
  
  init(descriptor: SwapChainDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let window = descriptor.window else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the factory.
    let factory: SwiftCOM.IDXGIFactory4 =
    try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
    
    // Create the swap chain descriptor.
    let swapChainDesc = Self.createSwapChainDescriptor(
      frameBufferSize: display.frameBufferSize)
    
    // Create the swap chain.
    let d3d12SwapChain1 = try! factory.CreateSwapChainForHwnd(
      device.commandQueue.d3d12CommandQueue, // pDevice
      window.hWnd, // hWnd
      swapChainDesc, // pDesc
      nil, // pFullscreenDesc
      display.dxgiOutput) // pRestrictToOutput
    self.d3d12SwapChain = try! d3d12SwapChain1.QueryInterface()
    
    // Set up the frame latency waitable object.
    do {
      let waitableObject = try! d3d12SwapChain.GetFrameLatencyWaitableObject()
      guard let waitableObject else {
        fatalError("Could not create waitable object.")
      }
      self.waitableObject = waitableObject
      
      try! d3d12SwapChain.SetMaximumFrameLatency(2)
    }
    
    // Set up the back buffers.
    for ringIndex in 0..<3 {
      // Create the back buffer.
      var backBuffer: SwiftCOM.ID3D12Resource
      backBuffer = try! d3d12SwapChain
        .GetBuffer(UInt32(ringIndex))
      
      // Append the back buffer to the list.
      backBuffers.append(backBuffer)
    }
  }
}

extension SwapChain {
  // Abstract away some code that appears unwieldy otherwise.
  static func createSwapChainDescriptor(
    frameBufferSize: SIMD2<Int>
  ) -> DXGI_SWAP_CHAIN_DESC1 {
    var swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
    swapChainDesc.Width = UInt32(frameBufferSize[0])
    swapChainDesc.Height = UInt32(frameBufferSize[1])
    swapChainDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
    swapChainDesc.Stereo = false
    swapChainDesc.SampleDesc.Count = 1
    swapChainDesc.SampleDesc.Quality = 0
    swapChainDesc.BufferUsage = DXGI_USAGE_BACK_BUFFER
    swapChainDesc.BufferCount = 3
    swapChainDesc.Scaling = DXGI_SCALING_NONE
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED
    swapChainDesc.Flags = UInt32(
      DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT.rawValue)
    
    return swapChainDesc
  }
}
#endif
