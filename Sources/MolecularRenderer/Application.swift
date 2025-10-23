#if os(Windows)
import SwiftCOM
import WinSDK
#endif

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
  var window: Window?
  #if os(macOS)
  var view: View?
  #else
  var swapChain: SwapChain?
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
    
    // Check this early to avoid propagation of undefined behavior into shader
    // codegen and other parts that rely on the upscale factor.
    if display.isOffline {
      guard upscaleFactor == 1 else {
        fatalError("Offline rendering cannot use upscaling.")
      }
    }
    
    // Set up the public API.
    self.device = device
    self.display = display
    self.atoms = Atoms(addressSpaceSize: addressSpaceSize)
    self.camera = Camera()
    self.clock = Clock(display: display)
    
    if !display.isOffline {
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
    }
    
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
    // seconds and happens exactly between frameID = 4 and frameID = 5.
    //
    // The disparity is clock.frames - frameID, meaning clock.frames has jumped
    // forward several dozen frames in time. The jump is a sudden jitter around
    // frameID = 4.
    //
    // These statistics were recorded at 1440x1440 resolution, M1 Max, 3x
    // upscaling enabled. Perhaps the exact latencies depend on these factors.
    //
    // | voxelAllocationSize | disp. before | disp. after | wait time here |
    // | ------------------: | -----------: | ----------: | -------------: |
    // |              0.2 GB |       125 ms |       83 ms |          43 ms |
    // |              0.5 GB |       133 ms |       83 ms |          50 ms |
    // |              1.0 GB |       158 ms |       83 ms |          73 ms |
    // |              2.0 GB |       175 ms |       83 ms |         104 ms |
    // |              4.0 GB |       275 ms |       83 ms |         183 ms |
    // |              8.0 GB |       450 ms |       83 ms |         323 ms |
    // |             12.0 GB |       583 ms |       83 ms |         477 ms |
    // |             16.0 GB |       766 ms |       83 ms |         677 ms |
    // |             18.0 GB |       842 ms |       83 ms |         705 ms |
    //
    // _Improvements to the 'clock.frames' jitter after implementing the queue
    // flush here._
    //
    // There is also an incredible lag (stutter lasting ~0.5 s) when the
    // application closes. It only kicks in when the memory allocation reaches
    // ~15.7 GB. This is with an older scheme before the allocation was broken
    // into 3 parts. The exact tipping point may change with the new scheme.
    // - Sometimes happens at 14 GB, although the probability is ~10%.
    // - Probability at 16 GB is perhaps 75%.
    //
    // # After refactoring the memory scheme to break the 17.2 GB barrier
    //
    // 16.0 GB - stutter after application exit probably seen 33% of the time
    // - occasionally see weird state where the application is nonresponsive
    //   after closing window
    // 18.9 GB - second massive series of stutters after startup
    // 19.1 GB - second series grows to 1 second, 120 FPS attained at t = ~2 s
    // 19.3 GB - stutters grow to several seconds, 120 FPS @ t = ~5 s
    // - nonresponsive closing sequence is the norm
    //
    // MTLDevice.maxBufferSize = 17.2 GB                (16 * 1024^3)
    // MTLDevice.recommendedMaxWorkingSetSize = 22.9 GB (21 * 1024^3)
    // hw.memsize: 34359738368                          (32 * 1024^3)
    checkCrashBuffer(frameID: 0)
    checkExecutionTime(frameID: 0)
    updateBVH(inFlightFrameID: 0)
    forgetIdleState(inFlightFrameID: 0)
    device.commandQueue.flush()
    #endif
    
    guard Application.singleton == nil else {
      fatalError(
        "Can only create one instance of Application in a program run.")
    }
    Application.singleton = self
  }
  
  #if os(Windows)
  private func encodeDescriptorHeap() {
    imageResources.renderTarget.encodeResources(
      descriptorHeap: descriptorHeap)
    
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
    guard let window else {
      fatalError("Cannot invoke run loop for offline rendering.")
    }
    
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
