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
  
  var frameID: Int?
  var startTime: Int64?
  var clock: Clock
  
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
    
    // Create the clock.
    self.clock = Clock()
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
    
    float convertToChannel(
      float hue,
      float saturation,
      float lightness,
      uint n
    ) {
      float k = float(n) + hue / 30;
      k -= 12 * floor(k / 12);
      
      float a = saturation;
      a *= min(lightness, 1 - lightness);
      
      float output = min(k - 3, 9 - k);
      output = max(output, float(-1));
      output = min(output, float(1));
      output = lightness - a * output;
      return output;
    }
    
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
      
      // Specify the arrangement of the bars.
      float line0 = float(screenHeight) * float(15) / 18;
      float line1 = float(screenHeight) * float(16) / 18;
      float line2 = float(screenHeight) * float(17) / 18;
      
      // Render something based on the pixel's position.
      float4 color;
      if (float(tid.y) < line0) {
        color = float4(0.707, 0.707, 0.00, 1.00);
      } else {
        float progress = float(tid.x) / float(screenWidth);
        if (float(tid.y) < line1) {
          progress += timeArgs.time0;
        } else if (float(tid.y) < line2) {
          progress += timeArgs.time1;
        } else {
          progress += timeArgs.time2;
        }
        
        float hue = float(progress) * 360;
        float saturation = 1.0;
        float lightness = 0.5;
        
        float red = convertToChannel(hue, saturation, lightness, 0);
        float green = convertToChannel(hue, saturation, lightness, 8);
        float blue = convertToChannel(hue, saturation, lightness, 4);
        color = float4(red, green, blue, 1.00);
      }
      
      // Write the pixel to the screen.
      frameBuffer[tid] = color;
    }
    
    """
  }
  
  func renderFrame() {
    // Wait on the waitable object.
    do {
      let result = WaitForSingleObjectEx(
        swapChain.waitableObject, // hHandle
        1000, // dwMilliseconds
        true) // bAlertable
      guard result == 0 else {
        fatalError("Failed to wait for object: \(result)")
      }
    }
    
    // Update the clock.
    do {
      let frameStatistics = try? swapChain.d3d12SwapChain
        .GetFrameStatistics()
      clock.increment(frameStatistics: frameStatistics)
    }
    
    // Update the frame ID.
    var currentFrameID: Int
    if let frameID {
      currentFrameID = frameID + 1
    } else {
      currentFrameID = 0
    }
    self.frameID = currentFrameID
    
    // Fetch the ring index.
    let ringIndex = Int(
      try! swapChain.d3d12SwapChain.GetCurrentBackBufferIndex())
    
    // Encode the GPU commands.
    device.commandQueue.withCommandList { commandList in
      // Utility function for calculating progress values.
      var times: SIMD3<Float> = .zero
      var times2: SIMD3<Float> = .zero
      func setTime(_ time: Double, index: Int) {
        let fractionalTime = time - floor(time)
        times[index] = Float(fractionalTime)
        times2[index] = Float(time)
      }
      
      // Write the absolute time.
      if let startTime {
        let currentTime = Self.getContinuousTime()
        let timeSeconds = Double(currentTime - startTime) / 10_000_000
        setTime(timeSeconds, index: 0)
      } else {
        startTime = Self.getContinuousTime()
        setTime(Double.zero, index: 0)
      }
      
      // Write the time according to the counter.
      do {
        let timeInSeconds1 = Double(clock.frameCounter) / Double(60)
        let timeInSeconds2 = Double(currentFrameID) / Double(60)
        setTime(timeInSeconds1, index: 1)
        setTime(timeInSeconds2, index: 2)
      }
      
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
      
      // Encode the compute command.
      commandList.withPipelineState(shader) {
        let descriptorHeap = swapChain.frameBufferDescriptorHeap
        try! commandList.d3d12CommandList
          .SetDescriptorHeaps([descriptorHeap])
        
        commandList.set32BitConstants(timeArgs, index: 0)
        
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
  
  // Utility function for querying time.
  private static func getContinuousTime() -> Int64 {
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    return largeInteger.QuadPart
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
