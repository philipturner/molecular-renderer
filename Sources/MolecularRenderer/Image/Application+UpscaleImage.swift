#if os(Windows)
import FidelityFX
import SwiftCOM
import WinSDK
#endif

#if os(Windows)
private func createFFXSurfaceFormat(
  _ format: DXGI_FORMAT
) -> FfxApiSurfaceFormat {
  switch format {
  case DXGI_FORMAT_R10G10B10A2_UNORM:
    return FFX_API_SURFACE_FORMAT_R10G10B10A2_UNORM
  case DXGI_FORMAT_R32_FLOAT:
    return FFX_API_SURFACE_FORMAT_R32_FLOAT
  case DXGI_FORMAT_R16G16_FLOAT:
    return FFX_API_SURFACE_FORMAT_R16G16_FLOAT
  default:
    fatalError("Unrecognized DXGI format.")
  }
}

// Utility for binding DirectX resources.
private func createFFXResource(
  _ d3d12Resource: SwiftCOM.ID3D12Resource
) -> FfxApiResource {
  func createID3D12Resource() -> UnsafeMutableRawPointer {
    let iid = SwiftCOM.ID3D12Resource.IID
    
    // Fetch the underlying pointer without worrying about memory leaks.
    let interface = try! d3d12Resource.QueryInterface(iid: iid)
    _ = try! d3d12Resource.Release()
    
    guard let interface else {
      fatalError("This should never happen.")
    }
    return interface
  }
  
  // Cannot invoke ffxApiGetResourceDX12 from Clang header import.
  var output = FfxApiResource()
  output.resource = createID3D12Resource()
  output.state = UInt32(FFX_API_RESOURCE_STATE_UNORDERED_ACCESS.rawValue)
  
  let desc = try! d3d12Resource.GetDesc()
  output.description.flags = UInt32(
    FFX_API_RESOURCE_FLAGS_NONE.rawValue)
  output.description.usage = UInt32(
    FFX_API_RESOURCE_USAGE_READ_ONLY.rawValue)
  output.description.usage |= UInt32(
    FFX_API_RESOURCE_USAGE_UAV.rawValue)
  
  output.description.width = UInt32(desc.Width)
  output.description.height = UInt32(desc.Height)
  output.description.depth = UInt32(desc.DepthOrArraySize)
  output.description.mipCount = UInt32(desc.MipLevels)
  output.description.type = UInt32(
    FFX_API_RESOURCE_TYPE_TEXTURE2D.rawValue)
  
  let ffxSurfaceFormat = createFFXSurfaceFormat(desc.Format)
  output.description.format = UInt32(ffxSurfaceFormat.rawValue)
  
  return output
}

private func createEmptyFFXResource() -> FfxApiResource {
  var output = FfxApiResource()
  output.resource = nil
  output.state = 0
  output.description.type = 0
  output.description.format = 0
  output.description.width = 0
  output.description.height = 0
  output.description.depth = 0
  output.description.mipCount = 0
  output.description.flags = 0
  output.description.usage = 0
  return output
}

private func createFFXFloatCoords(
  _ input: SIMD2<Float>
) -> FfxApiFloatCoords2D {
  var output = FfxApiFloatCoords2D()
  output.x = input[0]
  output.y = input[0]
  return output
}

private func createFFXDimensions(
  _ input: SIMD2<Int>
) -> FfxApiDimensions2D {
  var output = FfxApiDimensions2D()
  output.width = UInt32(input[0])
  output.height = UInt32(input[1])
  return output
}
#endif

extension Application {
  private func createJitterOffset() -> SIMD2<Float> {
    var jitterOffsetDesc = JitterOffsetDescriptor()
    jitterOffsetDesc.index = frameID
    jitterOffsetDesc.upscaleFactor = imageResources.renderTarget.upscaleFactor
    
    return JitterOffset.create(descriptor: jitterOffsetDesc)
  }
  
  public func upscale(image: Image) -> Image {
    guard imageResources.renderTarget.upscaleFactor > 1 else {
      fatalError("Upscaling is not allowed.")
    }
    guard image.scaleFactor == 1 else {
      fatalError("Received image with incorrect scale factor.")
    }
    guard let upscaler = imageResources.upscaler else {
      fatalError("Upscaler was not present.")
    }
    let colorTexture = imageResources.renderTarget
      .colorTextures[frameID % 2]
    let depthTexture = imageResources.renderTarget
      .depthTextures[frameID % 2]
    let motionTexture = imageResources.renderTarget
      .motionTextures[frameID % 2]
    let upscaledTexture = imageResources.renderTarget
      .upscaledTextures[frameID % 2]
    
    #if os(macOS)
    if frameID == 0 {
      upscaler.scaler.reset = true
    } else {
      upscaler.scaler.reset = false
    }
    
    upscaler.scaler.colorTexture = colorTexture
    upscaler.scaler.depthTexture = depthTexture
    upscaler.scaler.motionTexture = motionTexture
    upscaler.scaler.outputTexture = upscaledTexture
    
    let jitterOffset = createJitterOffset()
    upscaler.scaler.jitterOffsetX = -jitterOffset[0]
    upscaler.scaler.jitterOffsetY = -jitterOffset[1]
    
    device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      
      upscaler.scaler.encode(commandBuffer: commandList.mtlCommandBuffer)
      
      commandList.mtlCommandEncoder =
      commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
      
      nonisolated(unsafe)
      let selfReference = self
      let inFlightFrameID = frameID % 3
      commandList.mtlCommandBuffer.addCompletedHandler { commandBuffer in
        selfReference.bvhBuilder.counters.queue.sync {
          var executionTime = commandBuffer.gpuEndTime
          executionTime -= commandBuffer.gpuStartTime
          let latencyMicroseconds = Int(executionTime * 1e6)
          selfReference.bvhBuilder.counters
            .upscaleLatencies[inFlightFrameID] = latencyMicroseconds
        }
      }
    }
    #else
    device.commandQueue.withCommandList { commandList in
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        6)
      
      func createID3D12CommandList() -> UnsafeMutableRawPointer {
        let d3d12CommandList = commandList.d3d12CommandList
        let iid = SwiftCOM.ID3D12GraphicsCommandList.IID
        
        // Fetch the underlying pointer without worrying about memory leaks.
        let interface = try! d3d12CommandList.QueryInterface(iid: iid)
        _ = try! d3d12CommandList.Release()
        
        guard let interface else {
          fatalError("This should never happen.")
        }
        return interface
      }
      
      let dispatch = FFXDescriptor<ffxDispatchDescUpscale>()
      dispatch.type = FFX_API_DISPATCH_DESC_TYPE_UPSCALE
      dispatch.value.commandList = createID3D12CommandList()
      
      dispatch.value.color = createFFXResource(colorTexture)
      dispatch.value.depth = createFFXResource(depthTexture)
      dispatch.value.motionVectors = createFFXResource(motionTexture)
      dispatch.value.exposure = createEmptyFFXResource()
      dispatch.value.reactive = createEmptyFFXResource()
      dispatch.value.transparencyAndComposition = createEmptyFFXResource()
      dispatch.value.output = createFFXResource(upscaledTexture)
      
      // It takes some effort to investigate, but we are indeed getting better
      // results from jitterOffset * -1 than jitterOffset.
      let jitterOffset = createJitterOffset()
      let motionVectorScale = SIMD2<Float>(1, 1)
      dispatch.value.jitterOffset = createFFXFloatCoords(jitterOffset * -1)
      dispatch.value.motionVectorScale = createFFXFloatCoords(motionVectorScale)
      
      let upscaleFactor = imageResources.renderTarget.upscaleFactor
      let renderSize = display.frameBufferSize / Int(upscaleFactor)
      let upscaleSize = display.frameBufferSize
      dispatch.value.renderSize = createFFXDimensions(renderSize)
      dispatch.value.upscaleSize = createFFXDimensions(upscaleSize)
      
      // Could not detect a major quality improvement with sharpening enabled.
      dispatch.value.enableSharpening = false
      dispatch.value.sharpness = 0
      dispatch.value.frameTimeDelta = 2 // this doesn't do anything
      dispatch.value.preExposure = 1
      
      if frameID == 0 {
        dispatch.value.reset = true
      } else {
        dispatch.value.reset = false
      }
      
      dispatch.value.cameraNear = Float.greatestFiniteMagnitude
      dispatch.value.cameraFar = 0.075 // 75 pm, circumvents debug warning
      dispatch.value.cameraFovAngleVertical = camera.fovAngleVertical
      dispatch.value.viewSpaceToMetersFactor = 1
      dispatch.value.flags = 0
      
      // Encode the GPU commands for upscaling.
      upscaler.ffxContext.dispatch(descriptor: dispatch)
      
      try! commandList.d3d12CommandList.EndQuery(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        7)
      
      let destinationBuffer = bvhBuilder.counters
        .queryDestinationBuffers[frameID % 3]
      try! commandList.d3d12CommandList.ResolveQueryData(
        bvhBuilder.counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        6,
        2,
        destinationBuffer.d3d12Resource,
        48)
    }
    #endif
    
    var output = Image()
    output.scaleFactor = imageResources.renderTarget.upscaleFactor
    return output
  }
}
