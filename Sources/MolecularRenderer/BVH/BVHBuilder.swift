#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct BVHBuilderDescriptor {
  var addressSpaceSize: Int?
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Float?
}

class BVHBuilder {
  let shaders: BVHShaders
  let atoms: AtomResources
  let counters: CounterResources
  let voxels: VoxelResources
  
  var transactionArgs: TransactionArgs?
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var bvhShadersDesc = BVHShadersDescriptor()
    bvhShadersDesc.device = device
    bvhShadersDesc.worldDimension = worldDimension
    self.shaders = BVHShaders(descriptor: bvhShadersDesc)
    
    var atomResourcesDesc = AtomResourcesDescriptor()
    atomResourcesDesc.addressSpaceSize = addressSpaceSize
    atomResourcesDesc.device = device
    self.atoms = AtomResources(descriptor: atomResourcesDesc)
    
    var counterResourcesDesc = CounterResourcesDescriptor()
    counterResourcesDesc.device = device
    self.counters = CounterResources(descriptor: counterResourcesDesc)
    
    var voxelResourcesDesc = VoxelResourcesDescriptor()
    voxelResourcesDesc.device = device
    voxelResourcesDesc.voxelAllocationSize = voxelAllocationSize
    voxelResourcesDesc.worldDimension = worldDimension
    self.voxels = VoxelResources(descriptor: voxelResourcesDesc)
    
    // Remaining setup processes at program startup.
    initializeResources(device: device)
  }
  
  #if os(Windows)
  // Generic UAV barrier after every single kernel while building the
  // acceleration structure. Unless there is a clear reason to omit it, such
  // as clear buffer kernels writing to obviously distinct buffers.
  func computeUAVBarrier(commandList: CommandList) {
    // Specify the type of barrier.
    var barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    barrier.UAV.pResource = nil
    
    let barriers = [barrier]
    try! commandList.d3d12CommandList.ResourceBarrier(
      UInt32(barriers.count), barriers)
  }
  #endif
  
  func initializeResources(device: Device) {
    let voxelCount = VoxelResources.voxelCount(
      worldDimension: voxels.worldDimension)
    
    device.commandQueue.withCommandList { commandList in
      clearBuffer(
        commandList: commandList,
        clearValue: 0,
        clearedBuffer: atoms.addressOccupiedMarks,
        size: atoms.addressSpaceSize)
      
      clearBuffer(
        commandList: commandList,
        clearValue: UInt32.max,
        clearedBuffer: voxels.dense.assignedSlotIDs,
        size: voxelCount * 4)
      clearBuffer(
        commandList: commandList,
        clearValue: 0,
        clearedBuffer: voxels.dense.atomsRemovedMarks,
        size: voxelCount)
      clearBuffer(
        commandList: commandList,
        clearValue: 0,
        clearedBuffer: voxels.dense.rebuiltMarks,
        size: voxelCount)
      clearBuffer(
        commandList: commandList,
        clearValue: 0,
        clearedBuffer: voxels.dense.atomicCounters,
        size: voxelCount * 32)
      
      clearBuffer(
        commandList: commandList,
        clearValue: UInt32.max,
        clearedBuffer: voxels.sparse.assignedVoxelCoords,
        size: voxels.memorySlotCount * 4)
      
      // Initialize the crash buffer to 1.
      do {
        let elementCount = CounterResources.crashBufferSize / 4
        let data = [UInt32](repeating: 1, count: elementCount)
        counters.crashBuffer.initialize(
          commandList: commandList,
          data: data)
      }
      
      #if os(Windows)
      computeUAVBarrier(commandList: commandList)
      #endif
    }
  }
  
  // Clear resources that should be reset every frame with ClearBuffer.
  func purgeResources(commandList: CommandList) {
    let voxelGroupCount = VoxelResources.voxelGroupCount(
      worldDimension: voxels.worldDimension)
    
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: voxels.group.atomsRemovedMarks,
      size: voxelGroupCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: voxels.group.addedMarks,
      size: voxelGroupCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: voxels.group.rebuiltMarks,
      size: voxelGroupCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: voxels.group.occupiedMarks8,
      size: voxelGroupCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: 0,
      clearedBuffer: voxels.group.occupiedMarks32,
      size: (voxelGroupCount / 64) * 4)
    
    clearBuffer(
      commandList: commandList,
      clearValue: UInt32.max,
      clearedBuffer: voxels.sparse.atomsRemovedVoxelCoords,
      size: voxels.memorySlotCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: UInt32.max,
      clearedBuffer: voxels.sparse.rebuiltVoxelCoords,
      size: voxels.memorySlotCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: UInt32.max,
      clearedBuffer: voxels.sparse.vacantSlotIDs,
      size: voxels.memorySlotCount * 4)
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
}
