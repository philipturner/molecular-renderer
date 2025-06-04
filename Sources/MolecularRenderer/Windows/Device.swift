#if os(Windows)
import SwiftCOM
import WinSDK

// This file encapsulates the code for DirectX device selection. Will
// eventually merge with the code for Metal device selection. On Apple silicon,
// there is only ever one GPU, so the code is redundant. But there can be a
// single API that works cross-platform, and assumes multiple GPUs.

public class Device {
  let d3d12Debug: SwiftCOM.ID3D12Debug
  public let d3d12Device: SwiftCOM.ID3D12Device
  public let d3d12InfoQueue: SwiftCOM.ID3D12InfoQueue
  public let dxgiInfoQueue: SwiftCOM.IDXGIInfoQueue
  
  public init() {
    // Create the debug layer.
    let debug: SwiftCOM.ID3D12Debug =
      try! D3D12GetDebugInterface()
    try! debug.EnableDebugLayer()
    self.d3d12Debug = debug
    
    // Create the device.
    let factory: SwiftCOM.IDXGIFactory4 =
      try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
    let adapter = Self.createAdapter(factory: factory)
    let device: SwiftCOM.ID3D12Device =
      try! D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_1)
    self.d3d12Device = device
    
    // Create the info queue.
    let infoQueue = Self.createInfoQueue(device: device)
    try! infoQueue.SetBreakOnSeverity(
      D3D12_MESSAGE_SEVERITY_ERROR, true)
    self.d3d12InfoQueue = infoQueue
    
    // Create the DXGI info queue.
    self.dxgiInfoQueue = try! DXGIGetDebugInterface1(0)
    try! dxgiInfoQueue.SetBreakOnSeverity(
      DXGI_DEBUG_DXGI, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true)
  }
}

// Utility functions called in the initializer.
extension Device {
  // Choose the best GPU out of the two that appear.
  private static func createAdapter(
    factory: SwiftCOM.IDXGIFactory4
  ) -> SwiftCOM.IDXGIAdapter4 {
    var adapters: [SwiftCOM.IDXGIAdapter4] = []
    while true {
      let adapterID = adapters.count
      let adapter: SwiftCOM.IDXGIAdapter4? =
        try? factory.EnumAdapters(UInt32(adapterID)).QueryInterface()
      guard let adapter else {
        break
      }
      adapters.append(adapter)
    }
    
    // Choose the GPU with the greatest amount of memory. This is a relatively
    // crude heuristic for finding the fastest GPU.
    var maxAdapter: SwiftCOM.IDXGIAdapter4?
    var maxAdapterMemory: Int = .zero
    for adapterID in adapters.indices {
      let adapter = adapters[adapterID]
      let description = try! adapter.GetDesc()
      let dedicatedVideoMemory = description.DedicatedVideoMemory
      
      if dedicatedVideoMemory > maxAdapterMemory {
        maxAdapter = adapter
        maxAdapterMemory = Int(dedicatedVideoMemory)
      }
    }
    
    guard let maxAdapter else {
      fatalError("Could not find the fastest GPU.")
    }
    return maxAdapter
  }
  
  // Create an info queue.
  private static func createInfoQueue(
    device: SwiftCOM.ID3D12Device
  ) -> SwiftCOM.ID3D12InfoQueue {
    let iid = SwiftCOM.ID3D12InfoQueue.IID
    let interface = try! device.QueryInterface(iid: iid)
    let infoQueue = SwiftCOM.ID3D12InfoQueue(pUnk: interface)
    return infoQueue
  }
}

#endif
