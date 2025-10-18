#if os(Windows)
import SwiftCOM
import WinSDK
#endif

import QuartzCore

public struct ApplicationDescriptor {
  public var device: Device?
  public var display: Display?
  public var upscaleFactor: Float?
  
  public var addressSpaceSize: Int?
  public var voxelAllocationSize: Int?
  public var worldDimension: Float?
  
  public init() {
    
  }
}

public class Application {
  nonisolated(unsafe) static var singleton: Application?
  
  // Public API
  public let device: Device
  public let display: Display
  public let atoms: Atoms
  public var camera: Camera
  public var clock: Clock
  var runLoop: RunLoop?
  public internal(set) var frameID: Int = -1
  
  // Low-level display interfacing
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
  
  // Other resources
  let imageResources: ImageResources
  let bvhBuilder: BVHBuilder
  
  @MainActor
  public init(descriptor: ApplicationDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display,
          let upscaleFactor = descriptor.upscaleFactor,
          
          let addressSpaceSize = descriptor.addressSpaceSize,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Set up the public API.
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
    
    // Create the other resources.
    var imageResourcesDesc = ImageResourcesDescriptor()
    imageResourcesDesc.device = device
    imageResourcesDesc.display = display
    imageResourcesDesc.upscaleFactor = upscaleFactor
    imageResourcesDesc.worldDimension = worldDimension
    self.imageResources = ImageResources(descriptor: imageResourcesDesc)
    
    var bvhBuilderDesc = BVHBuilderDescriptor()
    bvhBuilderDesc.addressSpaceSize = atoms.addressSpaceSize
    bvhBuilderDesc.device = device
    bvhBuilderDesc.voxelAllocationSize = voxelAllocationSize
    bvhBuilderDesc.worldDimension = worldDimension
    self.bvhBuilder = BVHBuilder(descriptor: bvhBuilderDesc)
    
    #if os(Windows)
    // Bind resources to the descriptor heap.
    encodeDescriptorHeap()
    #endif
    
    #if os(macOS)
    // Fix an issue with massive startup latency for large allocations. Wait
    // for the latency period here, prior to application launch. Prevents a
    // gray screen from appearing for ~1 second and severely messing up
    // animations that rely on 'clock.frames'.
    //
    // It isn't perfect, but it reduces the disparity between frameID and
    // 'clock.frames' @ 16 GB from ~55 frames (0.6 seconds) to ~10 frames (0.15
    // seconds). At negligible allocation size, the minimum jump is 0.08
    // seconds and happens exactly between frameID = 4 and frameID = 5. There
    // is no way to make the disparity substantially smaller.
    //
    // | voxelAllocationSize | disp. before | disp. after | wait time here |
    // | ------------------: | -----------: | ----------: | -------------: |
    // |              0.2 GB |
    // |              0.5 GB |
    // |              1.0 GB |
    // |              2.0 GB |
    // |              4.0 GB |
    // |              8.0 GB |
    // |             12.0 GB |
    // |             16.0 GB |
    let start = CACurrentMediaTime()
    checkCrashBuffer(frameID: 0)
    checkExecutionTime(frameID: 0)
    updateBVH(inFlightFrameID: 0)
    forgetIdleState(inFlightFrameID: 0)
    device.commandQueue.flush()
    let end = CACurrentMediaTime()
    print("extra latency:", end - start)
    #endif
    
    guard Application.singleton == nil else {
      fatalError(
        "Can only create one instance of Application in a program run.")
    }
    Application.singleton = self
  }
  
  #if os(Windows)
  private func encodeDescriptorHeap() {
    imageResources.renderTarget.encode(
      descriptorHeap: descriptorHeap,
      offset: 0)
    
    bvhBuilder.atoms.encodeMotionVectors(
      descriptorHeap: descriptorHeap)
    bvhBuilder.atoms.encodeAddressOccupiedMarks(
      descriptorHeap: descriptorHeap)
    bvhBuilder.atoms.encodeRelativeOffsets(
      descriptorHeap: descriptorHeap)
    bvhBuilder.voxels.encodeMarks(
      descriptorHeap: descriptorHeap)
    bvhBuilder.voxels.encodeMemorySlots(
      descriptorHeap: descriptorHeap)
  }
  #endif
  
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
