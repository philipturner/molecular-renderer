#if os(macOS)
import MetalFX
#endif

struct UpscalerDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
}

class Upscaler {
  #if os(macOS)
  let scaler: MTLFXTemporalScaler
  #else
  let ffxContext: FFXContext
  #endif
  
  init(descriptor: UpscalerDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    
    #if os(macOS)
    let renderSize = display.frameBufferSize / Int(upscaleFactor)
    let upscaleSize = display.frameBufferSize
    
    let temporalScalerDesc = MTLFXTemporalScalerDescriptor()
    temporalScalerDesc.inputWidth = renderSize[0]
    temporalScalerDesc.inputHeight = renderSize[1]
    temporalScalerDesc.outputWidth = upscaleSize[0]
    temporalScalerDesc.outputHeight = upscaleSize[1]
    
    temporalScalerDesc.colorTextureFormat = .rgb10a2Unorm
    temporalScalerDesc.depthTextureFormat = .r32Float
    temporalScalerDesc.motionTextureFormat = .rg16Float
    temporalScalerDesc.outputTextureFormat = .rgb10a2Unorm
    
    temporalScalerDesc.isAutoExposureEnabled = false
    temporalScalerDesc.isInputContentPropertiesEnabled = false
    temporalScalerDesc.inputContentMinScale = upscaleFactor
    temporalScalerDesc.inputContentMaxScale = upscaleFactor
    
    // Location of the massive delay from ANECompilerService, which can
    // exceed 10 seconds for large textures. The delay happens whenever the
    // Swift code recompiles from even the slightest change.
    let scaler = temporalScalerDesc.makeTemporalScaler(
      device: device.mtlDevice)
    guard let scaler else {
      fatalError("The temporal scaler effect is not usable!")
    }
    self.scaler = scaler
    
    // We already store motion vectors in units of pixels. The default value
    // multiplies the vector by 'intermediateSize', which we don't want.
    scaler.motionVectorScaleX = 1
    scaler.motionVectorScaleY = 1
    scaler.isDepthReversed = true
    #else
    var ffxContextDesc = FFXContextDescriptor()
    ffxContextDesc.device = device
    ffxContextDesc.display = display
    ffxContextDesc.upscaleFactor = upscaleFactor
    self.ffxContext = FFXContext(descriptor: ffxContextDesc)
    #endif
  }
  
  // TODO: Expose a method to the public API, where the upscaler can be reset
  // by something other than frameID being 0.
  //
  // This may have some relation to the reactive mask texture, where the
  // accumulation history for certain pixels should reset after certain abrupt
  // changes (solve the ghosting problem with FidelityFX).
}
