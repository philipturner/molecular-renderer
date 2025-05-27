#if os(Windows)
import FidelityFX
import SwiftCOM
import WinSDK

public struct UpscalerDescriptor {
  public var device: Device?
  
  public init() {
    
  }
}

public class Upscaler {
  let d3d12Device: SwiftCOM.ID3D12Device
  
  public init(descriptor: UpscalerDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    self.d3d12Device = device.d3d12Device
  }
  
  public func createContext() -> ffxContext {
    // Set the backend header.
    let createBackend = UnsafeMutablePointer<ffxCreateBackendDX12Desc>
      .allocate(capacity: 1)
    createBackend.pointee.header.type = UInt64(
      FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12)
    createBackend.pointee.header.pNext = nil
    
    do {
      // Retrieve the DirectX device.
      //
      // I did not balance this with a call to `IUnknown::Release`, so something
      // bad is probably going to happen eventually. I would like to wait until
      // after the `ffxContext` is created. Otherwise, semantically, the
      // device could be deallocated before reaching that function.
      //
      // Probably best solved with a deinitializer, once this code matures.
      let iid = SwiftCOM.ID3D12Device.IID
      let interface = try! d3d12Device.QueryInterface(iid: iid)
      let device = interface!.assumingMemoryBound(to: WinSDK.ID3D12Device.self)
      createBackend.pointee.device = device
    }
    
    // Set the upscale header.
    let createUpscale = UnsafeMutablePointer<ffxCreateContextDescUpscale>
      .allocate(capacity: 1)
    createUpscale.pointee.header.type = UInt64(
      FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE)
    createBackend.withMemoryRebound(
      to: ffxApiHeader.self, capacity: 1
    ) { pointer in
      createUpscale.pointee.header.pNext = pointer
    }
    
    do {
      // Invert the depth, but keep the range at [1, 0]. This is for compatibility
      // with the Metal implementation, which uses 'isDepthReversed = true'.
      createUpscale.pointee.flags =
      UInt32(FFX_UPSCALE_ENABLE_DEPTH_INVERTED.rawValue)
      
      // Set the input dimensions as 480x480.
      let rayTracedTextureSize: Int = 480
      var rayTracedDimensions = FfxApiDimensions2D()
      rayTracedDimensions.width = UInt32(rayTracedTextureSize)
      rayTracedDimensions.height = UInt32(rayTracedTextureSize)
      createUpscale.pointee.maxRenderSize = rayTracedDimensions
      
      // Set the output dimensions as 1440x1440.
      let upscaledSize: Int = 1440
      var upscaledDimensions = FfxApiDimensions2D()
      upscaledDimensions.width = UInt32(upscaledSize)
      upscaledDimensions.height = UInt32(upscaledSize)
      createUpscale.pointee.maxUpscaleSize = upscaledDimensions
    }
    
    // Set the callback to crash on all warnings.
    createUpscale.pointee.fpMessage = { type, message in
      print("[FidelityFX] Encountered message of type \(type).")

      if let message {
        let string = String(decodingCString: message, as: UTF16.self)
        print("[FidelityFX] \(string)")
      } else {
        print("[FidelityFX] Message was a null pointer.")
      }
      fatalError()
    }

    // Create the FFX object context.
    var upscaleContext: ffxContext? = nil
    createUpscale.withMemoryRebound(
      to: ffxApiHeader.self, capacity: 1
    ) { pointer in
      let error = ffxCreateContext(
        &upscaleContext, pointer, nil)
      guard error == 0 else {
        fatalError("Failed to create context. Received error code \(error).")
      }
    }
    guard let upscaleContext else {
      fatalError("Could not create context.")
    }
    return upscaleContext
  }
}

#endif
