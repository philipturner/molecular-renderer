struct ResourcesDescriptor {
  var device: Device?
  var renderTarget: RenderTarget?
}

// A temporary measure to organize the large number of resources
// formerly in 'main.swift'.
class Resources {
  let renderShader: Shader
  let upscaleShader: Shader
  
  var atomBuffer: RingBuffer
  var atomMotionVectorsBuffer: RingBuffer
  var transactionTracker: TransactionTracker
  
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
  #if os(Windows)
  let descriptorHeap: DescriptorHeap
  let atomMotionVectorsBaseHandleID: Int
  #endif
  
  init(descriptor: ResourcesDescriptor) {
    guard let device = descriptor.device,
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
    
    self.atomBuffer = Self.createAtomBuffer(device: device)
    self.atomMotionVectorsBuffer = Self
      .createAtomMotionVectorsBuffer(device: device)
    self.transactionTracker = TransactionTracker(atomCount: 1000)
    
    self.cameraArgsBuffer = Self.createCameraArgsBuffer(device: device)
    self.previousCameraArgs = nil
    
    #if os(Windows)
    // Create the descriptor heap.
    var descriptorHeapDesc = DescriptorHeapDescriptor()
    descriptorHeapDesc.device = device
    descriptorHeapDesc.count = renderTarget.descriptorCount
    self.descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
    
    renderTarget.encode(
      descriptorHeap: descriptorHeap, offset: 0)
    self.atomMotionVectorsBaseHandleID = renderTarget.descriptorCount
    
    Self.encode(
      atomMotionVectorsBuffer: atomMotionVectorsBuffer,
      descriptorHeap: descriptorHeap,
      offset: atomMotionVectorsBaseHandleID)
    #endif
  }
  
  private static func createAtomBuffer(
    device: Device
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = 1000 * 16
    return RingBuffer(descriptor: ringBufferDesc)
  }
  
  private static func createAtomMotionVectorsBuffer(
    device: Device
  ) -> RingBuffer {
    var ringBufferDesc = RingBufferDescriptor()
    ringBufferDesc.accessLevel = .device
    ringBufferDesc.device = device
    ringBufferDesc.size = 1000 * 16 // TODO: Change to 1000 * 8
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
  
  private static func encode(
    atomMotionVectorsBuffer: RingBuffer,
    descriptorHeap: DescriptorHeap,
    offset: Int
  ) {
    
  }
}
