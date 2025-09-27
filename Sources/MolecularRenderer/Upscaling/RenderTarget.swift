#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

struct RenderTargetDescriptor {
  var device: Device?
  var display: Display?
  var upscaleFactor: Float?
}

class RenderTarget {
  let upscaleFactor: Float
  
  #if os(macOS)
  var colorTextures: [MTLTexture] = []
  var depthTextures: [MTLTexture] = []
  var motionTextures: [MTLTexture] = []
  var upscaledTextures: [MTLTexture] = []
  #else
  var colorTextures: [SwiftCOM.ID3D12Resource] = []
  #endif
  
  init(descriptor: RenderTargetDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.upscaleFactor = upscaleFactor
    
    func createIntermediateSize() -> SIMD2<Int> {
      var output = display.frameBufferSize
      
      switch upscaleFactor {
      case 1:
        break
      case 2:
        output /= 2
      case 3:
        output /= 3
      default:
        fatalError("Invalid upscale factor.")
      }
      return output
    }
    let intermediateSize = createIntermediateSize()
    
    #if os(macOS)
    // Ensure the textures use lossless compression.
    device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      let commandEncoder: MTLBlitCommandEncoder =
      commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
      
      for _ in 0..<2 {
        let textureDesc = MTLTextureDescriptor()
        textureDesc.textureType = .type2D
        textureDesc.width = intermediateSize[0]
        textureDesc.height = intermediateSize[1]
        textureDesc.depth = 1
        textureDesc.mipmapLevelCount = 1
        textureDesc.sampleCount = 1
        textureDesc.arrayLength = 1
        textureDesc.storageMode = .private
        textureDesc.usage = [.shaderRead, .shaderWrite]
        textureDesc.compressionType = .lossless
        
        textureDesc.pixelFormat = .rgb10a2Unorm
        let colorTexture = device.mtlDevice.makeTexture(
          descriptor: textureDesc)!
        colorTextures.append(colorTexture)
        commandEncoder.optimizeContentsForGPUAccess(texture: colorTexture)
        
        guard upscaleFactor > 1 else {
          continue
        }
        
        textureDesc.pixelFormat = .r32Float
        let depthTexture = device.mtlDevice.makeTexture(
          descriptor: textureDesc)!
        depthTextures.append(depthTexture)
        commandEncoder.optimizeContentsForGPUAccess(texture: depthTexture)
        
        textureDesc.pixelFormat = .rg16Float
        let motionTexture = device.mtlDevice.makeTexture(
          descriptor: textureDesc)!
        motionTextures.append(motionTexture)
        commandEncoder.optimizeContentsForGPUAccess(texture: motionTexture)
        
        textureDesc.pixelFormat = .rgb10a2Unorm
        textureDesc.width = display.frameBufferSize[0]
        textureDesc.height = display.frameBufferSize[1]
        let upscaledTexture = device.mtlDevice.makeTexture(
          descriptor: textureDesc)!
        upscaledTextures.append(upscaledTexture)
        commandEncoder.optimizeContentsForGPUAccess(texture: upscaledTexture)
      }
      
      commandEncoder.endEncoding()
      commandList.mtlCommandEncoder =
      commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    }
    #else
    for _ in 0..<2 {
      var heapProperties = D3D12_HEAP_PROPERTIES()
      heapProperties.Type = D3D12_HEAP_TYPE_DEFAULT
      
      var resourceDesc = D3D12_RESOURCE_DESC()
      resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D
      resourceDesc.Alignment = 64 * 1024
      resourceDesc.Width = UInt64(display.frameBufferSize[0])
      resourceDesc.Height = UInt32(display.frameBufferSize[1])
      resourceDesc.DepthOrArraySize = UInt16(1)
      resourceDesc.MipLevels = UInt16(1)
      resourceDesc.SampleDesc.Count = 1
      resourceDesc.SampleDesc.Quality = 0
      resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN
      resourceDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
      
      resourceDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
      let colorTexture: SwiftCOM.ID3D12Resource =
      try! device.d3d12Device.CreateCommittedResource(
        heapProperties, // pHeapProperties
        D3D12_HEAP_FLAG_NONE, // HeapFlags
        resourceDesc, // pDesc
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, // InitialResourceState
        nil) // pOptimizedClearValue
      colorTextures.append(colorTexture)
    }
    #endif
  }
  
  #if os(Windows)
  // Takes an offset as an argument, then returns the offset after encoding.
  @discardableResult
  func encode(descriptorHeap: DescriptorHeap, offset: Int) -> Int {
    for i in 0..<2 {
      let colorHandleID = descriptorHeap.createUAV(
        resource: colorTextures[i],
        uavDesc: nil)
      guard colorHandleID == offset + i else {
        fatalError("This should never happen.")
      }
    }
    return offset + 2
  }
  #endif
}
