#if os(macOS)
import MetalFX
import QuartzCore

struct UpscalerDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
}

class Upscaler {
  let scaler: MTLFXTemporalScaler
  
  init(descriptor: UpscalerDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
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
  }
  
  // TODO: Expose a method to the public API, where the upscaler can be reset
  // by something other than frameID being 0.
}
#endif
