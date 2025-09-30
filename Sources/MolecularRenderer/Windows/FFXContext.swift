#if os(Windows)
import FidelityFX
import SwiftCOM
import WinSDK

public struct FFXContextDescriptor {
  public var device: Device?
  public var display: Display?
  public var upscaleFactor: Float?
  
  public init() {
    
  }
}

public class FFXContext {
  private let pContext: UnsafeMutablePointer<ffxContext>
  
  public init(descriptor: FFXContextDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.pContext = .allocate(capacity: 1)
    
    // TODO: ffxCreateContext
    fatalError("Not implemented.")
  }
  
  // TODO: ffxDestroyContext in deinit
  deinit {
    pContext.deallocate()
  }
  
  // TODO: Implement ffxQuery, ffxConfigure, ffxDispatch
}
#endif
