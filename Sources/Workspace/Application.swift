#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let device: Device
  let window: HWND
  let swapChain: SwapChain
  
  let startTime: Int64
  
  init() {
    // Create the device.
    var deviceDesc = DeviceDescriptor()
    deviceDesc.deviceID = Device.fastestDeviceID
    self.device = Device(descriptor: deviceDesc)
    
    // Create the window.
    self.window = WindowUtilities.createWindow()
    
    // Create the swap chain.
    var swapChainDesc = SwapChainDescriptor()
    swapChainDesc.device = device
    swapChainDesc.window = window
    self.swapChain = SwapChain(descriptor: swapChainDesc)
    
    // Create the start time, for reference.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    self.startTime = largeInteger.QuadPart
  }
  
  func renderFrame() {
    // Fetch the current time.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    let currentTime = largeInteger.QuadPart
    
    // Display the time difference.
    let elapsedTime = Double(currentTime - startTime) / Double(10e6)
    let frameID = Int(elapsedTime * 60)
    print("frame ID:", frameID)
    
    // Fetch the ring index.
    let ringIndex = Int(
      try! swapChain.d3d12SwapChain.GetCurrentBackBufferIndex())
    
    // Encode the GPU commands.
    device.commandQueue.withCommandList { commandList in
      // Transition from PRESENT to RENDER_TARGET.
      do {
        let backBuffer = swapChain.backBuffers[ringIndex]
        let barrier = Self.transition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_PRESENT,
          after: D3D12_RESOURCE_STATE_RENDER_TARGET)
        try! commandList.d3d12CommandList
          .ResourceBarrier(1, [barrier])
      }
      
      // Clear the render target.
      do {
        let descriptorHeap = swapChain.descriptorHeaps[ringIndex]
        let color = (Float(0.4), Float(0.6), Float(0.9), Float(1.0))
        let cpuDescriptorHandle = try! descriptorHeap
          .GetCPUDescriptorHandleForHeapStart()
        try! commandList.d3d12CommandList.ClearRenderTargetView(
          cpuDescriptorHandle, // RenderTargetView
          color, // ColorRGBA
          0, // NumRects
          nil) // pRects
      }
      
      // Transition from RENDER_TARGET to PRESENT.
      do {
        let backBuffer = swapChain.backBuffers[ringIndex]
        let barrier = Self.transition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_RENDER_TARGET,
          after: D3D12_RESOURCE_STATE_PRESENT)
        try! commandList.d3d12CommandList
          .ResourceBarrier(1, [barrier])
      }
    }
    
    // Send the render target to the DWM.
    try! swapChain.d3d12SwapChain.Present(1, 0)
  }
  
  // Utility function for transitioning resources.
  private static func transition(
    resource: SwiftCOM.ID3D12Resource,
    before: D3D12_RESOURCE_STATES,
    after: D3D12_RESOURCE_STATES
  ) -> D3D12_RESOURCE_BARRIER {
    // Specify the type of barrier.
    var barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    
    // Specify the transition's parameters.
    try! resource.perform(
      as: WinSDK.ID3D12Resource.self
    ) { pUnk in
      barrier.Transition.pResource = pUnk
    }
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.Transition.StateBefore = before
    barrier.Transition.StateAfter = after
    
    return barrier
  }
}

#endif
