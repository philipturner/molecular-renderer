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
  let shader: Shader
  
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
    
    // Create the shader.
    var shaderDesc = ShaderDescriptor()
    shaderDesc.device = device
    shaderDesc.name = "renderImage"
    shaderDesc.source = Self.createShaderSource()
    self.shader = Shader(descriptor: shaderDesc)
    
    // Create the start time, for reference.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    self.startTime = largeInteger.QuadPart
  }
  
  static func createShaderSource() -> String {
    // Don't need to add a back-slash once this is upgraded to multiple
    // arguments.
    let rootSignature = """
    "DescriptorTable(UAV(u0, numDescriptors = 1)),"
    """
    
    return """
    
    RWTexture2D<float4> frameBuffer : register(u0);
    
    [numthreads(8, 8, 1)]
    [RootSignature(\(rootSignature))]
    void renderImage(
      uint2 tid : SV_DispatchThreadID
    ) {
      uint screenWidth;
      uint screenHeight;
      frameBuffer.GetDimensions(screenWidth, screenHeight);
      
      uint2 center = uint2(
        screenWidth / 2,
        screenHeight / 2);
      
      float radius = 200;
      float distance = length(float2(tid) - float2(center));
      if (distance <= radius) {
        float4 circleColor = float4(1, 0, 1, 0);
        frameBuffer[tid] = circleColor;
      }
    }
    
    """
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
      // Encode the compute command.
      commandList.withPipelineState(shader) {
        let descriptorHeap = swapChain.frameBufferDescriptorHeap
        try! commandList.d3d12CommandList
          .SetDescriptorHeaps([descriptorHeap])
        
        let gpuDescriptorHandle = try! descriptorHeap
          .GetGPUDescriptorHandleForHeapStart()
        try! commandList.d3d12CommandList
          .SetComputeRootDescriptorTable(0, gpuDescriptorHandle)
        
        let groups = SIMD3<UInt32>(1440 / 8, 1440 / 8, 1)
        commandList.dispatch(groups: groups)
      }
      
      // Transitions before the copy command.
      do {
        let barrier1 = Self.transition(
          resource: swapChain.frameBuffer,
          before: D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
          after: D3D12_RESOURCE_STATE_COPY_SOURCE)
        let barrier2 = Self.transition(
          resource: swapChain.backBuffers[ringIndex],
          before: D3D12_RESOURCE_STATE_PRESENT,
          after: D3D12_RESOURCE_STATE_COPY_DEST)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
      
      // Copy the frame buffer into the back buffer.
      do {
        try! commandList.d3d12CommandList.CopyResource(
          swapChain.backBuffers[ringIndex], // pDstResource
          swapChain.frameBuffer) // pSrcResource
      }
      
      // Transition after the copy command.
      do {
        let barrier1 = Self.transition(
          resource: swapChain.frameBuffer,
          before: D3D12_RESOURCE_STATE_COPY_SOURCE,
          after: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
        let barrier2 = Self.transition(
          resource: swapChain.backBuffers[ringIndex],
          before: D3D12_RESOURCE_STATE_COPY_DEST,
          after: D3D12_RESOURCE_STATE_PRESENT)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
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
