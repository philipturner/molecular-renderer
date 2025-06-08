// Next steps:
// - Write the SwapChain utility for Windows.
// - Reproduce the 1st 3DGEP tutorial using empty render passes.
// - Reproduce the StackOverflow comment (https://stackoverflow.com/a/78501260)
//   about rendering with entirely compute commands.

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
  
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
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
  // Start the command list.
  let commandList = application.device.createCommandList()
  
  // Utility function for encoding constants.
  func setTime(_ time: Double, index: Int) {
    let fractionalTime = time - floor(time)
    var time32 = Float(fractionalTime)
    commandList.mtlCommandEncoder
      .setBytes(&time32, length: 4, index: index)
  }
  
  // Bind buffer 0.
  if let startTime {
    let currentTime = mach_continuous_time()
    let timeSeconds = Double(currentTime - startTime) / 24_000_000
    setTime(timeSeconds, index: 0)
  } else {
    startTime = mach_continuous_time()
    setTime(Double.zero, index: 0)
  }
  
  // Bind buffers 1 and 2.
  do {
    let clock = application.clock
    let timeInFrames = clock.frames
    let framesPerSecond = application.display.frameRate
    let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
    setTime(timeInSeconds, index: 1)
    setTime(Double.zero, index: 2)
  }
  
  // Bind the textures.
  commandList.mtlCommandEncoder
    .setTexture(renderTarget, index: 0)
  
  // Bind the pipeline state.
  commandList.setPipelineState(shader)
  
  // Encode the dispatch.
  let groups = SIMD3<UInt32>(
    UInt32(renderTarget.width) / 8,
    UInt32(renderTarget.height) / 8,
    1)
  commandList.dispatch(groups: groups)
  
  // End the command list.
  application.device.commit(commandList)
}

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

// Before proceeding, let's get a high-level understanding of the various API
// objects and their relationships. How should one organize them? I can
// "complete" the 3DGEP tutorial by just using its code as reference.
//
// Abstract goals and time-consuming API development are not helpful at this
// point. Look for little, specific things and unanswered questions. Don't add
// code to the helper library until it's needed for the current task.
//
// Periodically purge the main file in small bits, instead of all at once to a
// GitHub gist. That removes the need for any more tedious archival events.

// Should I create a helper class called 'Texture'?
//
// Answer: No, because the reference implementation
// (https://stackoverflow.com/a/78501260) just extracts the resource
// descriptor from a swapchain buffer. It might be tractable to keep the
// texture initialization code separate between Metal and DirectX.
//
// Rule of thumb: don't create utility code or "cross-platform abstractions"
// until the boilerplate gets so tedious that you need them. At that point,
// you'll probably be better informed about the optimal API form.

// Keep every API as 'class' by default, unless you absolutely need the mutable
// value semantics of 'struct' for API design. While the HDL defaults
// everything, including 'Lattice', to a 'struct', the default choice is
// different for MolecularRenderer.

let window = Application.global.window
ShowWindow(window, SW_SHOW)

// Invoke the game loop.
while true {
  var message = MSG()
  PeekMessageA(
    &message, // lpMsg
    nil, // hWnd
    0, // wMsgFilterMin
    0, // wMsgFilterMax
    UInt32(PM_REMOVE)) // wRemoveMsg
  
  if message.message == WM_QUIT {
    break
  } else {
    TranslateMessage(&message)
    DispatchMessageA(&message)
  }
}

// Source: https://github.com/walbourn/directx-vs-templates/blob/main/d3d12game_win32/Game.cpp
//
// The first argument instructs DXGI to block until VSync, putting the application
// to sleep until the next VSync. This ensures we don't waste any cycles rendering
// frames that will never be displayed to the screen.
// HRESULT hr = m_swapChain->Present(1, 0)
//
// The tutorial dispatches the GPU commands before it calls 'Present'. This is
// counterintuitive to macOS, where I might use a semaphore or Vsync callback
// preceding command encoding. And then return immediately after dispatching
// the GPU commands, without blocking.
//
// m_timer.Tick([&](){}); doesn't perform any blocking operations, or wait
// until an invocation of an interrupt running in the background. It just
// computes the internal timestamp for the physics engine.
//
// Walbourn calls g_game->Tick() any time PeekMessage returns 0. When the
// WM_PAINT message is called, nothing actually happens. But there's a dead
// branch of the code that calls game->Tick().

// Next: study the 3DGEP (both v1 and final repo state) and StackOverflow
// examples. Compare them to how the Walbourn example handles the run loop.

// StackOverflow example:
// - relies on glfw for some UI stuff
//
// Order of operations each runloop:
// - get the back buffer index
// - encode and submit the GPU commands
// - swapchain->Present(0, 0)
// - fence_value += 1
// - direct_command_queue->Signal(fence, fence_value)
// - fence->SetEventOnCompletion(fence_value, fence_event)
// - WaitForSingleObject(fence_event, INFINITE)
// - poll for events from glfw

// 3DGEP tutorial 1:
// - [to fill in]
// - submit the GPU commands
// - m_SwapChain->Present(value depends, value depends)
// - fenceValues[current backbuffer ID] = app.Signal()
// - current backbuffer ID = SwapChain->GetCurrentBackBufferIndex()
// - WaitForFenceValue(fenceValues[current backbuffer ID])

// Great source:
// https://paminerva.github.io/LearnDirectX/Tutorials/01-HelloWorld/hello-frame-buffering.html
//
// Use DXGI_SWAP_EFFECT_FLIP_DISCARD
//
// Underlying memory for command list objects is being synchronized with
// fences, but memory for swap chain buffers is being synchronized by the API
// and driver.
//
// This source copies off of:
// https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/Samples/Desktop/D3D12HelloWorld/src/HelloFrameBuffering
//
// Run loop structure:
// - loop on PeekMessage, but do nothing else in the PeekMessage loop
// - upon receiving a WM_PAINT message, call pSample->OnRender()
//   - populate command list
//     - transition renderTargets[frameIndex] from PRESENT to RENDER_TARGET
//     - encode blank (or not) render command
//     - transition renderTargets[frameIndex] from RENDER_TARGET to PRESENT
//   - execute command list
//   - swapChain->Present(1, 0)
//   - MoveToNextFrame()
//     - encode Signal(fenceValues[frameIndex])
//     - frameIndex = new value chosen by swapChain
//     - wait on the fence, using fenceValues[new frame index]
//     - assign a larger value to fenceValues[new frame index]
//
// 3DGEP tutorial 1 follows the same run loop structure.

// Final state of the 3DGEP repository:
//
// Tutorial5::OnRender()
// - encode commands
// - OnGUI(SwapChain->GetRenderTarget())
//   - uses BackBufferTextures[CurrentBackBufferIndex]
// - SwapChain->Present()
//   - references BackBufferTextures[CurrentBackBufferIndex]
//   - transition the back buffer to PRESENT
//   - execute the command list
//   - dxgiSwapChain->Present(1, 0)
//   - FenceValues[CurrentBackBufferIndex] = CommandQueue.Signal()
//   - CurrentBackBufferIndex = dxgiSwapChain->GetCurrentBackBufferIndex()
//   - auto fenceValue = FenceValues[CurrentBackBufferIndex]
//   - CommandQueue.WaitForFenceValue(fenceValue)
//
// GameFramework::Run() doesn't do any actions in the PeekMessage loop, other
// than forward messages to TranslateMessage and DispatchMessage.
//
// WndProc responds to WM_PAINT, calling Window::OnUpdate.
//
// Window::OnUpdate() calls an arbitrarily defined function, Update().


#endif
