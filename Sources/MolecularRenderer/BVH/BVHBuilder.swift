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
        atoms.atoms,
        atoms.motionVectors,
        atoms.addressOccupiedMarks,
        atoms.relativeOffsets1,
        atoms.relativeOffsets2,
        
        counters.general,
        
        voxels.group.atomsRemovedMarks,
        voxels.group.addedMarks,
        voxels.group.rebuiltMarks,
        voxels.group.occupiedMarks,
        
        voxels.dense.assignedSlotIDs,
        voxels.dense.atomsRemovedMarks,
        voxels.dense.rebuiltMarks,
        voxels.dense.atomicCounters,
        
        voxels.sparse.assignedVoxelIDs,
        voxels.sparse.atomsRemovedVoxelIDs,
        voxels.sparse.rebuiltVoxelIDs,
        voxels.sparse.vacantSlotIDs,
        voxels.sparse.memorySlots,
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
        clearedBuffer: voxels.sparse.assignedVoxelIDs,
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
      clearedBuffer: voxels.group.occupiedMarks,
      size: voxelGroupCount * 4)
    
    clearBuffer(
      commandList: commandList,
      clearValue: UInt32.max,
      clearedBuffer: voxels.sparse.atomsRemovedVoxelIDs,
      size: voxels.memorySlotCount * 4)
    clearBuffer(
      commandList: commandList,
      clearValue: UInt32.max,
      clearedBuffer: voxels.sparse.rebuiltVoxelIDs,
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
  
  // Upload the acceleration structure changes for every frame.
  func upload(
    transaction: Atoms.Transaction,
    commandList: CommandList,
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
      let buffer = atoms.transactionIDs.nativeBuffers[inFlightFrameID]
      #else
      let buffer = atoms.transactionIDs.inputBuffers[inFlightFrameID]
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
      let buffer = atoms.transactionAtoms.nativeBuffers[inFlightFrameID]
      #else
      let buffer = atoms.transactionAtoms.inputBuffers[inFlightFrameID]
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
    do {
      let idsCount = removedCount + movedCount + addedCount
      atoms.transactionIDs.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        range: 0..<(idsCount * 4))
      
      let atomsCount = movedCount + addedCount
      atoms.transactionAtoms.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID,
        range: 0..<(atomsCount * 16))
    }
    #endif
    
    // Set the transactionArgs.
    do {
      var transactionArgs = TransactionArgs()
      transactionArgs.removedCount = UInt32(removedCount)
      transactionArgs.movedCount = UInt32(movedCount)
      transactionArgs.addedCount = UInt32(addedCount)
      self.transactionArgs = transactionArgs
    }
  }
}
