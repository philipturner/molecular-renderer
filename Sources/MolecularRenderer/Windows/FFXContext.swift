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
    
    // Allocate the CreateContextDescUpscale.
    let createContext = FFXDescriptor<ffxCreateContextDescUpscale>()
    createContext.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE
    createContext.value.flags = UInt32(
      FFX_UPSCALE_ENABLE_DEPTH_INVERTED.rawValue)
    
    // Set the texture dimensions.
    func createFFXDimensions(
      _ input: SIMD2<Int>
    ) -> FfxApiDimensions2D {
      var output = FfxApiDimensions2D()
      output.width = UInt32(input[0])
      output.height = UInt32(input[1])
      return output
    }
    do {
      let renderSize = display.frameBufferSize / Int(upscaleFactor)
      let upscaleSize = display.frameBufferSize
      createContext.value.maxRenderSize = createFFXDimensions(renderSize)
      createContext.value.maxUpscaleSize = createFFXDimensions(upscaleSize)
    }
    
     // Set the callback to crash on all warnings.
    createContext.value.fpMessage = { type, message in
      print("[FidelityFX] Encountered message of type \(type).")

      if let message {
        let string = String(decodingCString: message, as: UTF16.self)
        print("[FidelityFX] \(string)")
      } else {
        print("[FidelityFX] Message was a null pointer.")
      }
      fatalError()
    }
    
    // TODO: ffxCreateContext
    fatalError("Not implemented.")
    
    // withExtendedLifetime(all descriptors)
  }
  
  // TODO: ffxDestroyContext in deinit
  deinit {
    pContext.deallocate()
  }
  
  // TODO: Implement ffxQuery, ffxConfigure, ffxDispatch
}
#endif
