#if os(Windows)
import SwiftCOM
import WinSDK

// Temporary file to ensure the code for DirectX device initialization stays
// encapsulated within molecular-renderer.

public class DirectXDevice {
  public let d3d12Device: SwiftCOM.ID3D12Device
  
  public init() {
    let factory: SwiftCOM.IDXGIFactory4 =
      try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
    
    let adapter = Self.createAdapter(factory: factory)
    
    let device: SwiftCOM.ID3D12Device =
      try! D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_12_1)
    
    self.d3d12Device = device
  }
}

// Utility functions called in the initializer.
extension DirectXDevice {
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
}

#endif
