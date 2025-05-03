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
    self.fenceValue = 0
    self.commandListType = type
    self.d3d12Device = device
    
    var commandQueueDesc = D3D12_COMMAND_QUEUE_DESC()
    commandQueueDesc.Type = type
    commandQueueDesc.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL.rawValue
    commandQueueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE
    commandQueueDesc.NodeMask = 0
    
    d3d12CommandQueue = try! d3d12Device.CreateCommandQueue(commandQueueDesc)
    d3d12Fence = try! d3d12Device.CreateFence(fenceValue, D3D12_FENCE_FLAG_NONE)
    
    let fenceEvent = CreateEventA(nil, false, false, nil)
    guard let fenceEvent else {
      fatalError("Failed to create fence event handle.")
    }
    self.fenceEvent = fenceEvent
  }
  
  /// Get an available command list from the command queue.
  public func GetCommandList() -> SwiftCOM.ID3D12GraphicsCommandList {
    // Check whether we can recycle an existing command allocator.
    var commandAllocatorExists = false
    if commandAllocatorQueue.count > 0 {
      let frontEntry = commandAllocatorQueue.first!
      let frontFenceValue = frontEntry.fenceValue
      
      if IsFenceComplete(fenceValue: frontFenceValue) {
        commandAllocatorExists = true
      }
    }
    
    // Materialize a command allocator.
    var commandAllocator: SwiftCOM.ID3D12CommandAllocator
    if commandAllocatorExists {
      // Remove the first element from the queue.
      let frontEntry = commandAllocatorQueue.first!
      commandAllocatorQueue.removeFirst()
      commandAllocator = frontEntry.commandAllocator
      
      try! commandAllocator.Reset()
    } else {
      commandAllocator = CreateCommandAllocator()
    }
    
    // Materialize a command list.
    var commandList: SwiftCOM.ID3D12GraphicsCommandList
    if commandListQueue.count > 0 {
      // Remove the first element from the queue.
      commandList = commandListQueue.first!
      commandListQueue.removeFirst()
      
      try! commandList.Reset(commandAllocator, nil)
    } else {
      commandList = CreateCommandList(allocator: commandAllocator)
    }
    
    // Associate the command allocator with the command list so that it can be
    // retrieved when the command list is executed.
    var guid: _GUID = ID3D12CommandAllocator.IID
    try! commandList.SetPrivateDataInterface(&guid, commandAllocator)
    
    return commandList
  }
  
  /// Execute a command list.
  /// - Returns: A fence value to wait for for this command list.
  public func ExecuteCommandList(_ commandList: SwiftCOM.ID3D12GraphicsCommandList) -> UInt64 {
    try! commandList.Close()
    
    // Get the private data for the command allocator.
    func getPrivateData(
      commandList: SwiftCOM.ID3D12GraphicsCommandList
    ) -> SwiftCOM.ID3D12CommandAllocator {
      var guid: _GUID = ID3D12CommandAllocator.IID
      var dataSize: UInt32 = 8
      var pData = UnsafeMutableRawPointer(bitPattern: 0).unsafelyUnwrapped
      try! commandList.GetPrivateData(&guid, &dataSize, &pData)
      
      // Inspect the object pointer you were handed.
      guard Int(bitPattern: pData) != 0 else {
        fatalError("pData was invalid.")
      }
      
      // Create an IUnknown with the 'consuming' initializer, where the
      // reference count will change by -1 once it eventually deinitializes.
      let interface = SwiftCOM.ID3D12CommandAllocator(pUnk: pData)
      return interface
    }
    let commandAllocator = getPrivateData(commandList: commandList)
    
    // Execute an array of command lists
    do {
      let commandListArray = [commandList]
      try! d3d12CommandQueue.ExecuteCommandLists(commandListArray)
    }
    
    // Retrieve the fence value.
    let fenceValue = Signal()
    
    // Append to the command allocator queue.
    do {
      let entry = CommandAllocatorEntry(
        fenceValue: fenceValue,
        commandAllocator: commandAllocator)
      commandAllocatorQueue.append(entry)
    }
    
    // Append to the command list queue.
    commandListQueue.append(commandList)
    
    // No need to explicitly call 'Release()', as done in the tutorial. The
    // C++ version explicitly managed COM references, while the Swift version
    // already has the deinit primed to happen.
    return fenceValue
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
    let commandAllocator: SwiftCOM.ID3D12CommandAllocator = try! d3d12Device.CreateCommandAllocator(commandListType)
    return commandAllocator
  }
  
  private func CreateCommandList(allocator: SwiftCOM.ID3D12CommandAllocator) -> SwiftCOM.ID3D12GraphicsCommandList {
    let commandList: SwiftCOM.ID3D12GraphicsCommandList = try! d3d12Device.CreateCommandList(0, commandListType, allocator, nil)
    return commandList
  }
}

#endif
