#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct RenderTargetDescriptor {
  public var device: Device?
  public var display: Display?
  
  public init() {
    
  }
}

public class RenderTarget {
  // This number cycles through the range 0..<2. RunLoop manages it.
  public internal(set) var currentBufferIndex: Int = 0
  
  #if os(macOS)
  public internal(set) var colorTextures: [MTLTexture] = []
  #else
  public internal(set) var colorTextures: [SwiftCOM.ID3D12Resource] = []
  #endif
  
  public init(descriptor: RenderTargetDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    
    #if os(macOS)
    // Ensure the textures use lossless compression.
    device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      let commandEncoder: MTLBlitCommandEncoder =
      commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
      
      for _ in 0..<2 {
        let textureDesc = MTLTextureDescriptor()
        textureDesc.textureType = .type2D
        textureDesc.width = display.frameBufferSize[0]
        textureDesc.height = display.frameBufferSize[1]
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
}

/*
 // Ensure the textures use lossless compression.
 let commandBuffer = commandQueue.makeCommandBuffer()!
 let encoder = commandBuffer.makeBlitCommandEncoder()!
 
 // Initialize each texture twice, establishing a double buffer.
 for _ in 0..<2 {
   let desc = MTLTextureDescriptor()
   desc.storageMode = .private
   desc.usage = [ .shaderWrite, .shaderRead ]
   
   desc.width = argumentContainer.rayTracedTextureSize
   desc.height = argumentContainer.rayTracedTextureSize
   desc.pixelFormat = .rgb10a2Unorm
   let color = device.makeTexture(descriptor: desc)!
   
   desc.pixelFormat = .r32Float
   let depth = device.makeTexture(descriptor: desc)!
   
   desc.pixelFormat = .rg16Float
   let motion = device.makeTexture(descriptor: desc)!
   
   desc.pixelFormat = .rgb10a2Unorm
   desc.width = argumentContainer.upscaledSize
   desc.height = argumentContainer.upscaledSize
   let upscaled = device.makeTexture(descriptor: desc)!
   
   let textures = IntermediateTextures(
     color: color, depth: depth, motion: motion, upscaled: upscaled)
   bufferedIntermediateTextures.append(textures)
   
   for texture in [color, depth, motion, upscaled] {
     encoder.optimizeContentsForGPUAccess(texture: texture)
   }
 }
 encoder.endEncoding()
 commandBuffer.commit()
 
 var resourceDesc = D3D12_RESOURCE_DESC()
 resourceDesc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D
 resourceDesc.Alignment = 64 * 1024
 resourceDesc.Width = UInt64(display.frameBufferSize[0])
 resourceDesc.Height = UInt32(display.frameBufferSize[1])
 resourceDesc.DepthOrArraySize = UInt16(1)
 resourceDesc.MipLevels = UInt16(1)
 resourceDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
 resourceDesc.SampleDesc.Count = 1
 resourceDesc.SampleDesc.Quality = 0
 resourceDesc.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN
 resourceDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
 */
