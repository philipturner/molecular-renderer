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
  
  // Shader code to generate a voxel address.
  static func generate(
    _ input: String,
    _ gridDimension: Float
  ) -> String {
    let gridWidthSq = Int(gridDimension * gridDimension)
    let gridWidth = Int(gridDimension)
    return "\(input).z * \(gridWidthSq) + \(input).y * \(gridWidth) + \(input).x"
  }
  
  static func memorySlotCount(voxelAllocationSize: Int) -> Int {
    return voxelAllocationSize / memorySlotSize
  }
  
  static var memorySlotSize: Int {
    var output: Int = .zero
    output += 16 // header
    output += 512 * 8 // per 0.25 nm voxel header
    output += 3072 * 4 // 2 nm -> global mapping, fused with 3-bit tag
    output += 20480 * 4 // 0.25 nm -> global mapping
    return output
  }
}

struct GroupVoxelResources {
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

struct DenseVoxelResources {
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

struct SparseVoxelResources {
  // initialize to UInt32.max with shader
  let assignedVoxelIDs: Buffer
  
  // purge to UInt32.max before every frame
  let atomsRemovedVoxelIDs: Buffer
  let rebuiltVoxelIDs: Buffer
  let vacantSlotIDs: Buffer
  
  let memorySlots: Buffer
  
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
      size: memorySlotCount * VoxelResources.memorySlotSize)
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
      resource: atomsRemovedMarks.d3d12Resource,
      uavDesc: uavDesc)
    self.atomsRemovedMarksHandleID = handleID1
    
    let handleID2 = descriptorHeap.createUAV(
      resource: rebuiltMarks.d3d12Resource,
      uavDesc: uavDesc)
    self.rebuiltMarksHandleID = handleID2
  }
}
#endif
