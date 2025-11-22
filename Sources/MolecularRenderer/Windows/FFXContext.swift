#if os(Windows)
import FidelityFX
import SwiftCOM
import WinSDK

struct FFXContextDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
}

class FFXContext {
  private let pContext: UnsafeMutablePointer<ffxContext?>
  
  init(descriptor: FFXContextDescriptor) {
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
    createContext.value.flags |= UInt32(
      FFX_UPSCALE_ENABLE_DEPTH_INFINITE.rawValue)
    createContext.value.flags |= UInt32(
      FFX_UPSCALE_ENABLE_DEBUG_CHECKING.rawValue)
    createContext.value.flags |= UInt32(
      FFX_UPSCALE_ENABLE_DEBUG_VISUALIZATION.rawValue)
    
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
    }
    
    // Allocate the CreateBackendDX12Desc.
    let createBackend = FFXDescriptor<ffxCreateBackendDX12Desc>()
    createBackend.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12
    
    // Set the ID3D12Device.
    func createID3D12Device() -> UnsafeMutablePointer<WinSDK.ID3D12Device> {
      let d3d12Device = device.d3d12Device
      let iid = SwiftCOM.ID3D12Device.IID
      
      // Fetch the underlying pointer without worrying about memory leaks.
      let interface = try! d3d12Device.QueryInterface(iid: iid)
      _ = try! d3d12Device.Release()
      
      guard let interface else {
        fatalError("This should never happen.")
      }
      return interface.assumingMemoryBound(to: WinSDK.ID3D12Device.self)
    }
    createBackend.value.device = createID3D12Device()
    
    // Build the linked list.
    createContext.pNext = createBackend.pHeader
    createBackend.pNext = nil
    
    // Create the context.
    do {
      let error = ffxCreateContext(
        pContext, // context
        createContext.pHeader, // desc
        nil) // memCb
      guard error == 0 else {
        fatalError("Encountered error code \(error).")
      }
    }
    
    withExtendedLifetime(createContext) { }
    withExtendedLifetime(createBackend) { }
  }
  
  deinit {
    let error = ffxDestroyContext(
      pContext, // context
      nil) // memCb
    guard error == 0 else {
      fatalError("Encountered error code \(error).")
    }
    
    pContext.deallocate()
  }
  
  func configure<T>(descriptor: FFXDescriptor<T>) {
    let error = ffxConfigure(
      pContext, // context
      descriptor.pHeader) // desc
    guard error == 0 else {
      fatalError("Encountered error code \(error).")
    }
  }
  
  func query<T>(descriptor: FFXDescriptor<T>) {
    let error = ffxQuery(
      pContext, // context
      descriptor.pHeader) // desc
    guard error == 0 else {
      fatalError("Encountered error code \(error).")
    }
  }
  
  func dispatch<T>(descriptor: FFXDescriptor<T>) {
    let error = ffxDispatch(
      pContext, // context
      descriptor.pHeader) // desc
    guard error == 0 else {
      fatalError("Encountered error code \(error).")
    }
  }
  
  static func query<T>(descriptor: FFXDescriptor<T>) {
    let error = ffxQuery(
      nil, // context
      descriptor.pHeader) // desc
    guard error == 0 else {
      fatalError("Encountered error code \(error).")
    }
  }
}
#endif
