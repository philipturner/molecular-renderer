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
  
  // /// A structure describing a resource.
  // ///
  // /// @ingroup SDKTypes
  // struct FfxApiResourceDescription
  // {
  //     uint32_t     type;      ///< The type of the resource.
  //     uint32_t     format;    ///< The surface format.
  //     union {
  //         uint32_t width;     ///< The width of the texture resource.
  //         uint32_t size;      ///< The size of the buffer resource.
  //     };

  //     union {
  //         uint32_t height;    ///< The height of the texture resource.
  //         uint32_t stride;    ///< The stride of the buffer resource.
  //     };

  //     union {
  //         uint32_t depth;     ///< The depth of the texture resource.
  //         uint32_t alignment; ///< The alignment of the buffer resource.
  //     };

  //     uint32_t     mipCount;  ///< Number of mips (or 0 for full mipchain).
  //     uint32_t     flags;     ///< A set of resource flags.
  //     uint32_t     usage;     ///< Resource usage flags.
  // };
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
  // Fallback for debugging if the upscaler goes wrong, or for easily
  // visualizing the 3 inputs to the upscaler.
  private func fallbackUpscale() {
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(imageResources.upscaleShader) {
        // Bind the textures.
        #if os(macOS)
        let colorTexture = imageResources.renderTarget
          .colorTextures[frameID % 2]
        let upscaledTexture = imageResources.renderTarget
          .upscaledTextures[frameID % 2]
        commandList.mtlCommandEncoder
          .setTexture(colorTexture, index: 0)
        commandList.mtlCommandEncoder
          .setTexture(upscaledTexture, index: 1)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: 0)
        commandList.setDescriptor(
          handleID: 6 + frameID % 2, index: 1)
        #endif
        
        // Determine the dispatch grid size.
        func createGroupCount32() -> SIMD3<UInt32> {
          var groupCount = display.frameBufferSize
          
          let groupSize = SIMD2<Int>(8, 8)
          groupCount &+= groupSize &- 1
          groupCount /= groupSize
          
          return SIMD3<UInt32>(
            UInt32(groupCount[0]),
            UInt32(groupCount[1]),
            UInt32(1))
        }
        commandList.dispatch(groups: createGroupCount32())
      }
    }
  }
  
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
    }
    #else
    device.commandQueue.withCommandList { commandList in
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
    }
    #endif
    
    var output = Image()
    output.scaleFactor = imageResources.renderTarget.upscaleFactor
    return output
  }
}
