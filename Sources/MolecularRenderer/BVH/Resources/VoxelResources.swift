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
    //
    // 64 instead of 32 because of an issue with 32 nm scoped DDA traversal.
    guard worldDimension.remainder(dividingBy: 64) == 0 else {
      fatalError("World dimension was not divisible by 64.")
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
      device: device,
      voxelGroupCount: voxelGroupCount)
    self.dense = DenseVoxelResources(
      device: device,
      voxelCount: voxelCount)
    self.sparse = SparseVoxelResources(
      device: device,
      memorySlotCount: memorySlotCount)
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
    var bytesPerSlot: Int = .zero
    bytesPerSlot += MemorySlot.header.size
    bytesPerSlot += MemorySlot.reference32.size
    bytesPerSlot += MemorySlot.reference16.size
    return voxelAllocationSize / bytesPerSlot
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
  
  // Shader code to store voxel coords to RAM.
  static func encode(_ input: String) -> String {
    "(\(input).z << 20) + (\(input).y << 10) + \(input).x"
  }
  
  // Shader code to read voxel coords from RAM.
  static func decode(_ input: String) -> String {
    "uint3(\(input) & 1023, (\(input) >> 10) & 1023, \(input) >> 20)"
  }
}

class GroupVoxelResources {
  // purge to 0 before every frame
  let atomsRemovedMarks: Buffer
  let addedMarks: Buffer
  let rebuiltMarks: Buffer
  let occupiedMarks8: Buffer
  let occupiedMarks32: Buffer
  
  // purge to UInt32.max before every frame
  let atomsRemovedGroupCoords: Buffer
  let addedGroupCoords: Buffer
  let rebuiltGroupCoords: Buffer
  let resetGroupCoords: Buffer
  
  init(device: Device, voxelGroupCount: Int) {
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.atomsRemovedMarks = createBuffer(size: voxelGroupCount * 4)
    self.addedMarks = createBuffer(size: voxelGroupCount * 4)
    self.rebuiltMarks = createBuffer(size: voxelGroupCount * 4)
    self.occupiedMarks8 = createBuffer(size: voxelGroupCount * 4)
    self.occupiedMarks32 = createBuffer(size: (voxelGroupCount / 64) * 4)
    
    self.atomsRemovedGroupCoords = createBuffer(size: voxelGroupCount * 4)
    self.addedGroupCoords = createBuffer(size: voxelGroupCount * 4)
    self.rebuiltGroupCoords = createBuffer(size: voxelGroupCount * 4)
    self.resetGroupCoords = createBuffer(size: voxelGroupCount * 4)
  }
}

class DenseVoxelResources {
  // initialize to UInt32.max with shader
  let assignedSlotIDs: Buffer
  
  // initialize to 0 with shader
  // purge to 0 with idle/active
  let atomsRemovedMarks: Buffer
  let atomicCounters: Buffer
  let rebuiltMarks: Buffer
  
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
    self.atomicCounters = createBuffer(size: voxelCount * 32)
    self.rebuiltMarks = createBuffer(size: voxelCount)
  }
}

class SparseVoxelResources {
  // initialize to UInt32.max with shader
  let assignedVoxelCoords: Buffer
  
  // purge to UInt32.max before every frame
  let atomsRemovedVoxelCoords: Buffer
  let rebuiltVoxelCoords: Buffer
  let vacantSlotIDs: Buffer
  
  let headers: Buffer
  let references32: Buffer
  #if os(macOS)
  let references16: Buffer
  #else
  var references16: [Buffer] = []
  var references16HandleID: Int = -1
  #endif
  
  init(device: Device, memorySlotCount: Int) {
    func createBuffer(size: Int) -> Buffer {
      var bufferDesc = BufferDescriptor()
      bufferDesc.device = device
      bufferDesc.size = size
      bufferDesc.type = .native(.device)
      return Buffer(descriptor: bufferDesc)
    }
    
    self.assignedVoxelCoords = createBuffer(size: memorySlotCount * 4)
    self.atomsRemovedVoxelCoords = createBuffer(size: memorySlotCount * 4)
    self.rebuiltVoxelCoords = createBuffer(size: memorySlotCount * 4)
    self.vacantSlotIDs = createBuffer(size: memorySlotCount * 4)
    
    self.headers = createBuffer(
      size: memorySlotCount * MemorySlot.header.size)
    self.references32 = createBuffer(
      size: memorySlotCount * MemorySlot.reference32.size)
    #if os(macOS)
    self.references16 = createBuffer(
      size: memorySlotCount * MemorySlot.reference16.size)
    #else
    func slotRange(regionID: Int) -> Range<Int> {
      let max32BitSlotCount = MemorySlot.reference16.max32BitSlotCount
      let startSlotID = regionID * max32BitSlotCount
      var endSlotID = startSlotID + max32BitSlotCount
      endSlotID = min(endSlotID, memorySlotCount)
      return startSlotID..<endSlotID
    }

    let regionCount = SparseVoxelResources.regionCount(
      memorySlotCount: memorySlotCount)
    for regionID in 0..<regionCount {
      let range = slotRange(regionID: regionID)

      let buffer = createBuffer(
        size: range.count * MemorySlot.reference16.size)
      self.references16.append(buffer)
    }
    #endif
  }
  
  static func overflows32(memorySlotCount: Int) -> Bool {
    return overflows16(memorySlotCount: memorySlotCount)
  }
  
  static func overflows16(memorySlotCount: Int) -> Bool {
    let max32BitSlotCount = MemorySlot.reference16.max32BitSlotCount
    return memorySlotCount > max32BitSlotCount
  }
  
  #if os(Windows)
  // The number of ~4 GB regions the references16 buffer is divided into.
  static func regionCount(memorySlotCount: Int) -> Int {
    let max32BitSlotCount = MemorySlot.reference16.max32BitSlotCount
    
    var output = memorySlotCount
    output += max32BitSlotCount - 1
    output /= max32BitSlotCount
    return output
  }
  
  static func ref16FunctionArgument(
    _ memorySlotCount: Int
  ) -> String {
    let regionCount = Self.regionCount(
      memorySlotCount: memorySlotCount)
    
    if regionCount <= 1 {
      return """
      RWBuffer<uint> references16 : register(u100);
      """
    } else {
      return """
      RWBuffer<uint> references16[\(regionCount)] : register(u100);
      """
    }
  }
  
  // Re-mapping the buffer slot to 100 because in HLSL, buffer labels
  // don't correspond to RootParameterIndex.
  static func ref16RootSignatureArgument(
    _ memorySlotCount: Int
  ) -> String {
    let regionCount = Self.regionCount(
      memorySlotCount: memorySlotCount)
    return """
    DescriptorTable(UAV(u100, numDescriptors = \(regionCount)))
    """
  }
  #endif

  func bindReferences16(
    commandList: CommandList, 
    index: Int
  ) {
    #if os(macOS)
    commandList.setBuffer(references16, index: index)
    #else
    let handleID = references16HandleID
    commandList.setDescriptor(
      handleID: handleID, index: index)
    #endif
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
    func slotRange(regionID: Int) -> Range<Int> {
      let max32BitSlotCount = MemorySlot.reference16.max32BitSlotCount
      let startSlotID = regionID * max32BitSlotCount
      var endSlotID = startSlotID + max32BitSlotCount
      endSlotID = min(endSlotID, memorySlotCount)
      return startSlotID..<endSlotID
    }
    
    let regionCount = SparseVoxelResources.regionCount(
      memorySlotCount: memorySlotCount)
    for regionID in 0..<regionCount {
      let range = slotRange(regionID: regionID)

      var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
      uavDesc.Format = DXGI_FORMAT_R16_UINT
      uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
      uavDesc.Buffer.FirstElement = 0
      uavDesc.Buffer.NumElements = UInt32(range.count * 20480)
      uavDesc.Buffer.StructureByteStride = 0
      uavDesc.Buffer.CounterOffsetInBytes = 0
      uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
      
      let buffer = sparse.references16[regionID]
      let handleID = descriptorHeap.createUAV(
        resource: buffer.d3d12Resource,
        uavDesc: uavDesc)
      if regionID == 0 {
        sparse.references16HandleID = handleID
      }
    }
  }
}
#endif
