#if os(Windows)
import SwiftCOM
import WinSDK
#endif

struct VoxelResourcesDescriptor {
  var device: Device?
  var voxelAllocationSize: Int?
  var worldDimension: Float?
}

class VoxelResources {
  let worldDimension: Float
  let memorySlotCount: Int
  
  let group: GroupVoxelResources
  let dense: DenseVoxelResources
  let sparse: SparseVoxelResources
  
  init(descriptor: VoxelResourcesDescriptor) {
    guard let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Initialize the world dimension.
    guard worldDimension.remainder(dividingBy: 8) == 0 else {
      fatalError("World dimension was not divisible by 8.")
    }
    guard worldDimension > 0 else {
      fatalError("World dimension was zero.")
    }
    self.worldDimension = worldDimension
    
    // Initialize the memory slot count.
    let memorySlotCount = Self.memorySlotCount(
      voxelAllocationSize: voxelAllocationSize)
    guard memorySlotCount > 0 else {
      fatalError("Memory slot count was zero.")
    }
    self.memorySlotCount = memorySlotCount
    
    // Initialize the resources.
    let voxelGroupCount = Self.voxelGroupCount(worldDimension: worldDimension)
    let voxelCount = Self.voxelCount(worldDimension: worldDimension)
    self.group = GroupVoxelResources(
      device: device, voxelGroupCount: voxelGroupCount)
    self.dense = DenseVoxelResources(
      device: device, voxelCount: voxelCount)
    self.sparse = SparseVoxelResources(
      device: device, memorySlotCount: memorySlotCount)
  }
  
  static func voxelGroupCount(worldDimension: Float) -> Int {
    var output: Int = 1
    for _ in 0..<3 {
      output *= Int(worldDimension / 8)
    }
    return output
  }
  
  static func voxelCount(worldDimension: Float) -> Int {
    var output: Int = 1
    for _ in 0..<3 {
      output *= Int(worldDimension / 2)
    }
    return output
  }
  
  static func memorySlotCount(voxelAllocationSize: Int) -> Int {
    return voxelAllocationSize / MemorySlot.totalSize
  }
  
  // Shader code to generate a voxel address.
  static func generate(
    _ input: String,
    _ gridDimension: Float
  ) -> String {
    let gridWidthSq = Int(gridDimension * gridDimension)
    let gridWidth = Int(gridDimension)
    return "\(input).z * \(gridWidthSq) + \(input).y * \(gridWidth) + \(input).x"
  }
}

class GroupVoxelResources {
  // purge to 0 before every frame
  let atomsRemovedMarks: Buffer
  let rebuiltMarks: Buffer
  let addedMarks: Buffer
  let occupiedMarks: Buffer
  
  init(device: Device, voxelGroupCount: Int) {
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.atomsRemovedMarks = createBuffer(size: voxelGroupCount * 4)
    self.rebuiltMarks = createBuffer(size: voxelGroupCount * 4)
    self.addedMarks = createBuffer(size: voxelGroupCount * 4)
    self.occupiedMarks = createBuffer(size: voxelGroupCount * 4)
  }
}

class DenseVoxelResources {
  // initialize to UInt32.max with shader
  let assignedSlotIDs: Buffer
  
  // initialize to 0 with shader
  // purge to 0 with idle/active
  let atomsRemovedMarks: Buffer
  let rebuiltMarks: Buffer
  let atomicCounters: Buffer
  
  #if os(Windows)
  var atomsRemovedMarksHandleID: Int = -1
  var rebuiltMarksHandleID: Int = -1
  #endif
  
  init(device: Device, voxelCount: Int) {
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.assignedSlotIDs = createBuffer(size: voxelCount * 4)
    self.atomsRemovedMarks = createBuffer(size: voxelCount)
    self.rebuiltMarks = createBuffer(size: voxelCount)
    self.atomicCounters = createBuffer(size: voxelCount * 32)
  }
}

class SparseVoxelResources {
  // initialize to UInt32.max with shader
  let assignedVoxelIDs: Buffer
  
  // purge to UInt32.max before every frame
  let atomsRemovedVoxelIDs: Buffer
  let rebuiltVoxelIDs: Buffer
  let vacantSlotIDs: Buffer
  
  let memorySlots: Buffer
  #if os(Windows)
  var memorySlotsHandleID: Int = -1
  #endif
  
  init(device: Device, memorySlotCount: Int) {
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.assignedVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.atomsRemovedVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.rebuiltVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.vacantSlotIDs = createBuffer(size: memorySlotCount * 4)
    self.memorySlots = createBuffer(
      size: memorySlotCount * MemorySlot.totalSize)
  }
}

#if os(Windows)
extension VoxelResources {
  func encodeMarks(descriptorHeap: DescriptorHeap) {
    let voxelCount = Self.voxelCount(worldDimension: worldDimension)
    
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R8_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(voxelCount)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID1 = descriptorHeap.createUAV(
      resource: dense.atomsRemovedMarks.d3d12Resource,
      uavDesc: uavDesc)
    dense.atomsRemovedMarksHandleID = handleID1
    
    let handleID2 = descriptorHeap.createUAV(
      resource: dense.rebuiltMarks.d3d12Resource,
      uavDesc: uavDesc)
    dense.rebuiltMarksHandleID = handleID2
  }
  
  func encodeMemorySlots(descriptorHeap: DescriptorHeap) {
    let bufferByteCount = memorySlotCount * MemorySlot.totalSize
    
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(bufferByteCount / 2)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: sparse.memorySlots.d3d12Resource,
      uavDesc: uavDesc)
    sparse.memorySlotsHandleID = handleID
  }
}
#endif
