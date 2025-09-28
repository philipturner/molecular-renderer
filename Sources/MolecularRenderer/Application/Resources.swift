struct ResourcesDescriptor {
  var device: Device?
  var renderTarget: RenderTarget?
}

// A temporary measure to organize the large number of resources
// formerly in 'main.swift'.
class Resources {
  let renderShader: Shader
  let upscaleShader: Shader
  
  #if os(Windows)
  let descriptorHeap: DescriptorHeap
  #endif
  var atomBuffer: RingBuffer
  var transactionTracker: TransactionTracker
  
  var cameraArgsBuffer: RingBuffer
  var previousCameraArgs: CameraArgs?
  
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
    
    #if os(Windows)
    // Create the descriptor heap.
    var descriptorHeapDesc = DescriptorHeapDescriptor()
    descriptorHeapDesc.device = device
    descriptorHeapDesc.count = renderTarget.descriptorCount
    self.descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
    
    renderTarget.encode(
      descriptorHeap: descriptorHeap, offset: 0)
    #endif
    
    self.atomBuffer = RingBuffer(
      device: device,
      byteCount: 1000 * 16)
    self.transactionTracker = TransactionTracker(
      atomCount: 1000)
    
    self.cameraArgsBuffer = RingBuffer(
      device: device,
      byteCount: MemoryLayout<CameraArgs>.stride * 2)
    self.previousCameraArgs = nil
  }
}
