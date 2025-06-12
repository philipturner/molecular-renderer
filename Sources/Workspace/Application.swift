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
  var frameID: Int = .zero
  
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
    let rootSignature = """
    "RootConstants(num32BitConstants = 3, b0),"
    "DescriptorTable(UAV(u0, numDescriptors = 1)),"
    """
    
    return """
    
    struct TimeArguments {
      float time0;
      float time1;
      float time2;
    };
    
    ConstantBuffer<TimeArguments> timeArgs : register(b0);
    RWTexture2D<float4> frameBuffer : register(u0);
    
    [numthreads(8, 8, 1)]
    [RootSignature(\(rootSignature))]
    void renderImage(
      uint2 tid : SV_DispatchThreadID
    ) {
      // Query the screen's dimensions.
      uint screenWidth;
      uint screenHeight;
      frameBuffer.GetDimensions(screenWidth, screenHeight);
      
      // Define the center of the screen.
      uint2 center = uint2(
        screenWidth / 2,
        screenHeight / 2);
      
      // Render something based on the radial distance from the center.
      float radius = 200;
      float distance = length(float2(tid) - float2(center));
      float4 pixelColor;
      if (distance <= radius) {
        float progress;
        if (tid.y < center.y) {
          progress = timeArgs.time0;
        } else {
          progress = timeArgs.time1;
        }
        pixelColor = float4(progress, progress, 1, 0);
      } else {
        pixelColor = float4(0, 0, 0, 0);
      }
      
      // Write the pixel to the screen.
      frameBuffer[tid] = pixelColor;
    }
    
    """
  }
  
  func renderFrame() {
    // Update the frame ID.
    self.frameID += 1
    
    // Fetch the ring index.
    let ringIndex = Int(
      try! swapChain.d3d12SwapChain.GetCurrentBackBufferIndex())
    
    // Fetch the current time.
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    let currentTime = largeInteger.QuadPart
    
    // Calculate the time difference.
    let elapsedTime = Double(currentTime - startTime) / Double(10e6)
    let elapsedFrames = Int(elapsedTime * 60)
    
    // Calculate the progress values.
    let frameIDs = SIMD3<UInt32>(
      UInt32(elapsedFrames),
      UInt32(self.frameID),
      UInt32(0))
    let times = SIMD3<Float>(frameIDs % 60) / Float(60)
    
    // Fill the arguments data structure.
    struct TimeArguments {
      var time0: Float = .zero
      var time1: Float = .zero
      var time2: Float = .zero
    }
    var timeArgs = TimeArguments()
    timeArgs.time0 = times[0]
    timeArgs.time1 = times[1]
    timeArgs.time2 = times[2]
    
    // Encode the GPU commands.
    device.commandQueue.withCommandList { commandList in
      // Encode the compute command.
      commandList.withPipelineState(shader) {
        let descriptorHeap = swapChain.frameBufferDescriptorHeap
        try! commandList.d3d12CommandList
          .SetDescriptorHeaps([descriptorHeap])
        
        try! commandList.d3d12CommandList.SetComputeRoot32BitConstants(
          0, // RootParameterIndex
          3, // Num32BitValuesToSet
          &timeArgs, // pSrcData
          0) // DestOffsetIn32BitValues
        
        let gpuDescriptorHandle = try! descriptorHeap
          .GetGPUDescriptorHandleForHeapStart()
        try! commandList.d3d12CommandList
          .SetComputeRootDescriptorTable(1, gpuDescriptorHandle)
        
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
