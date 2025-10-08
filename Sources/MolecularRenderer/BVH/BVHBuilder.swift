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
  let shaders: BVHShaders
  let atomResources: AtomResources
  let voxelResources: VoxelResources
  let counters: BVHCounters
  
  init(descriptor: BVHBuilderDescriptor) {
    guard let addressSpaceSize = descriptor.addressSpaceSize,
          let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    var bvhShadersDesc = BVHShadersDescriptor()
    bvhShadersDesc.device = device
    self.shaders = BVHShaders(descriptor: bvhShadersDesc)
    
    var atomResourcesDesc = AtomResourcesDescriptor()
    atomResourcesDesc.addressSpaceSize = addressSpaceSize
    atomResourcesDesc.device = device
    self.atomResources = AtomResources(descriptor: atomResourcesDesc)
    
    var voxelResourcesDesc = VoxelResourcesDescriptor()
    voxelResourcesDesc.device = device
    voxelResourcesDesc.voxelAllocationSize = voxelAllocationSize
    voxelResourcesDesc.worldDimension = worldDimension
    self.voxelResources = VoxelResources(descriptor: voxelResourcesDesc)
    
    var bvhCountersDesc = BVHCountersDescriptor()
    bvhCountersDesc.device = device
    self.counters = BVHCounters(descriptor: bvhCountersDesc)
    
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
    device.commandQueue.withCommandList { commandList in
      // Initialize the crash buffer to 1.
      do {
        let elementCount = counters.crashBuffer.inputBuffer.size / 4
        let data = [UInt32](repeating: 1, count: elementCount)
        counters.crashBuffer.initialize(
          commandList: commandList,
          data: data)
      }
      
      // Initialize the atomic counters to 0.
      let worldDimension = voxelResources.worldDimension
      let voxelCount = VoxelResources.voxelCount(
        worldDimension: worldDimension)
      clearBuffer(
        commandList: commandList,
        elementCount: voxelCount * (32 / 4),
        clearValue: 0,
        clearedBuffer: voxelResources.atomicCounters)
      
      // Initialize the memory slot IDs to UInt32.max.
      clearBuffer(
        commandList: commandList,
        elementCount: voxelCount,
        clearValue: UInt32.max,
        clearedBuffer: voxelResources.memorySlotIDs)
      
      // Initialize the assigned voxel IDs to UInt32.max.
      clearBuffer(
        commandList: commandList,
        elementCount: voxelResources.memorySlotCount,
        clearValue: UInt32.max,
        clearedBuffer: voxelResources.assignedVoxelIDs)
      
      #if os(Windows)
      computeUAVBarrier(commandList: commandList)
      #endif
    }
  }
  
  // Clear resources that should be reset every frame with ClearBuffer. When
  // new counters and bookkeeping buffers are added, include them here.
  func purgeResources(commandList: CommandList) {
    // Purge the voxel group marks to 0.
    let worldDimension = voxelResources.worldDimension
    let voxelGroupCount = VoxelResources.voxelGroupCount(
      worldDimension: worldDimension)
    clearBuffer(
      commandList: commandList,
      elementCount: voxelGroupCount,
      clearValue: 0,
      clearedBuffer: voxelResources.voxelGroupMarks)
    
    // Purge the vacant slot IDs to UInt32.max.
    clearBuffer(
      commandList: commandList,
      elementCount: voxelResources.memorySlotCount,
      clearValue: UInt32.max,
      clearedBuffer: voxelResources.vacantSlotIDs)
    
    #if os(Windows)
    computeUAVBarrier(commandList: commandList)
    #endif
  }
  
  // Upload the acceleration structure changes for every frame.
  func upload(
    transaction: Atoms.Transaction,
    device: Device,
    inFlightFrameID: Int
  ) {
    let removedCount = transaction.removedIDs.count
    let movedCount = transaction.movedIDs.count
    let addedCount = transaction.addedIDs.count
    
    // Validate the sizes of the transaction components.
    guard removedCount <= 1_000_000 else {
      fatalError("Removed atom count must not exceed 1 million.")
    }
    guard movedCount + addedCount <= 1_000_000 else {
      fatalError("Moved and added atom count must not exceed 1 million.")
    }
    guard transaction.movedPositions.count == movedCount,
          transaction.addedPositions.count == addedCount else {
      fatalError("This should never happen.")
    }
    
    // Write to the IDs buffer.
    do {
      #if os(macOS)
      let buffer = atomResources.transactionIDs.nativeBuffers[inFlightFrameID]
      #else
      let buffer = atomResources.transactionIDs.inputBuffers[inFlightFrameID]
      #endif
      
      transaction.removedIDs.withUnsafeBytes { bufferPointer in
        buffer.write(
          input: bufferPointer,
          offset: 0)
      }
      transaction.movedIDs.withUnsafeBytes { bufferPointer in
        buffer.write(
          input: bufferPointer,
          offset: removedCount * 4)
      }
      transaction.addedIDs.withUnsafeBytes { bufferPointer in
        buffer.write(
          input: bufferPointer,
          offset: (removedCount + movedCount) * 4)
      }
    }
    
    // Write to the atoms buffer.
    do {
      #if os(macOS)
      let buffer = atomResources.transactionAtoms.nativeBuffers[inFlightFrameID]
      #else
      let buffer = atomResources.transactionAtoms.inputBuffers[inFlightFrameID]
      #endif
      
      transaction.movedPositions.withUnsafeBytes { bufferPointer in
        buffer.write(
          input: bufferPointer,
          offset: 0)
      }
      transaction.addedPositions.withUnsafeBytes { bufferPointer in
        buffer.write(
          input: bufferPointer,
          offset: movedCount * 16)
      }
    }
    
    #if os(Windows)
    // Dispatch the GPU commands to copy the PCIe data.
    device.commandQueue.withCommandList { commandList in
      try! commandList.d3d12CommandList.EndQuery(
        counters.queryHeap, D3D12_QUERY_TYPE_TIMESTAMP, 0)
      
      atomResources.transactionIDs.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      atomResources.transactionAtoms.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      
      try! commandList.d3d12CommandList.EndQuery(
        counters.queryHeap, D3D12_QUERY_TYPE_TIMESTAMP, 1)
      try! commandList.d3d12CommandList.ResolveQueryData(
        counters.queryHeap,
        D3D12_QUERY_TYPE_TIMESTAMP,
        UInt32(0),
        UInt32(2),
        counters.queryDestinationBuffer.d3d12Resource,
        UInt64(0))
    }
    device.commandQueue.flush()
    
    var output = [UInt64](repeating: 0, count: 2)
    output.withUnsafeMutableBytes { bufferPointer in
      counters.queryDestinationBuffer.read(output: bufferPointer)
    }
    
    let frequency = try! device.commandQueue.d3d12CommandQueue
      .GetTimestampFrequency()
    let latency = Double(output[1] - output[0]) / Double(frequency)
    print(latency)
    #endif
  }
}
