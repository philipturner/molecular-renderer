#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

public class CommandQueue {
  unowned let device: Device
  
  #if os(macOS)
  let mtlCommandQueue: MTLCommandQueue
  #else
  let d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue
  let d3d12Fence: SwiftCOM.ID3D12Fence
  let eventHandle: UnsafeMutableRawPointer
  #endif
  
  var previousCommandList: CommandList?
  #if os(Windows)
  var uncompletedCommandLists: [CommandList] = []
  #endif
  
  init(device: Device) {
    self.device = device
    
    // Fill the command queue descriptor.
    #if os(Windows)
    var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
    commandQueueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT
    commandQueueDesc.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL.rawValue
    commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
    commandQueueDesc.NodeMask = 0
    #endif
    
    // Create the command queue.
    #if os(macOS)
    self.mtlCommandQueue = device.mtlDevice.makeCommandQueue()!
    #else
    self.d3d12CommandQueue = try! device.d3d12Device
      .CreateCommandQueue(commandQueueDesc)
    #endif
    
    // Create the fence.
    #if os(Windows)
    self.d3d12Fence = try! device.d3d12Device
      .CreateFence(0, D3D12_FENCE_FLAG_NONE)
    
    // Create the event handle.
    let eventHandle = CreateEventA(nil, false, false, nil)
    guard let eventHandle else {
      fatalError("Failed to create event handle.")
    }
    self.eventHandle = eventHandle
    #endif
  }
}

extension CommandQueue {
  #if os(Windows)
  // Remove references to command lists that finished executing.
  private func newUncompletedCommandLists() -> [CommandList] {
    let currentFenceValue = try! d3d12Fence.GetCompletedValue()
    
    // Iterate over the command lists, in increasing chronological order.
    var output: [CommandList] = []
    for commandList in uncompletedCommandLists {
      if currentFenceValue >= commandList.fenceValue {
        continue
      } else {
        output.append(commandList)
      }
    }
    return output
  }
  #endif
  
  public func withCommandList(
    _ closure: (CommandList) -> Void
  ) {
    var commandListDesc = CommandListDescriptor()
    
    #if os(macOS)
    // Create the command buffer.
    let mtlCommandBuffer = mtlCommandQueue.makeCommandBuffer()!
    commandListDesc.mtlCommandBuffer = mtlCommandBuffer
    #endif
    
    #if os(Windows)
    // Create the command allocator.
    var d3d12CommandAllocator: SwiftCOM.ID3D12CommandAllocator
    d3d12CommandAllocator = try! device.d3d12Device
      .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
    
    // Create the command list from the command allocator.
    var d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList
    d3d12CommandList = try! device.d3d12Device.CreateCommandList(
      0,
      D3D12_COMMAND_LIST_TYPE_DIRECT,
      d3d12CommandAllocator,
      nil)
    commandListDesc.d3d12CommandList = d3d12CommandList
    
    // Assign a fence value.
    do {
      var fenceValue: UInt64
      if let previousCommandList {
        fenceValue = previousCommandList.fenceValue + 1
      } else {
        fenceValue = 1
      }
      commandListDesc.fenceValue = fenceValue
    }
    #endif
    
    // Create the command list.
    let commandList = CommandList(descriptor: commandListDesc)
    closure(commandList)
    
    #if os(macOS)
    commandList.mtlCommandEncoder.endEncoding()
    commandList.mtlCommandBuffer.commit()
    #else
    try! commandList.d3d12CommandList.Close()
    try! d3d12CommandQueue
      .ExecuteCommandLists([commandList.d3d12CommandList])
    
    // Signal the fence value, so we can wait on it later.
    try! d3d12CommandQueue.Signal(
      d3d12Fence, commandList.fenceValue)
    #endif
    
    // Save a reference to the command list.
    previousCommandList = commandList
    #if os(Windows)
    uncompletedCommandLists.append(commandList)
    
    // Garbage collect the completed command lists.
    if uncompletedCommandLists.count > 64 {
      fatalError("Too many command lists were in the queue.")
    }
    uncompletedCommandLists = newUncompletedCommandLists()
    #endif
  }
  
  /// Stall until all GPU commands have completed, and the contents of GPU
  /// buffers are safe to read from the CPU.
  public func flush() {
    guard let previousCommandList else {
      return
    }
    
    #if os(macOS)
    previousCommandList.mtlCommandBuffer.waitUntilCompleted()
    #else
    try! d3d12Fence.SetEventOnCompletion(
      previousCommandList.fenceValue, eventHandle)
    WaitForSingleObject(eventHandle, UInt32.max)
    #endif
  }
}
