#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct BVHBuilderDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Int?
}

class BVHBuilder {
  let atomResources: AtomResources
  let voxelResources: VoxelResources
  
  // Small counters and bookkeeping
  let crashBuffer: CrashBuffer // initialize at startup
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var atomResourcesDesc = AtomResourcesDescriptor()
    atomResourcesDesc.addressSpaceSize = addressSpaceSize
    atomResourcesDesc.device = device
    self.atomResources = AtomResources(descriptor: atomResourcesDesc)
    
    var voxelResourcesDesc = VoxelResourcesDescriptor()
    voxelResourcesDesc.device = device
    voxelResourcesDesc.voxelAllocationSize = voxelAllocationSize
    voxelResourcesDesc.worldDimension = worldDimension
    self.voxelResources = VoxelResources(descriptor: voxelResourcesDesc)
    
    var crashBufferDesc = CrashBufferDescriptor()
    crashBufferDesc.device = device
    crashBufferDesc.size = 4096
    self.crashBuffer = CrashBuffer(descriptor: crashBufferDesc)
    
    #if os(Windows)
    // Move all UAV resources to the UAV state.
    setUAVState(device: device)
    #endif
    
    // Remaining setup processes at program startup.
    initializeResources(device: device)
  }
  
  #if os(Windows)
  func setUAVState(device: Device) {
    device.commandQueue.withCommandList { commandList in
      let buffers: [Buffer] = [
        atomResources.atoms,
        atomResources.motionVectors,
        atomResources.relativeOffsets1,
        atomResources.relativeOffsets2,
        voxelResources.voxelGroupMarks,
        voxelResources.atomicCounters,
        voxelResources.memorySlotIDs,
        voxelResources.assignedVoxelIDs,
        voxelResources.vacantSlotIDs,
        voxelResources.memorySlots
      ]
      
      var barriers: [D3D12_RESOURCE_BARRIER] = []
      for buffer in buffers {
        let barrier = buffer
          .transition(state: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
        barriers.append(barrier)
      }
      try! commandList.d3d12CommandList.ResourceBarrier(
        UInt32(barriers.count), barriers)
    }
  }
  #endif
  
  func initializeResources(device: Device) {
    // Initialize the crash buffer to 1.
    device.commandQueue.withCommandList { commandList in
      let elementCount = crashBuffer.inputBuffer.size / 4
      let data = [UInt32](repeating: 1, count: elementCount)
      crashBuffer.initialize(
        commandList: commandList,
        data: data)
    }
  }
}
