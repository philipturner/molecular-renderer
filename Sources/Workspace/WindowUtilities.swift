#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

struct WindowUtilities {
  static func createWindow() -> HWND {
    SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    registerWindowClass()
    
    let dimensions = createWindowDimensions()
    let window = createWindow(dimensions: dimensions)
    return window
  }
  
  // Registers the window class for the application's window.
  static func registerWindowClass() {
    var windowClass = WNDCLASSEXA()
    windowClass.cbSize = UInt32(MemoryLayout<WNDCLASSEXA>.stride)
    windowClass.style = UInt32(CS_HREDRAW | CS_VREDRAW)
    
    // Link to the message procedure, which is defined in a different file.
    windowClass.lpfnWndProc = { hwnd, message, wParam, lParam in
      return MessageProcedure.globalProcedure(
        hwnd, message, wParam, lParam)
    }
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
    let name: String = "DX12WindowClass"
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
  
  // Returns appropriate window dimensions at the center of the screen.
  //
  // Lane 0: x
  // Lane 1: y
  // Lane 2: width
  // Lane 3: height
  static func createWindowDimensions() -> SIMD4<UInt32> {
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
    
    // Check validity of the dimensions.
    let outputSigned = SIMD4<Int32>(
      leftX, upperY, windowSizeX, windowSizeY)
    guard outputSigned[0] >= 0,
          outputSigned[1] >= 0,
          outputSigned[0] + outputSigned[2] < screenWidth,
          outputSigned[1] + outputSigned[3] < screenHeight else {
      fatalError("The window spawned off-screen.")
    }
    
    let outputUnsigned = SIMD4<UInt32>(
      truncatingIfNeeded: outputSigned)
    return outputUnsigned
  }
  
  // Creates a window from the specified dimensions.
  static func createWindow(dimensions: SIMD4<UInt32>) -> HWND {
    let className: String = "DX12WindowClass"
    let title: String = "Learning DirectX 12"
    
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
}

#endif
