#if os(Windows)
import SwiftCOM
import WinSDK
#endif

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
  
  public let device: Device
  public let display: Display
  
  public let atoms: Atoms
  public var camera: Camera
  public var clock: Clock
  let window: Window
  #if os(macOS)
  let view: View
  #else
  let swapChain: SwapChain
  #endif
  let renderTarget: RenderTarget
  let resources: Resources
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
    self.window = Window(display: display)
    #if os(macOS)
    self.view = View(display: display)
    
    // This assignment is the reason the code must be within a @MainActor
    // scope on macOS.
    window.view = view
    #else
    // Create the swap chain.
    var swapChainDesc = SwapChainDescriptor()
    swapChainDesc.device = device
    swapChainDesc.display = display
    swapChainDesc.window = window
    self.swapChain = SwapChain(descriptor: swapChainDesc)
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
