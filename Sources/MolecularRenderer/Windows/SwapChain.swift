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
  var renderTargets: [SwiftCOM.ID3D12Resource]
  
  // For simplicity, a separate descriptor heap per render target. I don't
  // see why we can't just reuse the same heap slot for each successive frame.
  // I want to try that at some point.
  var descriptorHeaps: [SwiftCOM.ID3D12DescriptorHeap]
  
  public init(descriptor: SwapChainDescriptor) {
    guard let device = descriptor.device,
          let window = descriptor.window else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the factory.
    let factory: SwiftCOM.IDXGIFactory4 =
      try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
    
    // Create the swap chain descriptor.
    let swapChainDesc = Self.createSwapChainDescriptor()
    
    // Create the swap chain.
    let swapChain1 = try! factory.CreateSwapChainForHwnd(
      device.commandQueue.d3d12CommandQueue, // pDevice
      window, // hWnd
      swapChainDesc, // pDesc
      nil, // pFullscreenDesc
      nil) // pRestrictToOutput
    self.swapChain = try! swapChain1.QueryInterface()
    
    // Fill the list of render targets.
    renderTargets = []
    for ringIndex in 0..<3 {
      // Create the render target.
      var renderTarget: SwiftCOM.ID3D12Resource
      renderTarget = try! swapChain
        .GetBuffer(UInt32(ringIndex))
      
      // Append the render target to the list.
      renderTargets.append(renderTarget)
    }
    
    // Fill the list of descriptor heaps.
    descriptorHeaps = []
    for ringIndex in 0..<3 {
      // Fill the heap descriptor.
      var descriptorHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
      descriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
      descriptorHeapDesc.NumDescriptors = 1
      descriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
      
      // Create the descriptor heap.
      var descriptorHeap: SwiftCOM.ID3D12DescriptorHeap
      descriptorHeap = try! device.d3d12Device
        .CreateDescriptorHeap(descriptorHeapDesc)
      
      // void CreateRenderTargetView(
      //   [in, optional] ID3D12Resource                      *pResource,
      //   [in, optional] const D3D12_RENDER_TARGET_VIEW_DESC *pDesc,
      //   [in]           D3D12_CPU_DESCRIPTOR_HANDLE         DestDescriptor
      // );
      
      // Append the descriptor heap to the list.
      descriptorHeaps.append(descriptorHeap)
    }
    
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
