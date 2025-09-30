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
    
    // ANECompilerService
    //
    // ## 2x Upscaling, 1920x1440
    //
    // first time | second time
    // ---------- | -----------
    // 9.480      | 0.258
    // 9.016      | 0.262
    // 8.253      | 0.261
    //
    // ## 2x Upscaling, 1080x1080
    //
    // first time | second time
    // ---------- | -----------
    // 0.767      | 0.239
    // 0.709      | 0.237
    // 0.747      | 0.237
    //
    // ## 3x Upscaling, 1920x1440
    //
    // first time | second time
    // ---------- | -----------
    // 0.728      | 0.237
    // 0.718      | 0.237
    // 0.681      | 0.237
    //
    // ## 3x Upscaling, 1080x1080
    //
    // first time | second time
    // ---------- | -----------
    // 0.585      | 0.225
    // 0.592      | 0.229
    // 0.601      | 0.227
    
    let start = CACurrentMediaTime()
    let scaler = temporalScalerDesc.makeTemporalScaler(
      device: device.mtlDevice)
    let end = CACurrentMediaTime()
    print("time delay:", String(format: "%.3f", end - start))
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
