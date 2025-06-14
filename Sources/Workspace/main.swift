// Next steps:
// - Get frame ID synchronization correct on Windows.
//   - See whether Microsoft lets you query the next "video" timestamp,
//     compared to the "host" timestamp, like with Apple CoreVideo. [DONE]
//   - Inspect all of the following APIs:
//     - IDXGISwapChain::GetContainingOutput [DONE]
//     - IDXGIAdapter::EnumOutputs [DONE]
//     - IDXGIOutput::GetDisplayModeList [DONE]
//       - Find the highest display resolution available.
//       - Reject all modes with lower resolution.
//       - Find the highest refresh rate available.
//     - IDXGISwapChain::GetFrameStatistics
//       - DXGI_FRAME_STATISTICS.PresentCount
//       - DXGI_FRAME_STATISTICS.PresentRefreshCount
//       - DXGI_FRAME_STATISTICS.SyncRefreshCount
//       - DXGI_FRAME_STATISTICS.SyncQPCTime
//   - Inspect the consistency of time tracking during the first few frames,
//     where 'GetFrameStatistics()' doesn't return anything.
//     - PresentCount always starts from 0, then going to a very small integer
//       (<10) and increasing afterward. Always assert that this is the case,
//       and it doesn't reflect number of frames since the computer booted.
//     - Spacing between calls to 'renderFrame()' stabilizes after the
//       frame statistics shows PresentCount = 2.
//     - Until this stabilization happens, clamp 'clock.frames' to the host
//       timestamp, rounded toward negative infinity.
//   - Inspect the consistency when PresentCount between two successive frames
//     differs by a number other than 1.
//     - The "catching up" phenomenon from the first few frames also occurs
//       after every jitter. I do not recall seeing this behavior on macOS.
//     - The time delta from GetFrameStatistics matches the time delta from
//       measured CPU time.
//       - If there was a long wait between the current and previous calls to
//         'renderFrame()', that approximately shows up in frame statistics.
//       - If the present queue is "catching up", the frame statistics shows
//         that zero refresh intervals passed since the last frame.
//   - PresentCount gradually lags behind PresentRefreshCount and
//     SyncRefreshCount.
//     - When the between-frame deltas conflict, PresentRefreshCount and
//       SyncRefreshCount consistently agree with SyncQPCTime.
//   - While the app's counter for number of 'renderFrame' invocations
//     generally starts out ahead of 'startTime', it eventually falls behind
//     due to dropped frames.
//   - After the initialization strangeness, 'startTime' and the last 3
//     members of the frame statistics are perfectly synchronized.
//     - For a brief moment, in the middle of a stutter, they may fall out of
//       sync. But they catch back up perfectly.
//     - Major (+1 frames) desynchronization during a stutter is not the norm.
//       I only observed it during one 5-frame stutter, in a program launch
//       with ~10 total stutters.
//   - Spacing between consecutive frames when "catching up":
//     - At program startup: 0.2-0.5 frames
//     - Jitters after startup: 0.05-0.1 frames
// - Purge the 'main.swift' file.
// - Revise how the window and swap chain are initialized, ensuring the window
//   always appears on the monitor with the highest refresh rate.
//   - Reference article: Microsoft documentation, "Positioning Objects on
//     Multiple Display Monitors"
//   - We need to inspect more functions to find the fastest monitor in a
//     multi-display system. This might be independent of the ID3D12Device,
//     removing the dependency of 'Display' on 'Device'.
// - Merge the macOS and Windows implementations of Clock.

import MolecularRenderer

#if os(macOS)
import Metal

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.renderTargetSize = 1920
  displayDesc.screenID = Display.fastestScreenID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  let application = Application(descriptor: applicationDesc)
  
  return application
}

func createShaderSource() -> String {
  """
  
  #include <metal_stdlib>
  using namespace metal;
  
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
  
  kernel void renderImage(
    constant TimeArguments &timeArgs [[buffer(0)]],
    texture2d<float, access::write> frameBuffer [[texture(1)]],
    uint2 tid [[thread_position_in_grid]]
  ) {
    // Query the screen's dimensions.
    uint screenWidth = frameBuffer.get_width();
    uint screenHeight = frameBuffer.get_height();
    
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
    frameBuffer.write(color, tid);
  }
  
  """
}

// Set up the application.
let application = createApplication()

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.device = application.device
shaderDesc.name = "renderImage"
shaderDesc.source = createShaderSource()
shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
let shader = Shader(descriptor: shaderDesc)

// Define the state variables.
var startTime: UInt64?

// Enter the run loop.
application.run { renderTarget in
  application.device.commandQueue.withCommandList { commandList in
    // Utility function for calculating progress values.
    var times: SIMD3<Float> = .zero
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - floor(time)
      times[index] = Float(fractionalTime)
    }
    
    // Write the absolute time.
    if let startTime {
      let currentTime = mach_continuous_time()
      let timeSeconds = Double(currentTime - startTime) / 24_000_000
      setTime(timeSeconds, index: 0)
    } else {
      startTime = mach_continuous_time()
      setTime(Double.zero, index: 0)
    }
    
    // Write the time according to the counter.
    do {
      let clock = application.clock
      let timeInFrames = clock.frames
      let framesPerSecond = application.display.frameRate
      let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
      setTime(timeInSeconds, index: 1)
      setTime(Double.zero, index: 2)
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
      commandList.set32BitConstants(timeArgs, index: 0)
      commandList.mtlCommandEncoder
        .setTexture(renderTarget, index: 1)
      
      let groups = SIMD3<UInt32>(
        UInt32(renderTarget.width) / 8,
        UInt32(renderTarget.height) / 8,
        1)
      commandList.dispatch(groups: groups)
    }
  }
}

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

let window = Application.global.window
ShowWindow(window, SW_SHOW)

// Invoke the game loop.
SetPriorityClass(GetCurrentProcess(), UInt32(HIGH_PRIORITY_CLASS))
while true {
  var message = MSG()
  let peekMessageOutput = PeekMessageA(
    &message, // lpMsg
    nil, // hWnd
    0, // wMsgFilterMin
    0, // wMsgFilterMax
    UInt32(PM_REMOVE)) // wRemoveMsg
  
  if message.message == WM_QUIT {
    break
  } else if peekMessageOutput {
    TranslateMessage(&message)
    DispatchMessageA(&message)
  }
}

#endif

// Plans for Clock implementation on Windows: the heuristic
//
// Ignore all properties of the frame statistics except PresentCount.
//
// ## Issue of several 0-frames
//
// Cannot afford to flood the GPU timeline with "catching up" frames.
//
// macOS almost never deals with 0-frame steps, especially not several in a
// row. This warrants modifications to the timekeeping algorithm.
//
// Start out with a timekeeping algorithm that processes 0-frames just as
// normal. Then, introduce intentional delays into the render loop via
// usleep(...).
//
// # Lack of data at program start
//
// There should be a state variable that's 'true' upon initialization, but set
// to 'false' upon encountering frame statistics with PresentCount >= 2.
//
// A guard statement should ensure the first non-zero present count is less
// than or equal to 3.
//
// Follow the CPU time exactly, rounding it down. This technique would
// produce lots of jitter in a real-time application as fractional parts of
// numbers jostled across '.000'.
// - Adds intentional 0-frames or jumps much larger than 1 frame, depending
//   on the nature of CPU time samples.
//
// # Other
//
// Follow the macOS implementation very closely, porting it line-by-line.
// Begin with a class in 'Workspace'. Gradually migrate related time-tracking
// data and utilities from 'Application'. Eventually, it will look similar to
// macOS and be ready for migration into the utility library.
//
// Use the Clock utility as the 3rd data stream in the rendering demo, along
// with the actual CPU time (tracked independently from Clock's host
// time stamp) and a naive frame counter.
//
// Start out by not incorporating the special cases for program startup or
// streams of 0-frames. The robust algorithm from macOS should stabilize the
// application; these are just touch-ups.

// # Notes
//
// The macOS algorithms is remarkably good at stabilizing the application's
// time keeping. However, both streams of 0-frames produce a noticeable blank
// or flash in the animation. This happens both at app startup and during the
// jitters later on.
//
// Hypothesis: The proposed heuristic components for startup should mend the
// flash artifact there.
//
// Start by adding a way to inspect the frame statistics, and check whether we
// have crossed over the initialization period.
//
// I've fixed the issues with program startup.

// # 0-frame catchups after startup
//
// General idea:
// - Increase the host time by actually waiting
// - Increase the GPU time artificially
// - Host and GPU time stay in alignment
//
// Is there a better approach?
// - We don't want to actually wait, because that causes missed opportunities
//   to fill in gaps in the GPU timeline.
// - We don't want to enter an unstable loop where CPU time increases by
//   more than 1 frame/frame.
//
// What's going on with Microsoft frame latency waitable object?
// - Seems like a good idea to try.
// - Read over the sample code for "DirectX latency sample".

// # Altered Run Loop Structure
//
// Messages received before program start:
// 1
// 3
// 6
// 7
// 20
// 24
// 28
// 36
// 70
// 71
// 127
// 129
// 131
// 133
// 134
// 641
// 642
// WM_SIZE
//
// Messages forwarded by run loop:
// 160
// 161
// 256 (translated)
// 257 (translated)
// 258
// 512
// 513
// 514
// 674
// 799
// 49419
// WM_PAINT
//
// Messages unique to run loop:
// 18
// 96
//
// Messages unique to WndProc:
// 3
// 6
// 8
// 16
// 20
// 28
// 32
// 36
// 70
// 71
// 127
// 130
// 132
// 133
// 134
// 144
// 274
// 533
// 534
// 561
// 641
// 642
// 674
// WM_DESTROY

// Most stable run loop structure:
//
// The freezing issue during window move disappears when I invoke
// 'renderFrame()' in the message procedure, in response to WM_MOVE. However,
// there is an increased rate of dropped frames. I might be able to solve this
// by finding and selecting more specific messages to handle. However, this
// effort would get quite tedious.
//
// A better approach is to just re-poll PeekMessageA after the latency waitable
// object. The messages polled here include all keyboard events. Just stop
// looking when you encounter WM_PAINT.
//
// Next step:
//
// Is it even legal to call PeekMessageA inside of WndProc?
//
// It is legal, and does not increase the number of frames dropped.

// paminerva.github.io was the website I was looking for!

// ## Startup with no waitable object
//
// 0 0 0 0
// 1 0 0 0
// 1 0 0 0
// 2 0 1 0
// 2 1 2 1
// 3 2 3 1
// 4 3 4 1
// 5 4 5 1
// 6 5 6 1
// 7 6 7 1
// 8 7 8 1
// 9 8 9 1
// 10 9 10 1
//
// 0 0 0 0
// 2 0 1 0
// 2 1 2 1
// 2 2 2 0
// 2 2 2 0
// 3 2 3 1
// 4 3 4 1
// 5 4 5 1
// 6 5 6 1
// 7 6 7 1
// 8 7 8 1
// 9 8 9 1
// 10 9 10 1
//
// 0 0 0 0
// 1 0 0 0
// 1 0 0 0
// 1 0 0 0
// 2 0 1 1
// 2 1 2 1
// 3 2 3 1
// 4 3 4 1
// 5 4 5 1
// 6 5 6 1
// 7 6 7 1
// 8 7 8 1
// 9 8 9 1
// 10 9 10 1

// Startup with maximum latency of 2
//
// 0 0 0 0
// 1 0 0 0
// 2 0 1 1
// 3 1 2 1
// 4 2 3 1
// 5 3 4 1
// 6 4 5 1
// 7 5 6 1
// 8 6 7 1
// 9 7 8 1
// 10 8 9 1
// 11 9 10 1
//
// 0 0 0 0
// 1 0 0 0
// 1 0 1 1
// 2 1 2 1
// 3 2 3 1
// 4 3 4 1
// 5 4 5 1
// 6 5 6 1
// 7 6 7 1
// 8 7 8 1
// 9 8 9 1
// 10 9 10 1
//
// 0 0 0 0
// 1 0 0 0
// 2 0 1 1
// 3 1 2 1
// 4 2 3 1
// 5 3 4 1
// 6 4 5 1
// 7 5 6 1
// 8 6 7 1
// 9 7 8 1
// 10 8 9 1
// 11 9 10 1

// Startup with maximum latency of 1
//
// 1 0 0 0
// 2 0 1 1
// 3 1 2 1
// 4 2 3 1
// 8 3 6 1
// 11 6 9 1
// 13 9 11 1
//
// 1 0 0 0
// 2 0 1 1
// 3 1 2 1
// 4 2 3 1
// 5 3 4 1
// 6 4 5 1
// 7 5 6 1
// 8 6 7 1
// 9 7 8 1
// 10 8 9 1
// 11 9 10 1
//
// 1 0 0 0
// 2 0 1 1
// 3 1 2 1
// 4 2 3 1
// 5 3 4 1
// 6 4 5 1
// 7 5 6 1
// 8 6 7 1
// 9 7 8 1
// 10 8 9 1
// 11 9 10 1
