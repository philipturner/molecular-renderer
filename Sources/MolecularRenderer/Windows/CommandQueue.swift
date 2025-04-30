#if os(Windows)
import SwiftCOM
import WinSDK

// Exercise in usage of the DirectX 12 API.
// Implementing the CommandQueue API design from:
// https://www.3dgep.com/learning-directx-12-2/#The_Command_Queue_Class
// As literal of a translation as possible from the C++ origin.

public class CommandQueue {
  // MARK: - Private
  
  struct CommandAllocatorEntry {
    var fenceValue: UInt64
    var commandAllocator: SwiftCOM.ID3D12CommandAllocator
  }
  
  private var commandListType: D3D12_COMMAND_LIST_TYPE
  private var d3d12Device: SwiftCOM.ID3D12Device
  private var d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue
  private var d3d12Fence: SwiftCOM.ID3D12Fence
  private var fenceEvent: HANDLE
  private var fenceValue: UInt64
  
  private var commandAllocatorQueue: [CommandAllocatorEntry] = []
  private var commandListQueue: [SwiftCOM.ID3D12GraphicsCommandList] = []
  
  // MARK: - Public
  
  public init(device: SwiftCOM.ID3D12Device, type: D3D12_COMMAND_LIST_TYPE) {
    fatalError("Not implemented.")
  }
  
  /// Get an available command list from the command queue.
  public func GetCommandList() -> SwiftCOM.ID3D12GraphicsCommandList {
    fatalError("Not implemented.")
  }
  
  /// Execute a command list.
  /// - Returns: A fence value to wait for for this command list.
  public func ExecuteCommandList(_ commandList: SwiftCOM.ID3D12GraphicsCommandList) -> UInt64 {
    fatalError("Not implemented.")
  }
  
  public func Signal() -> UInt64 {
    fatalError("Not implemented.")
  }
  
  public func IsFenceComplete(fenceValue: UInt64) -> Bool {
    fatalError("Not implemented.")
  }
  
  public func WaitForFenceValue(_ fenceValue: UInt64) {
    fatalError("Not implemented.")
  }
  
  public func Flush() {
    fatalError("Not implemented.")
  }
  
  // MARK: - Protected
  
  private func CreateCommandAllocator() -> SwiftCOM.ID3D12CommandAllocator {
    fatalError("Not implemented.")
  }
  
  private func CreateCommandList(allocator: SwiftCOM.ID3D12CommandAllocator) -> SwiftCOM.ID3D12GraphicsCommandList {
    fatalError("Not implemented.")
  }
}

#endif
