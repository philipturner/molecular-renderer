// Reference code
#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

struct WindowUtilities {
  // Returns appropriate window dimensions at the center of the screen.
  //
  // Lane 0: x
  // Lane 1: y
  // Lane 2: width
  // Lane 3: height
  static func createWindowDimensions() -> SIMD4<UInt32> {
    // This should use the actual work area.
    let screenWidth = Int32(GetSystemMetrics(SM_CXSCREEN))
    let screenHeight = Int32(GetSystemMetrics(SM_CYSCREEN))
    
    // This should use Display.frameBufferSize
    var windowRect = RECT()
    windowRect.left = 0
    windowRect.top = 0
    windowRect.right = 1440
    windowRect.bottom = 1440
    
    SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    let succeeded = AdjustWindowRect(
      &windowRect, // lpRect
      DWORD(), // createWindowStyle(), // dwStyle
      false) // bMenu
    guard succeeded else {
      fatalError("Could not adjust window rect.")
    }
    
    // Change this so the center of the content rect aligns with the center
    // of the work area.
    let windowSizeX = Int32(windowRect.right - windowRect.left)
    let windowSizeY = Int32(windowRect.bottom - windowRect.top)
    
    let leftX = screenWidth / 2 - windowSizeX / 2
    let upperY = screenHeight / 2 - windowSizeY / 2
    
    let outputSigned = SIMD4<Int32>(
      leftX, upperY, windowSizeX, windowSizeY)
    let outputUnsigned = SIMD4<UInt32>(
      truncatingIfNeeded: outputSigned)
    return outputUnsigned
  }
  
  // Create a window from the specified dimensions.
  static func createWindow(dimensions: SIMD4<UInt32>) -> HWND {
    // Show the close button, but hide the icon.
    //
    // Source: https://stackoverflow.com/a/4905502
    let dwExStyle = UInt32(WS_EX_DLGMODALFRAME)
    let className: String = "Window"
    
    SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    let output = CreateWindowExA(
      dwExStyle, // dwExStyle
      className, // lpClassName
      nil, // lpWindowName
      DWORD(), // createWindowStyle(), // dwStyle
      Int32(dimensions[0]), // X
      Int32(dimensions[1]), // Y
      Int32(dimensions[2]), // nWidth
      Int32(dimensions[3]), // nHeight
      nil, // hWndParent
      nil, // hMenu
      nil, // hInstance
      nil) // lpParam
    
    guard let output else {
      fatalError("Could not create window.")
    }
    return output
  }
}

#endif
