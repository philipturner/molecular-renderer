#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct DeviceDescriptor {
  public var deviceID: Int?
  
  public init() {
    
  }
}

public class Device {
  // Stored properties for the device.
  #if os(macOS)
  public let mtlDevice: MTLDevice
  #else
  let d3d12Debug: SwiftCOM.ID3D12Debug
  public let d3d12Device: SwiftCOM.ID3D12Device
  public let d3d12InfoQueue: SwiftCOM.ID3D12InfoQueue
  public let dxgiInfoQueue: SwiftCOM.IDXGIInfoQueue
  #endif
  
  // Stored properties for the command queue.
  
  
  #if os(macOS)
  // We shouldn't need this to be public if there's a utility for creating
  // command buffers.
  public let mtlCommandQueue: MTLCommandQueue
  #else
  let commandQueue: CommandQueue
  
  // We shouldn't need this if the utility library encapsulates the swap chain.
  public var d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue {
    commandQueue.d3d12CommandQueue
  }
  #endif
  
  public init(descriptor: DeviceDescriptor) {
    guard let deviceID = descriptor.deviceID else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the debug layer.
    #if os(Windows)
    self.d3d12Debug = try! D3D12GetDebugInterface()
    try! d3d12Debug.EnableDebugLayer()
    #endif
    
    // Create the device.
    #if os(macOS)
    let adapters = MTLCopyAllDevices()
    #else
    let adapters = Self.createAdapters()
    #endif
    guard deviceID >= 0,
          deviceID < adapters.count else {
      fatalError("Device ID was out of range.")
    }
    #if os(macOS)
    self.mtlDevice = adapters[deviceID]
    #else
    self.d3d12Device = try! D3D12CreateDevice(
      adapters[deviceID], D3D_FEATURE_LEVEL_12_1)
    #endif
    
    // Create the info queue.
    #if os(Windows)
    self.d3d12InfoQueue = Self
      .createInfoQueue(device: d3d12Device)
    try! d3d12InfoQueue.SetBreakOnSeverity(
      D3D12_MESSAGE_SEVERITY_ERROR, true)
    
    // Create the DXGI info queue.
    self.dxgiInfoQueue = try! DXGIGetDebugInterface1(0)
    try! dxgiInfoQueue.SetBreakOnSeverity(
      DXGI_DEBUG_DXGI, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true)
    #endif
    
    // Create the command queue.
    #if os(macOS)
    self.mtlCommandQueue = mtlDevice.makeCommandQueue()!
    #else
    self.commandQueue = CommandQueue(d3d12Device: d3d12Device)
    #endif
  }
}

extension Device {
  /// The identifier for the GPU with the most processing power.
  public static var fastestDeviceID: Int {
    #if os(macOS)
    return 0
    #else
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
    #endif
  }
  
  // List the available adapters.
  #if os(Windows)
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
  
  // Create an info queue from the 'ID3D12Device'.
  static func createInfoQueue(
    device: SwiftCOM.ID3D12Device
  ) -> SwiftCOM.ID3D12InfoQueue {
    let iid = SwiftCOM.ID3D12InfoQueue.IID
    let interface = try! device.QueryInterface(iid: iid)
    let infoQueue = SwiftCOM.ID3D12InfoQueue(pUnk: interface)
    return infoQueue
  }
  #endif
}
