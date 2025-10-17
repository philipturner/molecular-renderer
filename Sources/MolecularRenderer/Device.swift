#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct DeviceDescriptor {
  /// The identifier for the device.
  public var deviceID: Int?
  
  public init() {
    
  }
}

public class Device {
  // Stored properties for the device.
  #if os(macOS)
  let mtlDevice: MTLDevice
  #else
  let dxgiAdapter: SwiftCOM.IDXGIAdapter4
  let d3d12Device: SwiftCOM.ID3D12Device
  
  // This option can double the CPU-side command encoding latency.
  private static var enableDebug: Bool { true }
  
  // Stored properties for the debug layer.
  var d3d12Debug: SwiftCOM.ID3D12Debug?
  var d3d12InfoQueue: SwiftCOM.ID3D12InfoQueue?
  var dxgiInfoQueue: SwiftCOM.IDXGIInfoQueue?
  #endif
  
  // Stored properties for the command queue.
  private var _commandQueue: CommandQueue!
  var commandQueue: CommandQueue {
    self._commandQueue
  }
  
  public init(descriptor: DeviceDescriptor) {
    guard let deviceID = descriptor.deviceID else {
      fatalError("Descriptor was incomplete.")
    }
    
    // The debug layer must be turned on before any DirectX resources are
    // initialized.
    #if os(Windows)
    if Self.enableDebug {
      self.d3d12Debug = try! D3D12GetDebugInterface()
      try! d3d12Debug!.EnableDebugLayer()
    }
    #endif
    
    // Create the device (macOS).
    #if os(macOS)
    let devices = MTLCopyAllDevices()
    guard deviceID == 0,
          devices.count == 1 else {
      fatalError("Apple silicon should have only one GPU.")
    }
    self.mtlDevice = devices[deviceID]
    #endif
    
    // Create the device (Windows).
    #if os(Windows)
    let adapters = Self.createAdapters()
    guard deviceID >= 0,
          deviceID < adapters.count else {
      fatalError("Device ID was out of range.")
    }
    self.dxgiAdapter = adapters[deviceID]
    self.d3d12Device = try! D3D12CreateDevice(
      dxgiAdapter, D3D_FEATURE_LEVEL_12_1)
    #endif
    
    
    #if os(Windows)
    if Self.enableDebug {
      self.d3d12InfoQueue = Self.createInfoQueue(device: d3d12Device)
      try! d3d12InfoQueue!.SetBreakOnSeverity(
        D3D12_MESSAGE_SEVERITY_ERROR, true)
      
      self.dxgiInfoQueue = try! DXGIGetDebugInterface1(0)
      try! dxgiInfoQueue!.SetBreakOnSeverity(
        DXGI_DEBUG_DXGI, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true)
    }
    #endif
    
    // Create the command queue.
    self._commandQueue = CommandQueue(device: self)
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
  
  #if os(Windows)
  // List the available adapters.
  static func createAdapters() -> [SwiftCOM.IDXGIAdapter4] {
    // Create the factory.
    func factoryFlags() -> UInt32 {
      if Device.enableDebug {
        return UInt32(DXGI_CREATE_FACTORY_DEBUG)
      } else {
        return UInt32(0)
      }
    }
    let factory: SwiftCOM.IDXGIFactory4 =
    try! CreateDXGIFactory2(factoryFlags())
    
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
