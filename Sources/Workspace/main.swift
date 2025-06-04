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



// Tomorrow, with a fresh mindset, I can do something about this. Start by
// inspecting the functions that report screen properties.
//
// Screen dimensions with different awareness contexts:
// existing             2560x1440
// UNAWARE              2560x1440
// SYSTEM_AWARE         3840x2160
// PER_MONITOR_AWARE    3840x2160
// PER_MONITOR_AWARE_V2 3840x2160
// UNAWARE_GDISCALED    2560x1440

SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

// TODO: Set the Window name on macOS to match the one on Windows? Or reserve
// that GUI decision to one that generalizes to custom UIs. For now, just copy
// the names from the 3DGEP tutorial.
//
// I learned something interesting. Some OS functions have two variants, one
// suffixed with "A" and the other suffixed with "ExW/EXW". The former employs
// strings with 8-bit characters. The latter employs strings with 16-bit
// characters.
//
// Wait...there might be distinct concerns here:
// - "A" vs "W"
// - "Ex" vs not "Ex"
// - 32-bit vs 64-bit operating systems
//
// typedef struct tagWNDCLASSA {
//   UINT      style;
//   WNDPROC   lpfnWndProc;
//   int       cbClsExtra;
//   int       cbWndExtra;
//   HINSTANCE hInstance;
//   HICON     hIcon;
//   HCURSOR   hCursor;
//   HBRUSH    hbrBackground;
//   LPCSTR    lpszMenuName;
//   LPCSTR    lpszClassName;
// } WNDCLASSA, *PWNDCLASSA, *NPWNDCLASSA, *LPWNDCLASSA;
//
// typedef struct tagWNDCLASSEXA {
//   UINT      cbSize;
//   UINT      style;
//   WNDPROC   lpfnWndProc;
//   int       cbClsExtra;
//   int       cbWndExtra;
//   HINSTANCE hInstance;
//   HICON     hIcon;
//   HCURSOR   hCursor;
//   HBRUSH    hbrBackground;
//   LPCSTR    lpszMenuName;
//   LPCSTR    lpszClassName;
//   HICON     hIconSm;
// } WNDCLASSEXA, *PWNDCLASSEXA, *NPWNDCLASSEXA, *LPWNDCLASSEXA;
//
// The "ATOM" return type is a 16-bit integer. The user can't do anything with
// the value, except check that it's not 0.
//
// HWND CreateWindowA(
//   [in, optional] LPCSTR    lpClassName,
//   [in, optional] LPCSTR    lpWindowName,
//   [in]           DWORD     dwStyle,
//   [in]           int       x,
//   [in]           int       y,
//   [in]           int       nWidth,
//   [in]           int       nHeight,
//   [in, optional] HWND      hWndParent,
//   [in, optional] HMENU     hMenu,
//   [in, optional] HINSTANCE hInstance,
//   [in, optional] LPVOID    lpParam
// );
//
// HWND CreateWindowExA(
//   [in]           DWORD     dwExStyle,
//   [in, optional] LPCSTR    lpClassName,
//   [in, optional] LPCSTR    lpWindowName,
//   [in]           DWORD     dwStyle,
//   [in]           int       X,
//   [in]           int       Y,
//   [in]           int       nWidth,
//   [in]           int       nHeight,
//   [in, optional] HWND      hWndParent,
//   [in, optional] HMENU     hMenu,
//   [in, optional] HINSTANCE hInstance,
//   [in, optional] LPVOID    lpParam
// );

// Choices for 'WNDCLASS':
//
// Use 'WNDCLASSEX' instead of 'WNDCLASS'.
// Use 'A' instead of 'W'.
//
// cbSize = sizeof(WNDCLASSEXA)
// style = 0
// lpfnWndProc = TODO
// hInstance = TODO
// hIcon = nullptr
// hCursor = LoadCursor(nullptr, IDC_ARROW)
// hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW + 1))
// lpszClassName = "DX12WindowClass"
// hSmIcon = nullptr
//
// In the default initializer for the struct, everything is initialized to 0.
// The code can be made shorter by just not mentioning these members.
//
// There is an issue with the HINSTANCE. When I use the instance from the
// Workspace executable, it will be different than when the function is
// encapsulated in a library. Try setting 'hInstance' to 'nullptr' for now.
//
// #define MAKEINTRESOURCEA(i) ((LPSTR)((ULONG_PTR)((WORD)(i))))
// #define IDC_ARROW           MAKEINTRESOURCE(32512)

func messageProcedure(
  hwnd: HWND?,
  message: UInt32,
  wParam: WPARAM,
  lParam: LPARAM
) -> LRESULT {
  print("Called the message procedure with message code \(message).")
  
  // Defer to the OS default function.
  return DefWindowProcA(hwnd, message, wParam, lParam)
}

// WARNING: Captures 'messageProcedure' from the outer scope. Encapsulate this
// better when you migrate this to the helper library.
//
// Leaving all of the null variables explicitly initialized, to ease the pain
// of explicitly checking them when tracing down a bug.
func registerWindowClass(name: String) {
  // Specify the first few parameters of the window class descriptor.
  var windowClass = WNDCLASSEXA()
  windowClass.cbSize = UInt32(MemoryLayout<WNDCLASSEXA>.stride)
  windowClass.style = UInt32(CS_HREDRAW | CS_VREDRAW)
  windowClass.lpfnWndProc = messageProcedure
  windowClass.cbClsExtra = 0
  windowClass.cbWndExtra = 0
  windowClass.hInstance = nil
  
  // Generate the cursor object.
  let cursorName = UnsafeMutablePointer<Int8>(bitPattern: UInt(32512))
  let cursor = LoadCursorA(nil, cursorName)
  windowClass.hCursor = cursor
  windowClass.hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW + 1))
  
  // Set the icon properties.
  let iconName = UnsafeMutablePointer<Int8>(bitPattern: UInt(32512))
  let icon = LoadIconA(nil, iconName)
  windowClass.hIcon = icon
  windowClass.hIconSm = icon
  
  // 'RegisterClassExA' must be called within the same scope where the cString
  // pointer exists. Otherwise, cString becomes a zombie pointer and the
  // function fails with error code 123.
  name.withCString { cString in
    windowClass.lpszMenuName = nil
    windowClass.lpszClassName = cString
    
    let atom = RegisterClassExA(&windowClass)
    guard atom > 0 else {
      let errorCode = GetLastError()
      fatalError(
        "Could not create window class. Received error code \(errorCode).")
    }
  }
}
registerWindowClass(name: "DX12WindowClass")

// This worked. Next, create the window.
//
// OVERLAPPEDWINDOW is a combination of styles.
// - OVERLAPPED: top-level window, application's main window
// - CAPTION: has a title bar
// - SYSMENU: perhaps something only visible upon pressing ALT + SPACE? I don't
//   want 'File', 'Edit', etc. to show. If this is a pop-up window, hopefully
//   it is a temporary window.
// - THICKFRAME: has a sizing border. I want to eliminate this, because the
//   user should not be able to resize the window. Perhaps keep the border for
//   now, to identify all possible sources of resizing events. A window must
//   have CAPTION or THICKFRAME to receive a WM_GETMINMAXINFO message.
// - WS_MINIMIZEBOX: the title bar has a minimize button. This option can only
//   be specified if SYSMENU is also specified.
// - WS_MAXIMIZEBOX: the title bar has a maximize button. This option can only
//   be specified if SYSMENU is also specified. I don't want the user to be
//   able to enlarge the window to fullscreen / near-fullscreen. Keep this
//   option available and diagnose it as a source of resize events. Also, try
//   to keep consistency with the window structure on macOS.
//
// dwExStyle = 0
// windowClassName = "DX12WindowClass"
// windowTitle = "Learning DirectX 12"
// dwStyle = WS_OVERLAPPEDWINDOW
// X = defined in other code (TODO)
// Y = defined in other code (TODO)
// windowWidth = defined in other code (TODO)
// windowHeight = defined in other code (TODO)
// hWndParent = NULL
// hMenu = NULL
// hInstance = TODO
// lpParam = nullptr
//
// Interesting note: 'NULL' is not exactly the same as 'nullptr'. NULL is a
// macro that substitutes for the value '0'. It could apply to any integer
// type. Meanwhile, nullptr applies exclusively to pointer types.

// Returns the window size and position.
// Lane 0: x
// Lane 1: y
// Lane 2: width
// Lane 3: height
func createWindowDimensions() -> SIMD4<UInt32> {
  // (3840, 2160)
  let screenWidth = Int32(GetSystemMetrics(SM_CXSCREEN))
  let screenHeight = Int32(GetSystemMetrics(SM_CYSCREEN))
  
  // (0, 0, 1440, 1440) -> (-11, -45, 1451, 1451)
  var windowRect = RECT()
  windowRect.left = 0
  windowRect.top = 0
  windowRect.right = 1440
  windowRect.bottom = 1440
  AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, false)
  
  // (1462, 1496)
  let windowSizeX = Int32(windowRect.right - windowRect.left)
  let windowSizeY = Int32(windowRect.bottom - windowRect.top)
  
  // (1920, 1080)
  let centerX = screenWidth / 2
  let centerY = screenHeight / 2
  
  // (1189, 332)
  let leftX = centerX - windowSizeX / 2
  let upperY = centerY - windowSizeY / 2
  
  // Not clamping because we don't do this on Mac either. Instead, crashing if
  // we detect an out-of-bounds error. May remove this check in the future. It
  // feels fair to also check if the bottom right corner is out of bounds, but
  // that goes beyond the spirit of the 3DGEP tutorial.
  guard leftX >= 0,
        upperY >= 0 else {
    fatalError("Window origin was out of bounds.")
  }
  
  let outputSigned = SIMD4<Int32>(
    leftX, upperY, windowSizeX, windowSizeY)
  let outputUnsigned = SIMD4<UInt32>(
    truncatingIfNeeded: outputSigned)
  return outputUnsigned
}



struct WindowDescriptor {
  var className: String?
  var title: String?
  var dimensions: SIMD4<UInt32>?
}

func createWindow(descriptor: WindowDescriptor) -> HWND {
  guard let className = descriptor.className,
        let title = descriptor.title,
        let dimensions = descriptor.dimensions else {
    fatalError("Descriptor was incomplete.")
  }
  
  let output = CreateWindowExA(
    0, // dwExStyle
    className, // lpClassName
    title, // lpWindowName
    WS_OVERLAPPEDWINDOW, // dwStyle
    Int32(dimensions[0]), // X
    Int32(dimensions[1]), // Y
    Int32(dimensions[2]), // nWidth
    Int32(dimensions[3]), // nHeight
    nil, // hWndParent
    nil, // hMenu
    nil, // hInstance
    nil) // lpParam
  
  guard let output else {
    let errorCode = GetLastError()
    fatalError(
      "Failed to create window. Received error code \(errorCode).")
  }
  return output
}

// Test the window creation procedure.
var windowDesc = WindowDescriptor()
windowDesc.className = "DX12WindowClass"
windowDesc.title = "Learning DirectX 12"
windowDesc.dimensions = createWindowDimensions()
let window = createWindow(descriptor: windowDesc)



// I think the next task is setting up the swap chain.

struct SwapChainDescriptor {
  var commandQueue: CommandQueue?
  var window: HWND?
}

func createSwapChain(
  descriptor: SwapChainDescriptor
) -> SwiftCOM.IDXGISwapChain4? {
  guard let commandQueue = descriptor.commandQueue,
        let window = descriptor.window else {
    fatalError("Descriptor was incomplete.")
  }
  
  // Instantiate the factory.
  let factory: SwiftCOM.IDXGIFactory4 =
    try! CreateDXGIFactory2(UInt32(DXGI_CREATE_FACTORY_DEBUG))
  
  // Fill the swap chain descriptor.
  var swapChainDesc = DXGI_SWAP_CHAIN_DESC1()
  swapChainDesc.Width = 1440
  swapChainDesc.Height = 1440
  swapChainDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM
  swapChainDesc.Stereo = false
  
  // Specify the multisampling descriptor.
  var sampleDesc = DXGI_SAMPLE_DESC()
  sampleDesc.Count = 1
  sampleDesc.Quality = 0
  swapChainDesc.SampleDesc = sampleDesc
  
  // Compute-centric workflow: write to a custom UAV resource in the shader,
  // copy to the back buffer with 'ID3D12GraphicsCommandList::CopyResource'.
  //
  // https://stackoverflow.com/a/78501260
  swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
  swapChainDesc.BufferCount = 3
  swapChainDesc.Scaling = DXGI_SCALING_NONE
  
  // I'm choosing flip discard, although I'm still troubled over whether this
  // is the option I want.
  swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD
  
  // I'm also troubled over the best option for the alpha mode.
  swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED
  swapChainDesc.Flags = 0
  
  // Get the swap chain as 'IDXGISwapChain1'.
  var swapChain1: SwiftCOM.IDXGISwapChain1
  swapChain1 = try! factory.CreateSwapChainForHwnd(
    commandQueue.d3d12CommandQueue, // pDevice
    window, // hWnd
    swapChainDesc, // pDesc
    nil, // pFullscreenDesc,
    nil) // pRestrictToOutput
  print(swapChain1)
  
  // Perform a cast using 'IUnknown::QueryInterface'.
  var swapChain4: SwiftCOM.IDXGISwapChain4
  swapChain4 = try! swapChain1.QueryInterface()
  return swapChain4
}



// List all of the DXGI debug IDs for reference.
let dxgiDebugIDs: [DXGI_DEBUG_ID] = [
  //DXGI_DEBUG_ALL,
  //DXGI_DEBUG_DX,
  DXGI_DEBUG_DXGI,
  //DXGI_DEBUG_APP,
  //DXGI_DEBUG_D3D11
]

// Create the device.
let device = Device()
let infoQueue = device.d3d12InfoQueue
try! infoQueue.ClearStorageFilter()

// Initialize the DXGI info queue.
var infoQueue2: SwiftCOM.IDXGIInfoQueue
infoQueue2 = try! DXGIGetDebugInterface1(0)
try! infoQueue2.SetBreakOnSeverity(
  DXGI_DEBUG_DXGI, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true)

// Create the command queue.
var commandQueueDescriptor = CommandQueueDescriptor()
commandQueueDescriptor.device = device
let commandQueue = CommandQueue(descriptor: commandQueueDescriptor)

// Create the swap chain.
var swapChainDesc = SwapChainDescriptor()
swapChainDesc.commandQueue = commandQueue
swapChainDesc.window = window
let swapChain = createSwapChain(descriptor: swapChainDesc)

#if false

// MARK: - Section 1 of Implemented Methods

print()
print(try! infoQueue.GetRetrievalFilterStackSize())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetRetrievalFilterStackSize(dxgiDebugID))
}

print()
print(try! infoQueue.GetStorageFilterStackSize())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetStorageFilterStackSize(dxgiDebugID))
}

print()
print(try! infoQueue.GetMessageCountLimit())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetMessageCountLimit(dxgiDebugID))
}

print()
print(try! infoQueue.GetMuteDebugOutput())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetMuteDebugOutput(dxgiDebugID))
}

// MARK: - Section 2 of Implemented Methods

print()
print("Start of Section 2")

print()
print(try! infoQueue.GetNumMessagesAllowedByStorageFilter())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetNumMessagesAllowedByStorageFilter(dxgiDebugID))
}

print()
print(try! infoQueue.GetNumMessagesDeniedByStorageFilter())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetNumMessagesDeniedByStorageFilter(dxgiDebugID))
}

print()
print(try! infoQueue.GetNumStoredMessages())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetNumStoredMessages(dxgiDebugID))
}

print()
print(try! infoQueue.GetNumStoredMessagesAllowedByRetrievalFilter())
for dxgiDebugID in dxgiDebugIDs {
  print("-", try! infoQueue2.GetNumStoredMessagesAllowedByRetrievalFilters(dxgiDebugID))
}

print()
print("End of Section 2")

// Next task:
// Test whether the info queue catches the errors for IDXGISwapChain.

#endif



#if false

// Show the debug messages.
do {
  let messageCount = try! infoQueue.GetNumStoredMessages()
  for messageID in 0..<messageCount {
    let message =
    try! infoQueue.GetMessage(UInt64(messageID))
    print("messages[\(messageID)]:")
    print("- category:", message.pointee.Category)
    print("- severity:", message.pointee.Severity)
    print("- ID:", message.pointee.ID)
    
    let description = String(cString: message.pointee.pDescription)
    print("- description:", description)
    print("- byte length:", message.pointee.DescriptionByteLength)
    
    free(message)
  }
}

#endif

#if false

for dxgiDebugID in dxgiDebugIDs {
  print("DXGI debug ID: \(dxgiDebugID)")
  
  let messageCount = try! infoQueue2.GetNumStoredMessages(dxgiDebugID)
  for messageID in 0..<messageCount {
    let message =
    try! infoQueue2.GetMessage(dxgiDebugID, UInt64(messageID))
    print("- messages[\(messageID)]:")
    print("  - category:", message.pointee.Category)
    print("  - severity:", message.pointee.Severity)
    print("  - ID:", message.pointee.ID)
    
    let description = String(cString: message.pointee.pDescription)
    print("  - description:", description)
    print("  - byte length:", message.pointee.DescriptionByteLength)
    
    free(message)
  }
}

#endif



// Next steps:
// (1) Migrate 'IDXGIInfoQueue' to the fork of swift-com.
// (2) Continue developing the above code as-is, until the tutorial is finished.
// (3) Archive and purge 'main.swift' and 'VectorAddition.swift'.
// (4) Incorporate code handling 'HWND', 'IDXGISwapChain', and 'IDXGIInfoQueue'
//     into the helper library.

// Descriptor heap:
// - NumDescriptors: 3
// - Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV
func createDescriptorHeap(device: Device) -> SwiftCOM.ID3D12DescriptorHeap {
  // Fill the descriptor.
  var descriptorHeapDesc = D3D12_DESCRIPTOR_HEAP_DESC()
  descriptorHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV
  descriptorHeapDesc.NumDescriptors = 3
  descriptorHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE
  descriptorHeapDesc.NodeMask = 0
  
  // Create the descriptor heap.
  let d3d12Device = device.d3d12Device
  var descriptorHeap: SwiftCOM.ID3D12DescriptorHeap
  descriptorHeap = try! d3d12Device
    .CreateDescriptorHeap(descriptorHeapDesc)
  return descriptorHeap
}
let descriptorHeap = createDescriptorHeap(device: device)
print("descriptor heap:", descriptorHeap)

#endif
