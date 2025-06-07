#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public struct CommandList {
  #if os(macOS)
  public let mtlCommandEncoder: MTLComputeCommandEncoder
  #else
  public let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
  #endif
}
