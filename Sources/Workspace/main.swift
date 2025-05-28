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
import SwiftCOM
import WinSDK

// The "hello world" compute demo works! Next, render an image to the screen
// using only compute shaders.
//
// First research question: can you create a texture that's backed by a buffer?
// Is the drawable for rendering backed by a buffer? If not, each texture
// should own a unique descriptor table, encapsulated in the utility 'Texture'.

// Notes from the 3DGEP tutorial #4
//
// Texture2D<float4> SrcMip : register(t0);
// RWTexture2D<float4> OutMip1 : register(u0);
//
// "DescriptorTable(SRV(t0, numDescriptors = 1)), " \
// "DescriptorTable(UAV(u0, numDescriptors = 4)), " \
//
// float2 UV;
// Src1 = SrcMip.SampleLevel(LinearClampSampler, UV, SrcMipLevel);
// OutMip1[DispatchThreadID.xy] = PackColor(Src1);
//
// D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {};
// uavDesc.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
// uavDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
// uavDesc.Texture2D.MipSlice = i;
// uavDesc.Texture2D.PlaneSlice = 0;
//
// device->CreateUnorderedAccessView(
//   nullptr, nullptr, &uavDesc,
//   m_DefaultUAV.GetDescriptorHandle(i));
//
// There is no actual backing resource for the UAV, so the resource and the
// counter resource are specified as 'nullptr'.
//
// ID3D12Device::CreateShaderResourceView and
// ID3D12Device::CreateUnorderedAccessView only relate to the case where
// resources are stored indirectly as descriptors in tables?
//
// Resources that will be used as a UAV must be created with
// 'UNORDERED_ACCESS' and may not be 'RENDER_TARGET'. Does that mean a
// drawable texture on windows is completely incompatible with writing from a
// compute shader? That sounds like a silly restriction.
//
// It might be possible to copy between textures with a copy command.
//
// The tutorial created textures in a heap. I won't need to do that, because
// the DXGI API supplies me with drawable textures.
//
// I'll have to implement triple buffering somehow. Perhaps with a fence that
// *isn't* the fence used internally during 'CommandQueue.flush()'.

// I'll have to come back to this another day, with a fresh mindset, to make
// more progress.
//
// Let's understand the swapchain before exploring whether textures can be
// backed with buffers. I feel more comfortable with exploring this order of
// priorities.



// Notes on the 1st 3DGEP tutorial:
//
// DXGI 1.6 adds functionality in order to detect HDR displays.
//
// 'chrono::high_resolution_clock' is used to perform timing in between calls
// to the 'Update' function.
//
// 'Vsync' is referenced in the file 'Window.h' from the tutorial's repository.
//
// The swap chain uses 3 back buffers.
//
// Windows Advanced Rasterization Platform is not used.
//
// Notable DirectX API objects:
// - ID3D12Device2
// - IDXGISwapChain4
// - ID3D12Resource g_BackBuffers[3]
// - ID3D12DescriptorHeap
//
// Although the back buffers of the swap chain are actually textures, all
// buffer and texture resources are referenced using the 'ID3D12Resource'
// interface in DirectX 12.
//
// The tutorial uses RTVs to clear the back buffers of the render target. The
// RTVs are created in descriptor heaps, and they describe instances of
// 'ID3D12Resource' that reside in GPU memory.
//
// A view in DirectX 12 is also called a descriptor. One descriptor is needed
// to describe each back buffer texture. The RTVs for the back buffers are
// stored in a descriptor heap.
//
// You must query the size of a descriptor in a descriptor heap. It may vary
// depending on the vendor.
//
// The index of the current back buffer in the swap chain may not be
// sequential (???).
//
// Method of GPU synchronization:
// - ID3D12Fence fence
// - uint64_t fenceValue
//   - The next fence value to signal the command queue.
// - uint64_t frameFenceValues[3]
//   - Keeps track of the fence values that were used to signal the command
//     queue for a particular frame. Guarantees that any resources still being
//     referenced by the command queue are not overwritten.
// - HANDLE fenceEvent
//
// VSync and tearing can be toggled. Use windowed instead of fullscreen mode.
//
// By default, the swap chain's present method will block (???) until the next
// vertical refresh of the screen.
//
// Some displays support 'variable refresh rates', which has implications for
// Vsync.
//
// A callback function is used to register the window class.



// Next region of the tutorial: description of the OS windowing API.
//
// Do not create an icon (HICON) for my application. Leave it as the OS default
// icon, all the way through production. I will create an application that
// generalizes beyond the myriad permutations for company names and company
// logos.
//
// There is a cursor class specified in WNDCLASSEXW. For the foreseeable future,
// I prefer to avoid any GUI functionality besides Ctrl+W to close the window.
// The current macOS implementation does not reference mouse events.
//
// The tutorial makes an effort to measure the screen dimensions and center the
// window. The macOS code does this as well. I don't know if Windows has the
// issue of falsifying screen dimensions to satisfy OS text scale factors. My
// PC uses 150%.
//
// A good starting point is to work with the OS-specific APIs for querying
// screen properties.
//
// I don't know what a 'class atom' is.
//
// 'CW_USEDEFAULT' is mentioned multiple times. I do not know how important
// it is.
//
// A window is first created. Then the DirectX resources are created. Finally,
// the window is shown.



// Next region of the tutorial: creation of DXGI resources.
//
// 'DXGI_CREATE_FACTORY_DEBUG' should supposedly be omitted in 'production
// builds'.
//
// It seems that both WARP and non-WARP adapters apply equally to
// 'IDXGIAdapter1' and 'IDXGIAdapter4'.
//
// The tutorial uses the heuristic of selecting the GPU with the largest memory,
// just like my code. Generally speaking, the GPU with the largest amount of
// dedicated video memory is a good indicator of GPU performance. Perhaps
// integrated GPUs have access to significant memory, but it isn't
// "dedicated memory".
//
// Variable refresh-rate displays require tearing (vsync-off) for an app to
// function correctly. I am testing on a fixed refresh-rate display. Tearing
// support was introduced in DXGI 1.5. The tutorial queries whether a computer
// supports tearing. I will not add any explicit support for variable refresh
// rate displays on Windows.
//
// 'IDXGISwapChain' exists, and it has an instance member, 'Present'.
//
// Upon 'Present', the swap chain increments everything in a ring buffer of
// pointers.
//
// 'FLIP_SEQUENTIAL' looks simpler. Presentation lag shouldn't exist if buffers
// are properly guarded with a 3-frame semaphore? This may need to be rigorously
// tested. Or perhaps latency heuristics guarantee it won't cause problems. The
// tutorial uses 'FLIP_DISCARD'.
//
// From the Microsoft docs, 'FLIP_DISCARD' may permit certain optimizations in
// the driver that reduce the amount of copying. These optimizations apply when
// the app is not the only window on the screen (not in fullscreen mode).
//
// The tutorial appears to initialize the 'IDXGIFactory4' multiple times. These
// initializations are redundant, but could be important for encapsulating code.
//
// The back buffer's pixel format is specified in 'DXGI_SWAP_CHAIN_DESC1'.
// 'DXGI_SWAP_CHAIN_DESC' also allows the pixel format to be specified. And it
// is the only one that lets you specify the refresh rate. However, this one
// has been deprecated since DirectX 11.1.
//
// Another thing to note: on Mac, I can test setups with multiple displays,
// and automatically choose the one with the fastest refresh rate. On Windows,
// I cannot test such a feature.
//
// 'IDXGIFactory2::CreateSwapChainForHwnd' requires the swap chain descriptor
// to be 'DXGI_SWAP_CHAIN_DESC1'.
//
// 'ALT' + 'ENTER' can force a window to fullscreen. I don't want that for my
// use case. There is a way to prevent that from happening.
//
// The tutorial uses 'ClearRenderTargetView', but one can probably get away
// with 'ClearUnorderedAccessViewXxx'. It's still not clear whether the back
// buffer's resource can be set to a buffer instead of a texture.
//
// 'Present' should use a sync interval of 1.
//
// The tutorial issues a 'Signal' between 'ExecuteCommandLists' and 'Present'.
// My existing helper class makes this use case impossible. Except... the fence
// inside this utility is not the fence for triple-buffer semaphores. So it is
// not a concern.



// Window Message Procedure
//
// Events:
// - Repaint a portion of the window's contents.
// - Respond to key presses when the window is in focus.
// - Respond to resize events (which shouldn't happen for my application).
//
// Not fixing the annoying sound in response to SYSCHAR. But what is the sound?
// It's the standard Windows error chime.
//
// It is important to respond to WM_DESTROY. Call 'PostQuitMessage(0)', which
// terminates the current process. It may be similar to 'exit(0)' on macOS.
// Both 'PostQuitMessage' and 'exit' exist on Windows, but the former doesn't
// actually terminate the application. It looks reasonable to just call
// 'exit(0)' on Windows.
//
// I wonder what happens if I don't call 'DefWindowProc' for messages that
// aren't relevant. There should be nothing wrong with skipping this function
// call.

// SetThreadDpiAwarenessContext
//
// The documentation mentions 'DPI_AWARENESS_CONTEXT' and 'DPI_AWARENESS'. But
// it seems that only 'DPI_AWARENESS_CONTEXT' has any relevance.
//
// What is the old 'dpiContext' returned on my computer?
// existing             0x0000000080006010
// UNAWARE              0x0000000000006010
// SYSTEM_AWARE         0x0000000000009011
// PER_MONITOR_AWARE    0x0000000000000012
// PER_MONITOR_AWARE_V2 0x0000000000000022
// UNAWARE_GDISCALED    0x0000000040006010
//
// The pointer passed out does not equal the pointer entered in. It doesn't
// even correspond to the input pointer arithmetically. I would expect it to be
// UInt64.max - (input pointer).
//
// DPI_AWARENESS_CONTEXT = UnsafeMutablePointer<DPI_AWARENESS_CONTEXT__>
// DPI_AWARENESS_CONTEXT = struct type, has property 'unused' of type Int32
// DPI_AWARENESS = enumeration, has raw value of type Int32



#endif
