#if os(macOS)
import Metal

public struct GPUContextDescriptor {
  public var deviceID: Int?
  
  public init() {
    
  }
}

public class GPUContext {
  /// The GPU chosen for rendering at program startup.
  public let mtlDevice: MTLDevice
  
  /// The command queue that issues GPU commands.
  public let mtlCommandQueue: MTLCommandQueue
  
  public init(descriptor: GPUContextDescriptor) {
    guard let deviceID = descriptor.deviceID else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the device.
    let devices = MTLCopyAllDevices()
    guard deviceID >= 0,
          deviceID < devices.count else {
      fatalError("Device ID was out of range.")
    }
    self.device = devices[deviceID]
    
    // Create the command queue.
    self.commandQueue = device.makeCommandQueue()!
  }
}

extension GPUContext {
  /// The identifier for the GPU with the most processing power.
  public static var fastestDeviceID: Int {
    return 0
  }
}
#endif
