#if os(Windows)
import SwiftCOM
import WinSDK

public struct SwapChainDescriptor {
  public var device: Device?
  public var window: HWND?
  
  public init() {
    
  }
}

public class SwapChain {
  public let d3d12SwapChain: SwiftCOM.IDXGISwapChain4
  
  public private(set) var backBuffers: [SwiftCOM.ID3D12Resource] = []
  public let frameBuffer: SwiftCOM.ID3D12Resource
  public let frameBufferDescriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  
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
    let d3d12SwapChain1 = try! factory.CreateSwapChainForHwnd(
      device.commandQueue.d3d12CommandQueue, // pDevice
      window, // hWnd
      swapChainDesc, // pDesc
      nil, // pFullscreenDesc
      nil) // pRestrictToOutput
    self.d3d12SwapChain = try! d3d12SwapChain1.QueryInterface()
    
    // Set up the back buffers.
    for ringIndex in 0..<3 {
      // Create the back buffer.
      var backBuffer: SwiftCOM.ID3D12Resource
      backBuffer = try! d3d12SwapChain
        .GetBuffer(UInt32(ringIndex))
      
      // Append the back buffer to the list.
      backBuffers.append(backBuffer)
    }
    
    // Set up the frame buffer.
    do {
      // Fill the heap properties.
      var heapProperties = D3D12_HEAP_PROPERTIES()
      heapProperties.Type = D3D12_HEAP_TYPE_DEFAULT
      
      // Fill the resource descriptor.
      let backBuffer = backBuffers[0]
      var resourceDesc = try! backBuffer.GetDesc()
      var flagsRawValue = resourceDesc.Flags.rawValue
      flagsRawValue |= D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS.rawValue
      resourceDesc.Flags = D3D12_RESOURCE_FLAGS(rawValue: flagsRawValue)
      
      // Create the resource.
      self.frameBuffer =
      try! device.d3d12Device.CreateCommittedResource(
        heapProperties, // pHeapProperties
        D3D12_HEAP_FLAG_NONE, // HeapFlags
        resourceDesc, // pDesc
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, // InitialResourceState
        nil) // pOptimizedClearValue
    }
    
    // Set up the frame buffer's descriptor heap.
    do {
      // Fill the heap descriptor.
      var descriptorHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
      descriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV
      descriptorHeapDesc.NumDescriptors = 1
      descriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE
      
      // Create the descriptor heap.
      self.frameBufferDescriptorHeap = try! device.d3d12Device
        .CreateDescriptorHeap(descriptorHeapDesc)
      
      // Create the UAV.
      let cpuDescriptorHandle = try! frameBufferDescriptorHeap
        .GetCPUDescriptorHandleForHeapStart()
      try! device.d3d12Device.CreateUnorderedAccessView(
        frameBuffer, // pResource
        nil, // pCounterResource,
        nil, // pDesc
        cpuDescriptorHandle) // DestDescriptor
    }
  }
}

extension SwapChain {
  // Abstract away some code that appears unwieldy otherwise.
  static func createSwapChainDescriptor() -> DXGI_SWAP_CHAIN_DESC1 {
    var swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
    swapChainDesc.Width = 1440
    swapChainDesc.Height = 1440
    swapChainDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
    swapChainDesc.Stereo = false
    swapChainDesc.SampleDesc = DXGI_SAMPLE_DESC(Count: 1, Quality: 0)
    swapChainDesc.BufferUsage = DXGI_USAGE_BACK_BUFFER
    swapChainDesc.BufferCount = 3
    swapChainDesc.Scaling = DXGI_SCALING_NONE
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
    swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED
    swapChainDesc.Flags = 0
    
    return swapChainDesc
  }
}

#endif
