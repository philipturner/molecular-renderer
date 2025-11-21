extension RenderShader {
  static let renderArgs: Int = 1
  static let cameraArgs: Int = 2
  static let atoms: Int = 3
  static let motionVectors: Int = 4
  static let voxelGroup8OccupiedMarks: Int = 5
  static let voxelGroup32OccupiedMarks: Int = 6
  static let assignedSlotIDs: Int = 7
  static let headers: Int = 8
  static let references32: Int = 9
  static let references16: Int = 10
  static let colorTexture: Int = 11
  static let depthTexture: Int = 12
  static let motionTexture: Int = 13

  // atoms.atoms
  // atoms.motionVectors
  // voxels.group.occupiedMarks
  // voxels.dense.assignedSlotIDs
  // voxels.sparse.memorySlots [32, 16]
  static func functionSignature(
    descriptor: RenderShaderDescriptor
  ) -> String {
    guard let isOffline = descriptor.isOffline,
          let memorySlotCount = descriptor.memorySlotCount,
          let supports16BitTypes = descriptor.supports16BitTypes,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("Descriptor was incomplete.")
    }

    #if os(Windows)
    func motionVectorsArgumentType() -> String {
      if supports16BitTypes {
        return "RWStructuredBuffer<half4>"
      } else {
        return "RWBuffer<float4>"
      }
    }

    func motionVectorsRootSignatureArgument() -> String {
      if supports16BitTypes {
        return "UAV(u\(Self.motionVectors))"
      } else {
        return "DescriptorTable(UAV(u\(Self.motionVectors), numDescriptors = 1))"
      }
    }
    #endif

    func colorTextureArgument() -> String {
      if !isOffline {
        #if os(macOS)
        return "texture2d<float, access::write> colorTexture [[texture(\(Self.colorTexture))]]"
        #else
        return "RWTexture2D<float4> colorTexture : register(u\(Self.colorTexture));"
        #endif
      } else {
        #if os(macOS)
        return "device half4 *colorBuffer [[buffer(\(Self.colorTexture))]]"
        #else
        return "RWBuffer<float4> colorBuffer : register(u\(Self.colorTexture));"
        #endif
      }
    }
    
    func upscalingFunctionArguments() -> String {
      guard upscaleFactor > 1 else {
        return ""
      }
      
      #if os(macOS)
      return """
      texture2d<float, access::write> depthTexture [[texture(\(Self.depthTexture))]],
      texture2d<float, access::write> motionTexture [[texture(\(Self.motionTexture))]],
      """
      #else
      return """
      RWTexture2D<float4> depthTexture : register(u\(Self.depthTexture));
      RWTexture2D<float4> motionTexture : register(u\(Self.motionTexture));
      """
      #endif
    }
    
    #if os(Windows)
    func upscalingRootSignatureArguments() -> String {
      guard upscaleFactor > 1 else {
        return ""
      }
      
      return """
      "DescriptorTable(UAV(u\(Self.depthTexture), numDescriptors = 1)),"
      "DescriptorTable(UAV(u\(Self.motionTexture), numDescriptors = 1)),"
      """
    }
    #endif
    
    #if os(macOS)
    return """
    kernel void render(
      \(CrashBuffer.functionArguments),
      constant RenderArgs &renderArgs [[buffer(\(Self.renderArgs))]],
      constant CameraArgsList &cameraArgs [[buffer(\(Self.cameraArgs))]],
      device float4 *atoms [[buffer(\(Self.atoms))]],
      device half4 *motionVectors [[buffer(\(Self.motionVectors))]],
      device uint *voxelGroup8OccupiedMarks [[buffer(\(Self.voxelGroup8OccupiedMarks))]],
      device uint *voxelGroup32OccupiedMarks [[buffer(\(Self.voxelGroup32OccupiedMarks))]],
      device uint *assignedSlotIDs [[buffer(\(Self.assignedSlotIDs))]],
      device uint *headers [[buffer(\(Self.headers))]],
      device uint *references32 [[buffer(\(Self.references32))]],
      device ushort *references16 [[buffer(\(Self.references16))]],
      \(colorTextureArgument()),
      \(upscalingFunctionArguments())
      uint2 pixelCoords [[thread_position_in_grid]],
      uint2 localID [[thread_position_in_threadgroup]])
    """
    #else
    let byteCount = MemoryLayout<RenderArgs>.size
    
    return """
    \(CrashBuffer.functionArguments)
    ConstantBuffer<RenderArgs> renderArgs : register(b\(Self.renderArgs));
    ConstantBuffer<CameraArgsList> cameraArgs : register(b\(Self.cameraArgs));
    RWStructuredBuffer<float4> atoms : register(u\(Self.atoms));
    \(motionVectorsArgumentType()) motionVectors : register(u\(Self.motionVectors));
    RWStructuredBuffer<uint> voxelGroup8OccupiedMarks : register(u\(Self.voxelGroup8OccupiedMarks));
    RWStructuredBuffer<uint> voxelGroup32OccupiedMarks : register(u\(Self.voxelGroup32OccupiedMarks));
    RWStructuredBuffer<uint> assignedSlotIDs : register(u\(Self.assignedSlotIDs));
    RWStructuredBuffer<uint> headers : register(u\(Self.headers));
    RWStructuredBuffer<uint> references32 : register(u\(Self.references32));
    \(SparseVoxelResources.ref16FunctionArgument(memorySlotCount))
    \(colorTextureArgument())
    \(upscalingFunctionArguments())
    
    [numthreads(8, 8, 1)]
    [RootSignature(
      \(CrashBuffer.rootSignatureArguments)
      "RootConstants(b\(Self.renderArgs), num32BitConstants = \(byteCount / 4)),"
      "CBV(b\(Self.cameraArgs)),"
      "UAV(u\(Self.atoms)),"
      "\(motionVectorsRootSignatureArgument()),"
      "UAV(u\(Self.voxelGroup8OccupiedMarks)),"
      "UAV(u\(Self.voxelGroup32OccupiedMarks)),"
      "UAV(u\(Self.assignedSlotIDs)),"
      "UAV(u\(Self.headers)),"
      "UAV(u\(Self.references32)),"
      "\(SparseVoxelResources.ref16RootSignatureArgument(memorySlotCount)),"
      "DescriptorTable(UAV(u\(Self.colorTexture), numDescriptors = 1)),"
      \(upscalingRootSignatureArguments())
    )]
    void render(
      uint2 pixelCoords : SV_DispatchThreadID,
      uint2 localID : SV_GroupThreadID)
    """
    #endif
  }
}
