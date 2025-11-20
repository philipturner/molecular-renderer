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

/*
8 GB: 144654
4 GB: 72327
*/
    
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
  let references16: Buffer
  #if os(Windows)
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
      size: 144654 * MemorySlot.header.size)
    self.references32 = createBuffer(
      size: 144654 * MemorySlot.reference32.size)
    self.references16 = createBuffer(
      size: 144654 * MemorySlot.reference16.size)
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
    // TODO: Test whether we can fix the problem by only
    // using 32-bit references. Perhaps a fallback mode
    // where beefier GPUs can incur the extra bandwidth cost,
    // in exchange for the DirectX API not breaking.
    //
    // Once that is attempted to solve the AMD problem, some
    // possible optimizations:
    // - RebuildProcess2 writes temporarily to a small
    //   allocation encoded as UInt16 with a descriptor heap.
    //   Later, the raw data gets copied to regions of UInt32
    //   scoped larger buffer.
    // - Shaders fetch UInt32 data and choose based on some
    //   bitmasking or conditionals.
    // - The two modes are switched based on amount of
    //   memory allocated. And all of this only happens on
    //   Windows.
    let bufferByteCount = 100000 * MemorySlot.reference16.size
    
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(bufferByteCount / 2)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: sparse.references16.d3d12Resource,
      uavDesc: uavDesc)
    sparse.references16HandleID = handleID
  }
}
#endif
