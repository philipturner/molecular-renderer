#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct ResourcesDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var renderTarget: RenderTarget?
}

// A temporary measure to organize the large number of resources
// formerly in 'main.swift'.
class Resources {
  let renderShader: Shader
  let upscaleShader: Shader
  
  var atomsBuffer: RingBuffer
  var motionVectorsBuffer: RingBuffer
  var transactionTracker: TransactionTracker
  
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
  #if os(Windows)
  let motionVectorsBaseHandleID: Int
  let descriptorHeap: DescriptorHeap
  #endif
  
  init(descriptor: ResourcesDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let renderTarget = descriptor.renderTarget else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the shaders.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    #endif
    
    shaderDesc.source = RenderShader.createSource(
      upscaleFactor: renderTarget.upscaleFactor)
    shaderDesc.name = "render"
    self.renderShader = Shader(descriptor: shaderDesc)
    
    shaderDesc.source = UpscaleShader.createSource(
      upscaleFactor: renderTarget.upscaleFactor)
    shaderDesc.name = "upscale"
    self.upscaleShader = Shader(descriptor: shaderDesc)
    
    self.atomsBuffer = Self.createAtomsBuffer(
      device: device,
      addressSpaceSize: addressSpaceSize)
    self.motionVectorsBuffer = Self.createMotionVectorsBuffer(
      device: device,
      addressSpaceSize: addressSpaceSize)
    self.transactionTracker = TransactionTracker(
      atomCount: addressSpaceSize)
    
    self.cameraArgsBuffer = Self.createCameraArgsBuffer(device: device)
    self.previousCameraArgs = nil
    
    #if os(Windows)
    // Prefix sum the offset of each descriptor.
    self.motionVectorsBaseHandleID = renderTarget.descriptorCount
    let descriptorCount = motionVectorsBaseHandleID + 3
    
    // Create the descriptor heap.
    var descriptorHeapDesc = DescriptorHeapDescriptor()
    descriptorHeapDesc.device = device
    descriptorHeapDesc.count = descriptorCount
    self.descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
    
    // Encode the render target.
    renderTarget.encode(
      descriptorHeap: descriptorHeap,
      offset: 0)
    
    // Encode the motion vectors.
    Self.encode(
      motionVectorsBuffer: motionVectorsBuffer,
      addressSpaceSize: addressSpaceSize,
      descriptorHeap: descriptorHeap,
      offset: motionVectorsBaseHandleID)
    #endif
  }
  
  private static func createAtomsBuffer(
    device: Device,
    addressSpaceSize: Int
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = addressSpaceSize * 16
    return RingBuffer(descriptor: ringBufferDesc)
  }
  
  private static func createMotionVectorsBuffer(
    device: Device,
    addressSpaceSize: Int
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = addressSpaceSize * 8
    return RingBuffer(descriptor: ringBufferDesc)
  }
  
  private static func createCameraArgsBuffer(
    device: Device
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .constant
    ringBufferDesc.device = device
    ringBufferDesc.size = MemoryLayout<CameraArgs>.stride * 2
    return RingBuffer(descriptor: ringBufferDesc)
  }
  
  #if os(Windows)
  private static func encode(
    motionVectorsBuffer: RingBuffer,
    addressSpaceSize: Int,
    descriptorHeap: DescriptorHeap,
    offset: Int
  ) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    for i in 0..<3 {
      let nativeBuffer = motionVectorsBuffer.nativeBuffers[i]
      let handleID = descriptorHeap.createUAV(
        resource: nativeBuffer.d3d12Resource,
        uavDesc: uavDesc)
      guard handleID == offset + i else {
        fatalError("This should never happen.")
      }
    }
  }
  #endif
}
