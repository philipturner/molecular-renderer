// Reference code
#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

struct WindowUtilities {
  // Create a window using the utilities in this file.
  static func createWindow() -> HWND {
    registerWindowClass()
    
    let dimensions = createWindowDimensions()
    let window = createWindow(dimensions: dimensions)
    return window
  }
  
  // Register the window class for the application's window.
  static func registerWindowClass() {
    var windowClass = WNDCLASSEXA()
    windowClass.cbSize = UInt32(MemoryLayout<WNDCLASSEXA>.stride)
    windowClass.style = 0
    
    // Link to the message procedure, which is defined in a different file.
    windowClass.lpfnWndProc = nil
    windowClass.cbClsExtra = 0
    windowClass.cbWndExtra = 0
    windowClass.hInstance = nil
    
    // Generate the cursor object.
    let cursorName = UnsafeMutablePointer<Int8>(bitPattern: UInt(32512))
    let cursor = LoadCursorA(nil, cursorName)
    guard let cursor else {
      fatalError("Could not load cursor.")
    }
    windowClass.hCursor = cursor
    windowClass.hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW + 1))
    windowClass.hIcon = nil
    windowClass.hIconSm = nil
    
    // 'RegisterClassExA' must be called within the same scope where the cString
    // pointer exists. Otherwise, cString becomes a zombie pointer and the
    // function fails with error code 123.
    let name: String = "Window"
    name.withCString { cString in
      windowClass.lpszMenuName = nil
      windowClass.lpszClassName = cString
      
      let atom = RegisterClassExA(&windowClass)
      guard atom > 0 else {
        fatalError("Could not create window class.")
      }
    }
  }
  
  // Returns WS_OVERLAPPEDWINDOW, but without the ability to resize the window.
  static func createWindowStyle() -> DWORD {
    var output: Int32 = .zero
    output |= WS_OVERLAPPED
    output |= WS_CAPTION
    output |= WS_SYSMENU
    return DWORD(output)
  }
  
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
      createWindowStyle(), // dwStyle
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
      createWindowStyle(), // dwStyle
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
