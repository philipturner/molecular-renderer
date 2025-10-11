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
  
  // TODO: Reorganize to "group", "dense", and "sparse" sub-containers
  
  // Per dense voxel
  let assignedSlotIDs: Buffer // initialize to UInt32.max with shader
  
  // purge to 0 before every frame
  let voxelGroupAtomsRemovedMarks: Buffer
  let voxelGroupRebuiltMarks: Buffer
  let voxelGroupAddedMarks: Buffer
  let voxelGroupOccupiedMarks: Buffer
  
  // initialize to 0 with shader
  // purge to 0 with idle/active
  let atomsRemovedMarks: Buffer
  let rebuiltMarks: Buffer
  let atomicCounters: Buffer
  #if os(Windows)
  var atomsRemovedMarksHandleID: Int = -1
  var rebuiltMarksHandleID: Int = -1
  #endif
  
  // Per sparse voxel
  let assignedVoxelIDs: Buffer // initialize to UInt32.max with shader
  
  // purge to UInt32.max before every frame
  let atomsRemovedVoxelIDs: Buffer
  let rebuiltVoxelIDs: Buffer
  let vacantSlotIDs: Buffer
  
  let memorySlots: Buffer
  
  init(descriptor: VoxelResourcesDescriptor) {
    guard let device = descriptor.device,
          let voxelAllocationSize = descriptor.voxelAllocationSize,
          let worldDimension = descriptor.worldDimension else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Create a general purpose buffer that resides natively on the GPU.
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    // Create the per dense voxel resources.
    guard worldDimension.remainder(dividingBy: 8) == 0 else {
      fatalError("World dimension was not divisible by 8.")
    }
    guard worldDimension > 0 else {
      fatalError("World dimension was zero.")
    }
    self.worldDimension = worldDimension
    
    let voxelGroupCount = Self.voxelGroupCount(worldDimension: worldDimension)
    let voxelCount = Self.voxelCount(worldDimension: worldDimension)
    self.assignedSlotIDs = createBuffer(size: voxelCount * 4)
    self.atomsRemovedMarks = createBuffer(size: voxelCount)
    self.rebuiltMarks = createBuffer(size: voxelCount)
    self.voxelGroupAddedMarks = createBuffer(size: voxelGroupCount * 4)
    self.voxelGroupOccupiedMarks = createBuffer(size: voxelGroupCount * 4)
    self.atomicCounters = createBuffer(size: voxelCount * 32)
    
    // Create the per sparse voxel resources.
    self.memorySlotCount = Self.memorySlotCount(
      voxelAllocationSize: voxelAllocationSize)
    guard memorySlotCount > 0 else {
      fatalError("Memory slot count was zero.")
    }
    
    self.assignedVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.atomsRemovedVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.rebuiltVoxelIDs = createBuffer(size: memorySlotCount * 4)
    self.vacantSlotIDs = createBuffer(size: memorySlotCount * 4)
    self.memorySlots = createBuffer(size: memorySlotCount * Self.memorySlotSize)
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
