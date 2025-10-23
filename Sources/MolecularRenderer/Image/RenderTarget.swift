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
  typealias Texture = MTLTexture
  #else
  typealias Texture = SwiftCOM.ID3D12Resource
  #endif
  
  // In offline mode, these arrays should have length zero.
  var colorTextures: [Texture] = []
  var depthTextures: [Texture] = []
  var motionTextures: [Texture] = []
  var upscaledTextures: [Texture] = []
  
  // In offline mode, create a single native buffer and (on Windows) a single
  // output buffer. Every call to 'application.render()' spawns a new Swift
  // array containing a copy of the pixels as SIMD4<Float16>.
  
  init(descriptor: RenderTargetDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.upscaleFactor = upscaleFactor
    
    let intermediateSize = self.intermediateSize(display: display)
    
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
      resourceDesc.Width = UInt64(intermediateSize[0])
      resourceDesc.Height = UInt32(intermediateSize[1])
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
      
      guard upscaleFactor > 1 else {
        continue
      }
      
      resourceDesc.Format = DXGI_FORMAT_R32_FLOAT
      let depthTexture: SwiftCOM.ID3D12Resource =
      try! device.d3d12Device.CreateCommittedResource(
        heapProperties, // pHeapProperties
        D3D12_HEAP_FLAG_NONE, // HeapFlags
        resourceDesc, // pDesc
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, // InitialResourceState
        nil) // pOptimizedClearValue
      depthTextures.append(depthTexture)
      
      resourceDesc.Format = DXGI_FORMAT_R16G16_FLOAT
      let motionTexture: SwiftCOM.ID3D12Resource =
      try! device.d3d12Device.CreateCommittedResource(
        heapProperties, // pHeapProperties
        D3D12_HEAP_FLAG_NONE, // HeapFlags
        resourceDesc, // pDesc
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, // InitialResourceState
        nil) // pOptimizedClearValue
      motionTextures.append(motionTexture)
      
      resourceDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
      resourceDesc.Width = UInt64(display.frameBufferSize[0])
      resourceDesc.Height = UInt32(display.frameBufferSize[1])
      let upscaledTexture: SwiftCOM.ID3D12Resource =
      try! device.d3d12Device.CreateCommittedResource(
        heapProperties, // pHeapProperties
        D3D12_HEAP_FLAG_NONE, // HeapFlags
        resourceDesc, // pDesc
        D3D12_RESOURCE_STATE_UNORDERED_ACCESS, // InitialResourceState
        nil) // pOptimizedClearValue
      upscaledTextures.append(upscaledTexture)
    }
    #endif
  }
  
  func intermediateSize(display: Display) -> SIMD2<Int> {
    var output = display.frameBufferSize
    guard output[0] % Int(upscaleFactor) == 0,
          output[1] % Int(upscaleFactor) == 0 else {
      fatalError("Frame buffer size was not divisible by upscale factor.")
    }
    
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
  
  #if os(Windows)
  func encode(descriptorHeap: DescriptorHeap, offset: Int) {
    for i in 0..<2 {
      let colorHandleID = descriptorHeap.createUAV(
        resource: colorTextures[i],
        uavDesc: nil)
      guard colorHandleID == offset + i else {
        fatalError("This should never happen.")
      }
    }
    
    guard upscaleFactor > 1 else {
      return
    }
    
    for i in 0..<2 {
      let depthHandleID = descriptorHeap.createUAV(
        resource: depthTextures[i],
        uavDesc: nil)
      guard depthHandleID == offset + 2 + i else {
        fatalError("This should never happen.")
      }
    }
    
    for i in 0..<2 {
      let motionHandleID = descriptorHeap.createUAV(
        resource: motionTextures[i],
        uavDesc: nil)
      guard motionHandleID == offset + 4 + i else {
        fatalError("This should never happen.")
      }
    }
    
    for i in 0..<2 {
      let upscaledHandleID = descriptorHeap.createUAV(
        resource: upscaledTextures[i],
        uavDesc: nil)
      guard upscaledHandleID == offset + 6 + i else {
        fatalError("This should never happen.")
      }
    }
  }
  
  var descriptorCount: Int {
    if upscaleFactor == 1 {
      return 2
    } else {
      return 8
    }
  }
  #endif
}
