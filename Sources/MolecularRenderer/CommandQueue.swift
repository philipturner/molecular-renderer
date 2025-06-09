#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

class CommandQueue {
  #if os(macOS)
  let mtlCommandQueue: MTLCommandQueue
  var currentCommandBuffer: MTLCommandBuffer?
  var lastCommandBuffer: MTLCommandBuffer?
  #else
  let d3d12CommandQueue: SwiftCOM.ID3D12CommandQueue
  let d3d12Fence: SwiftCOM.ID3D12Fence
  let eventHandle: UnsafeMutableRawPointer
  var fenceValue: UInt64 = .zero
  #endif
  
  init(device: Device) {
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

extension Device {
  public func createCommandList() -> CommandList {
    #if os(macOS)
    // Check that the current command buffer does not exist.
    guard commandQueue.currentCommandBuffer == nil else {
      fatalError("""
        Attempted to open a new command list while the previous one was still
        being encoded.
        """)
    }
    
    // Open the command buffer.
    let mtlCommandBuffer = commandQueue.mtlCommandQueue.makeCommandBuffer()!
    commandQueue.currentCommandBuffer = mtlCommandBuffer
    
    // Open the command encoder.
    let mtlCommandEncoder = mtlCommandBuffer.makeComputeCommandEncoder()!
    return CommandList(mtlCommandEncoder: mtlCommandEncoder)
    #endif
    
    #if os(Windows)
    // Create the command allocator.
    let d3d12CommandAllocator: SwiftCOM.ID3D12CommandAllocator =
    try! d3d12Device.CreateCommandAllocator(
      D3D12_COMMAND_LIST_TYPE_DIRECT)
    
    // Create the command list from the command allocator.
    let d3d12CommandList: SwiftCOM.ID3D12GraphicsCommandList =
    try! d3d12Device.CreateCommandList(
      0,
      D3D12_COMMAND_LIST_TYPE_DIRECT,
      d3d12CommandAllocator,
      nil)
    
    // The command list increments the command allocator's reference, as long
    // as the command list is alive.
    return CommandList(d3d12CommandList: d3d12CommandList)
    #endif
  }
  
  public func commit(_ commandList: CommandList) {
    #if os(macOS)
    // Close the command encoder.
    commandList.mtlCommandEncoder.endEncoding()
    
    // Fetch and purge the current command buffer.
    let currentCommandBuffer = commandQueue.currentCommandBuffer
    guard let currentCommandBuffer else {
      fatalError("This should never happen.")
    }
    commandQueue.currentCommandBuffer = nil
    
    // Close the command buffer.
    currentCommandBuffer.commit()
    commandQueue.lastCommandBuffer = currentCommandBuffer
    #endif
    
    #if os(Windows)
    // Close the command list.
    try! commandList.d3d12CommandList.Close()
    
    // Submit the command list to the queue.
    let commandLists = [commandList.d3d12CommandList]
    try! commandQueue.d3d12CommandQueue
      .ExecuteCommandLists(commandLists)
    
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
    #if os(macOS)
    commandQueue.lastCommandBuffer?.waitUntilCompleted()
    #else
    // Do not follow the fastpath that checks whether the fence's value is
    // already good enough. This is a simpler approach, but it may incur
    // additional CPU-side latency for DirectX. This extra latency is trivial;
    // any command stalling on GPU work is ultra-high latency.
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
