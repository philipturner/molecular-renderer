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
    self.d3d12Debug = try! D3D12GetDebugInterface()
    try! d3d12Debug.EnableDebugLayer()
    
    // Create the device.
    let deviceID = Self.fastestDeviceID
    let adapters = Self.createAdapters()
    guard deviceID >= 0,
          deviceID < adapters.count else {
      fatalError("Device ID was out of range.")
    }
    self.d3d12Device = try! D3D12CreateDevice(
      adapters[deviceID], D3D_FEATURE_LEVEL_12_1)
    
    // Create the info queue.
    self.d3d12InfoQueue = Self
      .createInfoQueue(device: d3d12Device)
    try! d3d12InfoQueue.SetBreakOnSeverity(
      D3D12_MESSAGE_SEVERITY_ERROR, true)
        
    // Create the DXGI info queue.
    self.dxgiInfoQueue = try! DXGIGetDebugInterface1(0)
    try! dxgiInfoQueue.SetBreakOnSeverity(
      DXGI_DEBUG_DXGI, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true)
  }
}

extension Device {
  static func createAdapters() -> [SwiftCOM.IDXGIAdapter4] {
    // Create the factory.
    let factory: SwiftCOM.IDXGIFactory4 =
      try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
    
    // Create the adapters.
    var adapters: [SwiftCOM.IDXGIAdapter4] = []
    while true {
      // Check whether the next adapter exists.
      let adapterID = UInt32(adapters.count)
      let adapter = try? factory.EnumAdapters(adapterID)
      guard let adapter else {
        break
      }
      
      // Assume every adapter conforms to IDXGIAdapter4.
      let adapter4: SwiftCOM.IDXGIAdapter4 =
      try! adapter.QueryInterface()
      adapters.append(adapter4)
    }
    
    return adapters
  }
  
  public static var fastestDeviceID: Int {
    let adapters = createAdapters()
    
    // Choose the GPU with the greatest amount of memory. This is a relatively
    // crude heuristic for finding the fastest GPU.
    var selectedAdapterID: Int?
    var maxAdapterMemory: Int = .zero
    for adapterID in adapters.indices {
      let adapter = adapters[adapterID]
      let description = try! adapter.GetDesc()
      let dedicatedVideoMemory = description.DedicatedVideoMemory
      
      if dedicatedVideoMemory > maxAdapterMemory {
        selectedAdapterID = adapterID
        maxAdapterMemory = Int(dedicatedVideoMemory)
      }
    }
    
    guard let selectedAdapterID else {
      fatalError("Could not find the fastest GPU.")
    }
    return selectedAdapterID
  }
  
  // Create an info queue from an ID3D12Device.
  static func createInfoQueue(
    device: SwiftCOM.ID3D12Device
  ) -> SwiftCOM.ID3D12InfoQueue {
    let iid = SwiftCOM.ID3D12InfoQueue.IID
    let interface = try! device.QueryInterface(iid: iid)
    let infoQueue = SwiftCOM.ID3D12InfoQueue(pUnk: interface)
    return infoQueue
  }
}

#endif
