// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene). [DONE]
// - Repeat the same process with COM / D3D12 on Windows.
//   - Get some general experience with C++ DirectX sample code.
//   - Modify the files one-by-one to support Windows.

import MolecularRenderer

#if os(macOS)
import Metal

@MainActor
func createApplication() -> Application {
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.renderTargetSize = 1920
  displayDesc.screenID = Display.fastestScreenID
  let display = Display(descriptor: displayDesc)
  
  // Set up the GPU context.
  var gpuContextDesc = GPUContextDescriptor()
  gpuContextDesc.deviceID = GPUContext.fastestDeviceID
  let gpuContext = GPUContext(descriptor: gpuContextDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.display = display
  applicationDesc.gpuContext = gpuContext
  let application = Application(descriptor: applicationDesc)
  
  return application
}

func createShaderSource() -> String {
  """
  
  #include <metal_stdlib>
  using namespace metal;
  
  half convertToChannel(
    half hue,
    half saturation,
    half lightness,
    ushort n
  ) {
    half k = half(n) + hue / 30;
    k -= 12 * floor(k / 12);
  
    half a = saturation;
    a *= min(lightness, 1 - lightness);
  
    half output = min(k - 3, 9 - k);
    output = max(output, half(-1));
    output = min(output, half(1));
    output = lightness - a * output;
    return output;
  }
  
  kernel void renderImage(
    constant float *time0 [[buffer(0)]],
    constant float *time1 [[buffer(1)]],
    constant float *time2 [[buffer(2)]],
    texture2d<half, access::write> drawableTexture [[texture(0)]],
    ushort2 tid [[thread_position_in_grid]]
  ) {
    half4 color;
    if (tid.y < 1600) {
      color = half4(0.707, 0.707, 0.00, 1.00);
    } else {
      float progress = float(tid.x) / 1920;
      if (tid.y < 1600 + 107) {
        progress += *time0;
      } else if (tid.y < 1600 + 213) {
        progress += *time1;
      } else {
        progress += *time2;
      }
  
      half hue = half(progress) * 360;
      half saturation = 1.0;
      half lightness = 0.5;
  
      half red = convertToChannel(hue, saturation, lightness, 0);
      half green = convertToChannel(hue, saturation, lightness, 8);
      half blue = convertToChannel(hue, saturation, lightness, 4);
      color = half4(red, green, blue, 1.00);
    }
  
    drawableTexture.write(color, tid);
  }
  
  """
}

func createRenderPipeline(
  application: Application,
  shaderSource: String
) -> MTLComputePipelineState {
  let device = application.gpuContext.device
  let shaderSource = createShaderSource()
  let library = try! device.makeLibrary(source: shaderSource, options: nil)
  
  let function = library.makeFunction(name: "renderImage")
  guard let function else {
    fatalError("Could not make function.")
  }
  let pipeline = try! device.makeComputePipelineState(function: function)
  return pipeline
}

// Set up the resources.
let application = createApplication()
let shaderSource = createShaderSource()
let renderPipeline = createRenderPipeline(
  application: application,
  shaderSource: shaderSource)

var startTime: UInt64?
var frameID: Int = .zero

// Enter the run loop.
application.run { renderTarget in
  frameID += 1
  
  // Start the command encoder.
  let commandQueue = application.gpuContext.commandQueue
  let commandBuffer = commandQueue.makeCommandBuffer()!
  let encoder = commandBuffer.makeComputeCommandEncoder()!
  
  // Bind the buffers.
  do {
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - floor(time)
      var time32 = Float(fractionalTime)
      encoder.setBytes(&time32, length: 4, index: index)
    }
    
    if let startTime {
      let currentTime = mach_continuous_time()
      let timeSeconds = Double(currentTime - startTime) / 24_000_000
      setTime(timeSeconds, index: 0)
    } else {
      startTime = mach_continuous_time()
      setTime(Double.zero, index: 0)
    }
    
    let clock = application.clock
    let timeInFrames = clock.frames
    let framesPerSecond = application.display.frameRate
    let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
    setTime(timeInSeconds, index: 1)
    
    setTime(Double.zero, index: 2)
  }
  
  // Bind the textures.
  encoder.setTexture(renderTarget, index: 0)
  
  // Dispatch
  do {
    encoder.setComputePipelineState(renderPipeline)
    
    let width = Int(renderTarget.width)
    let height = Int(renderTarget.height)
    encoder.dispatchThreads(
      MTLSize(width: width, height: height, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
  }
  
  // End the command encoder.
  encoder.endEncoding()
  commandBuffer.commit()
}
#endif



#if os(Windows)

// Next steps to refactor the codebase:
// - Reorganize the files in molecular-renderer to a loose grouping of what
//   "should be" common vs. macOS vs. Windows [DONE]
// - Redirect the executable links in the package manifest to
//   molecular-renderer [DONE]
// - Create utility files that can smoke test the following:
//   - Create a DirectX device [DONE]
//   - DXC symbol linking [DONE]
//   - FidelityFX symbol linking [DONE]
//
// After that:
// - Do not jump ahead to merging any code with that for Apple yet. Need more
//   experience with the entirety of the command dispatching workflow.
// - Implement the CommandQueue exercise.

let device = DirectXDevice()
let d3d12Device = device.d3d12Device
print(d3d12Device)

// The CommandQueue class has finished being translated. Next, how do we test
// it? The code base does not have good unit tests.
//
// Start by studying the tutorials. What is the first function I should call
// to initiate a testing procedure?
//
// Study the functions, what they're supposed to do, and how they're supposed to
// affect the internal state variables. There will be tests that monitor the
// internal state variables and check for unexpected behavior.
// - Ensure the tests cover the case where lists grow to >1 in size.
// - Ensure there are no memory leaks. This is a good question; I wonder how to
//   debug/search for memory leaks in practice.

// var commandListType
// var d3d12Device
// var d3d12CommandQueue
// var d3d12Fence
// var fenceEvent
// var fenceValue
// var commandAllocatorQueue: []
// var commandListQueue: []
//
// init(device:type:)
// func GetCommandList()
// func ExecuteCommandList()
// func Signal()
// func IsFenceComplete(fenceValue:)
// func WaitForFenceValue()
// func Flush()
// func CreateCommandAllocator()
// func CreateCommandList(allocator:)

// I don't need to invest time testing and debugging this functionality. Just
// read along through the tutorials. The translation exercise will reinforce my
// knowledge of DirectX. Once it's complete, I can devise simpler tests.
//
// In a later tutorial, the command allocator is refactored out into the
// 'CommandList' class. There is less risk for memory leaks from manual COM
// memory management. Debugging the code above would waste time unnecessarily.



// Pausing progress on translating the 3DGEP tutorials. I don't feel
// motivated to work on it right now. Instead, I'm returning to the 'logins'
// tutorial about compute shaders. Perhaps there's a faster way to achieve
// 'hello world' for vector addition.
//
// https://logins.github.io/graphics/2020/10/31/D3D12ComputeShaders.html#compute-shaders-in-d3d12

// Issues:
// - How to create resources
// - How to create pipelines
// - What the heck is going on with descriptors
// - What the heck is going on with root signatures
// - How to bind resources to commands
// - How to dispatch GPU threads
// - What the heck is going on with resource state (transitions)
// - How to test the results of GPU execution
//
// Can I do this without reading/translating the 3DGEP tutorials? Can I just
// read them without copying the code? There's a lot of non-DirectX stuff there,
// like boilerplate logic for memory allocation algorithms. I only care about
// the API calls.
// - The 'logins' code in FirstDX12Renderer relies on the utilities in the
//   3DGEP tutorials, so there's a Catch 22. You can't escape the dependency
//   on the utilities.
//
// Sort through all of these issues and find a way to proceed, without wasting
// time unnecessarily.

#endif
