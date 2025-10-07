#if os(Windows)
import SwiftCOM
import WinSDK

extension BVHBuilder {
  func encodeMotionVectors(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID = descriptorHeap.createUAV(
      resource: motionVectors.d3d12Resource,
      uavDesc: uavDesc)
    self.motionVectorsHandleID = handleID
  }
  
  func encodeRelativeOffsets(descriptorHeap: DescriptorHeap) {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16G16B16A16_UINT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(addressSpaceSize)
    uavDesc.Buffer.StructureByteStride = 0
    uavDesc.Buffer.CounterOffsetInBytes = 0
    uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_NONE
    
    let handleID1 = descriptorHeap.createUAV(
      resource: relativeOffsets1.d3d12Resource,
      uavDesc: uavDesc)
    self.relativeOffsets1HandleID = handleID1
    
    let handleID2 = descriptorHeap.createUAV(
      resource: relativeOffsets2.d3d12Resource,
      uavDesc: uavDesc)
    self.relativeOffsets2HandleID = handleID2
  }
}

#endif
