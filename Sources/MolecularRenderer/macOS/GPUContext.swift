#if os(macOS)
import Metal

public struct GPUContextDescriptor {
  public var deviceID: Int?
  
  public init() {
    
  }
}

// This should probably be changed to 'struct'. However, the entire data type
// will be removed once we split it into common 'CommandQueue' and 'Device'.
public class GPUContext {
  /// The GPU chosen for rendering at program startup.
  public private(set) var device: MTLDevice
  
  /// The command queue that issues GPU commands.
  public private(set) var commandQueue: MTLCommandQueue
  
  public init(descriptor: GPUContextDescriptor) {
    guard let deviceID = descriptor.deviceID else {
      fatalError("Descriptor was incomplete.")
    }
    self.device = GPUContext.device(deviceID: deviceID)
    self.commandQueue = device.makeCommandQueue()!
  }
}

extension GPUContext {
  static func device(deviceID: Int) -> MTLDevice {
    let devices = MTLCopyAllDevices()
    guard deviceID >= 0,
          deviceID < devices.count else {
      fatalError("GPU ID was out of range.")
    }
    return devices[deviceID]
  }
  
  /// The identifier for the GPU with the most processing power.
  public static var fastestDeviceID: Int {
    return 0
  }
}
#endif
