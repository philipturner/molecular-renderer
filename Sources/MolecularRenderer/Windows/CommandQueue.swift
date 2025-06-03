#if os(Windows)
import SwiftCOM
import WinSDK

public struct CommandQueueDescriptor {
  public var device: Device?
  
  public init() {
    
  }
}

public class CommandQueue {
  let d3d12Device: SwiftCOM.ID3D12Device
  
  // Public for the current swap chain initializer. Return to internal in the
  // future.
  public let d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue
  let d3d12Fence: SwiftCOM.ID3D12Fence
  
  let eventHandle: UnsafeMutableRawPointer
  var fenceValue: UInt64 = .zero
  
  public init(descriptor: CommandQueueDescriptor) {
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    self.d3d12Device = device.d3d12Device
    
    // Fill the command queue descriptor.
    var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
    commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
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
    // Close the compute encoder and commit the command buffer.
    try! commandList.Close()
    try! d3d12CommandQueue.ExecuteCommandLists([commandList])
    
    // Hold a reference to the latest command buffer.
    fenceValue += 1
    try! d3d12CommandQueue.Signal(d3d12Fence, fenceValue)
  }
  
  /// Stall until all GPU commands have completed, and the contents of GPU
  /// buffers are safe to read from the CPU.
  public func flush() {
    // Do not follow the fastpath that checks whether the fence's value is
    // already good enough. This is a simpler approach, but it may incur
    // additional CPU-side latency for DirectX. This extra latency is trivial;
    // any command stalling on GPU work is ultra-high latency.
    try! d3d12Fence.SetEventOnCompletion(fenceValue, eventHandle)
    
    // Determine the wait time in milliseconds.
    //
    // Using a wait time of 1000 seconds (~20 minutes)
    let waitTimeInMilliseconds: UInt32 = 1000 * 1000
    WaitForSingleObject(eventHandle, waitTimeInMilliseconds)
  }
}

#endif
