#if os(Windows)
import SwiftCOM
import WinSDK
#endif

import func Foundation.exit // temporary, for development of BVH

public struct ApplicationDescriptor {
  public var addressSpaceSize: Int?
  public var voxelAllocationSize: Int?
  public var worldDimension: Int?
  
  public var device: Device?
  public var display: Display?
  public var upscaleFactor: Float?
  
  public init() {
    
  }
}

public class Application {
  nonisolated(unsafe) static var singleton: Application?
  
  // Public API.
  public let device: Device
  public let display: Display
  public let atoms: Atoms
  public var camera: Camera
  public var clock: Clock
  
  // Low-level display interfacing.
  let window: Window
  #if os(macOS)
  let view: View
  #else
  let swapChain: SwapChain
  #endif
  
  // Single descriptor heap that encapsulates all weirdly formatted resources.
  #if os(Windows)
  let descriptorHeap: DescriptorHeap
  #endif
  
  // TODO: Migrate RenderTarget into ImageResources
  let renderTarget: RenderTarget
  let resources: Resources
  
  // TODO: Migrate upscaler into ImageResources
  let upscaler: Upscaler?
  
  var runLoop: RunLoop?
  public internal(set) var frameID: Int = -1
  
  @MainActor
  public init(descriptor: ApplicationDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension,
          
          let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }
    self.device = device
    self.display = display
    self.atoms = Atoms(addressSpaceSize: addressSpaceSize)
    self.camera = Camera()
    self.clock = Clock(display: display)
    
    // Set up the resources for low-level display interfacing.
    self.window = Window(display: display)
    #if os(macOS)
    self.view = View(display: display)
    window.view = view
    #else
    var swapChainDesc = SwapChainDescriptor()
    swapChainDesc.device = device
    swapChainDesc.display = display
    swapChainDesc.window = window
    self.swapChain = SwapChain(descriptor: swapChainDesc)
    #endif
    
    #if os(Windows)
    // Create the descriptor heap.
    var descriptorHeapDesc = DescriptorHeapDescriptor()
    descriptorHeapDesc.device = device
    descriptorHeapDesc.count = 64
    self.descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
    #endif
    
    // Create the render target.
    var renderTargetDesc = RenderTargetDescriptor()
    renderTargetDesc.device = device
    renderTargetDesc.display = display
    renderTargetDesc.upscaleFactor = upscaleFactor
    self.renderTarget = RenderTarget(descriptor: renderTargetDesc)
    
    // Create the resources container.
    var resourcesDesc = ResourcesDescriptor()
    resourcesDesc.device = device
    resourcesDesc.renderTarget = renderTarget
    self.resources = Resources(descriptor: resourcesDesc)
    
    // Create the upscaler.
    if upscaleFactor > 1 {
      var upscalerDesc = UpscalerDescriptor()
      upscalerDesc.device = device
      upscalerDesc.display = display
      upscalerDesc.upscaleFactor = upscaleFactor
      self.upscaler = Upscaler(descriptor: upscalerDesc)
    } else {
      self.upscaler = nil
    }
    
    guard Application.singleton == nil else {
      fatalError(
        "Can only create one instance of Application in a program run.")
    }
    Application.singleton = self
    
    print("Exiting the program.")
    exit(0)
  }
  
  @MainActor
  public func run(
    _ closure: @escaping () -> Void
  ) {
    var runLoopDesc = RunLoopDescriptor()
    runLoopDesc.closure = closure
    #if os(macOS)
    runLoopDesc.display = display
    #endif
    let runLoop = RunLoop(descriptor: runLoopDesc)
    
    guard self.runLoop == nil else {
      fatalError("Can only run an application one time.")
    }
    self.runLoop = runLoop
    
    runLoop.start(window: window)
    runLoop.stop()
  }
}
