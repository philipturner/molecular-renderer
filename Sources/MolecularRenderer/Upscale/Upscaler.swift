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
    //
    //
    // ## 2x Upscaling, 1920x1920
    //
    // first time | second time
    // ---------- | -----------
    // 12.843     | 0.277
    // 12.846     | 0.274
    // 12.697     | 0.270
    //
    // ## 2x Upscaling, 1800x1800
    //
    // first time | second time
    // ---------- | -----------
    // 10.894     | 0.270
    // 12.234     | 0.267
    // 12.013     | 0.271
    //
    // ## 2x Upscaling, 1620x1620
    //
    // first time | second time
    // ---------- | -----------
    // 1.539      | 0.260
    // 2.722      | 0.259
    // 1.415      | 0.261
    //
    // ## 2x Upscaling, 1440x1440
    //
    // first time | second time
    // ---------- | -----------
    // 2.065      | 0.251
    // 2.129      | 0.251
    // 2.034      | 0.251
    //
    // ## 2x Upscaling, 1200x1200
    //
    // first time | second time
    // ---------- | -----------
    // 1.544      | 0.241
    // 1.199      | 0.241
    // 1.581      | 0.242
    //
    // ## 2x Upscaling, 1080x1080
    //
    // first time | second time
    // ---------- | -----------
    // 0.767      | 0.239
    // 0.709      | 0.237
    // 0.747      | 0.237
    //
    //
    //
    // ## 3x Upscaling, 1920x1920
    //
    // first time | second time
    // ---------- | -----------
    // 1.658      | 0.243
    // 1.746      | 0.243
    // 1.148      | 0.243
    //
    // ## 3x Upscaling, 1800x1800
    //
    // first time | second time
    // ---------- | -----------
    // 1.436      | 0.242
    // 1.641      | 0.241
    // 1.928      | 0.242
    //
    // ## 3x Upscaling, 1620x1620
    //
    // first time | second time
    // ---------- | -----------
    // 0.736      | 0.239
    // 0.757      | 0.238
    // 0.731      | 0.237
    //
    // ## 3x Upscaling, 1440x1440
    //
    // first time | second time
    // ---------- | -----------
    // 0.696      | 0.234
    // 0.701      | 0.243
    // 0.776      | 0.228
    //
    // ## 3x Upscaling, 1200x1200
    //
    // first time | second time
    // ---------- | -----------
    // 0.632      | 0.233
    // 0.641      | 0.231
    // 0.619      | 0.233
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
