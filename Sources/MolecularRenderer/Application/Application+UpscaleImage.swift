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
  let iid = SwiftCOM.ID3D12Resource.IID
  
  // Fetch the underlying pointer without worrying about memory leaks.
  let interface = try! d3d12Resource.QueryInterface(iid: iid)
  _ = try! d3d12Resource.Release()
  guard let interface else {
    fatalError("This should never happen.")
  }
  
  // Cannot invoke ffxApiGetResourceDX12 from Clang header import.
  var output = FfxApiResource()
  output.resource = interface
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
#endif

extension Application {
  private func fallbackUpscale() {
    device.commandQueue.withCommandList { commandList in
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.upscaleShader) {
        // Bind the textures.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        let upscaledTexture = renderTarget.upscaledTextures[frameID % 2]
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
          let groupSize = SIMD2<Int>(8, 8)
          
          var groupCount = display.frameBufferSize
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
    jitterOffsetDesc.upscaleFactor = renderTarget.upscaleFactor
    
    return JitterOffset.create(descriptor: jitterOffsetDesc)
  }
  
  public func upscale(image: Image) -> Image {
    guard renderTarget.upscaleFactor > 1 else {
      fatalError("Upscaling is not allowed.")
    }
    guard image.scaleFactor == 1 else {
      fatalError("Received image with incorrect scale factor.")
    }
    guard let upscaler else {
      fatalError("Upscaler was not present.")
    }
    let colorTexture = renderTarget.colorTextures[frameID % 2]
    let depthTexture = renderTarget.depthTextures[frameID % 2]
    let motionTexture = renderTarget.motionTextures[frameID % 2]
    let upscaledTexture = renderTarget.upscaledTextures[frameID % 2]
    
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
    // Test createFFXResource on the four resources and print to console,
    // confirming that they were created.
    let color = createFFXResource(colorTexture)
    let depth = createFFXResource(depthTexture)
    let motion = createFFXResource(motionTexture)
    let upscaled = createFFXResource(upscaledTexture)
    
    print()
    print(color)
    print(depth)
    print(motion)
    print(upscaled)
    
    fallbackUpscale()
    #endif
    
    var output = Image()
    output.scaleFactor = renderTarget.upscaleFactor
    return output
  }
}
