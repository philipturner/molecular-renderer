#if os(Windows)
import SwiftCOM
import WinSDK

public class CommandQueue {
  let d3d12Device: SwiftCOM.ID3D12Device
  let d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue
  let d3d12Fence: SwiftCOM.ID3D12Fence
  
  let eventHandle: UnsafeMutableRawPointer
  var fenceValue: UInt64 = .zero
  
  public init(device: DirectXDevice) {
    self.d3d12Device = device.d3d12Device
    
    // Fill the command queue descriptor.
    var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
    commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_COMPUTE
    commandQueueDesc.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL.rawValue
    commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
    commandQueueDesc.NodeMask = 0
    
    // Create the command queue.
    self.d3d12CommandQueue = try! d3d12Device.CreateCommandQueue(
      commandQueueDesc)
    
    // Create the fence.
    self.d3d12Fence = try! d3d12Device.CreateFence(
      0,
      D3D12_FENCE_FLAG_NONE)
    
    // Create the event handle.
    let eventHandle = CreateEventA(nil, false, false, nil)
    guard let eventHandle else {
      fatalError("Failed to create event handle.")
    }
    self.eventHandle = eventHandle
  }
  
  public func createCommandList() -> SwiftCOM.ID3D12GraphicsCommandList {
    // Create the command allocator.
    let commandAllocator: SwiftCOM.ID3D12CommandAllocator =
    try! d3d12Device.CreateCommandAllocator(
      D3D12_COMMAND_LIST_TYPE_COMPUTE)
    
    // Create the command list from the command allocator.
    let commandList: SwiftCOM.ID3D12GraphicsCommandList =
    try! d3d12Device.CreateCommandList(
      0,
      D3D12_COMMAND_LIST_TYPE_COMPUTE,
      commandAllocator,
      nil)
    
    // The command list increments the command allocator's reference, as long as
    // the command list is alive.
    return commandList
  }
  
  public func commit(_ commandList: SwiftCOM.ID3D12GraphicsCommandList) {
    // Objectives:
    // - close the command list
    // - call 'ExecuteCommandLists()' on the command queue
    fatalError("Not implemented.")
  }
  
  /// Stall until all GPU commands have completed, and the contents of GPU
  /// buffers are safe to read from the CPU.
  public func flush() {
    // Objectives:
    // - increment the fence counter
    // - use the fence created when this was initialized
    fatalError("Not implemented.")
  }
}

#endif
