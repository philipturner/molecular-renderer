struct ResourcesDescriptor {
  var device: Device?
  var renderTarget: RenderTarget?
}

// A temporary measure to organize the large number of resources
// formerly in 'main.swift'.
public class Resources {
  public let shader: Shader
  #if os(Windows)
  public let descriptorHeap: DescriptorHeap
  #endif
  public var atomBuffer: AtomBuffer
  public var transactionTracker: TransactionTracker
  
  init(descriptor: ResourcesDescriptor) {
    guard let device = descriptor.device,
          let renderTarget = descriptor.renderTarget else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create the shader.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "renderImage"
    shaderDesc.source = RenderImage.createSource()
    #if os(macOS)
    shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
    #endif
    self.shader = Shader(descriptor: shaderDesc)
    
    #if os(Windows)
    // Create the descriptor heap.
    var descriptorHeapDesc = DescriptorHeapDescriptor()
    descriptorHeapDesc.device = device
    descriptorHeapDesc.count = renderTarget.descriptorCount
    self.descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
    
    renderTarget.encode(
      descriptorHeap: descriptorHeap, offset: 0)
    #endif
    
    self.atomBuffer = AtomBuffer(
      device: device,
      atomCount: 1000)
    self.transactionTracker = TransactionTracker(
      atomCount: 1000)
  }
}
