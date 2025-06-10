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
  
  // This is inching closer to the target design on Windows, which tracks the
  // entire history of in-flight command lists. This alone might solve the
  // crash I'm currently experiencing in the run loop.
  var previousCommandList: CommandList?
  
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
  public func withCommandList(
    _ closure: (CommandList) -> Void
  ) {
    var commandListDesc = CommandListDescriptor()
    
    #if os(macOS)
    // Create the command buffer.
    let mtlCommandBuffer = commandQueue.mtlCommandQueue.makeCommandBuffer()!
    commandListDesc.mtlCommandBuffer = mtlCommandBuffer
    #endif
    
    #if os(Windows)
    // Create the command allocator.
    //
    // The DirectX API will often regenerate a pointer to the same region of
    // memory for the command allocator. One command allocator may be shared by
    // multiple command lists, causing errors like #552.
    //
    // But this reuse of memory isn't what triggers the error.
    //
    // On the other hand, holding a reference to every previously submitted
    // ID3D12GraphicsCommandList stops to crash from happening.
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
    var fenceValue: UInt64
    if let previousCommandList {
      fenceValue = previousCommandList.fenceValue
    } else {
      fenceValue = 0
    }
    commandListDesc.fenceValue = fenceValue
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
    
    // Add a fence to the command stream, so we can wait on it later.
    commandQueue.fenceValue += 1
    try! commandQueue.d3d12CommandQueue.Signal(
      commandQueue.d3d12Fence,
      commandQueue.fenceValue)
    #endif
  }
  
  /// Stall until all GPU commands have completed, and the contents of GPU
  /// buffers are safe to read from the CPU.
  public func flush() {
    guard currentCommandList == nil else {
      fatalError("Cannot flush while a command list is being encoded.")
    }
    guard let previousCommandList else {
      return
    }
    
    #if os(macOS)
    previousCommandList.waitUntilCompleted()
    #else
    
    
    try! commandQueue.d3d12Fence.SetEventOnCompletion(
      commandQueue.fenceValue,
      commandQueue.eventHandle)
    
    // Wait for 1000 seconds (~20 minutes).
    let waitTimeInMilliseconds: UInt32 = 1000 * 1000
    WaitForSingleObject(
      commandQueue.eventHandle,
      waitTimeInMilliseconds)
    #endif
  }
}
