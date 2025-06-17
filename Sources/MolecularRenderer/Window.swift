#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

#if os(macOS)
class Window: NSViewController, NSApplicationDelegate {
  nonisolated(unsafe) var nsWindow: NSWindow
  private var frameSize: SIMD2<Double>
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    // Initialize the window.
    //
    // The content rectangle is set to zero, because its value at this time
    // has no effect on the final value.
    nsWindow = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .titled],
      backing: .buffered,
      defer: false,
      screen: display.nsScreen)
    
    let workArea = display.nsScreen.visibleFrame
    let workAreaCenter = SIMD2<Double>(workArea.midX, workArea.midY)
    
    let contentSize = display.contentSize
    let contentBottomLeft = workAreaCenter - contentSize / 2
    let contentRect = NSRect(
      origin: CGPointMake(contentBottomLeft[0], contentBottomLeft[1]),
      size: CGSizeMake(contentSize[0], contentSize[1]))
    
    let frameRect = nsWindow.frameRect(forContentRect: contentRect)
    nsWindow.setFrameOrigin(frameRect.origin)
    self.frameSize = SIMD2(
      frameRect.size.width,
      frameRect.size.height)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the UI event handlers.
    nsWindow.makeFirstResponder(self)
    registerCloseNotification()
    
    // Materialize the window's content rect, expanding its frame size to the
    // expected value.
    nsWindow.contentViewController = self
    guard nsWindow.frame.size.width == frameSize[0],
          nsWindow.frame.size.height == frameSize[1] else {
      fatalError("Window had unexpected size.")
    }
    
    // Make the window visible to the user.
    nsWindow.makeKey()
    nsWindow.orderFrontRegardless()
  }
}
#endif

#if os(Windows)

// TODO: Remove all 'public' modifiers after smoke testing object creation
// in the workspace script.
//
// TODO: Fix the two places where createWindowStyle() should be called.

public class Window {
  public init(display: Display) {
    Self.registerWindowClass()
    
    // Rework everything about how dimensions are done. As the next task, just
    // try to replicate the process of setting the various rects on macOS.
    
    // extract frame origin offset from frameRect
    // - combine with center of workArea - contentSize / 2
    // extract nWidth/nHeight from frameRect
    
    let monitor = Display.monitor(output: display.dxgiOutput)
    let workArea = Display.workArea(monitor: monitor)
    let workAreaCenter = (workArea.lowHalf &+ workArea.highHalf) / 2
    
    let contentSize = display.frameBufferSize
    let contentTopLeft = workAreaCenter &- contentSize / 2
    
    // Add the origin of the frame rect, which is the offset from a perfectly
    // aligned content rect.
    let frameRect = Self.createFrameRect(contentSize: contentSize)
    let frameTopLeft = contentTopLeft &+ frameRect.lowHalf
    let frameSize = frameRect.highHalf &- frameRect.lowHalf
    
    
    
    print(workArea)
    print(workAreaCenter)
    print(contentTopLeft, contentSize)
    print(frameTopLeft, frameSize)
  }
}

extension Window {
  // Register the window class for the application's window.
  static func registerWindowClass() {
    var windowClass = WNDCLASSEXA()
    windowClass.cbSize = UInt32(MemoryLayout<WNDCLASSEXA>.stride)
    windowClass.style = 0
    
    // Link to the message procedure, which is defined in a different file.
    windowClass.lpfnWndProc = { hWnd, uMsg, wParam, lParam in
      Window.windowProcedure(hWnd, uMsg, wParam, lParam)
    }
    windowClass.cbClsExtra = 0
    windowClass.cbWndExtra = 0
    windowClass.hInstance = nil
    windowClass.hIcon = nil
    
    // Generate the cursor object.
    let cursorName = UnsafeMutablePointer<Int8>(bitPattern: UInt(32512))
    let cursor = LoadCursorA(nil, cursorName)
    guard let cursor else {
      fatalError("Could not load cursor.")
    }
    windowClass.hCursor = cursor
    windowClass.hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW + 1))
    
    // 'RegisterClassExA' must be called within the same scope where the cString
    // pointer exists. Otherwise, cString becomes a zombie pointer and the
    // function fails with error code 123.
    let name: String = "Window"
    name.withCString { cString in
      windowClass.lpszMenuName = nil
      windowClass.lpszClassName = cString
      windowClass.hIconSm = nil
      
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
  
  static func createFrameRect(contentSize: SIMD2<Int>) -> SIMD4<Int> {
    var frameRect = RECT()
    frameRect.left = 0
    frameRect.top = 0
    frameRect.right = Int32(contentSize[0])
    frameRect.bottom = Int32(contentSize[1])
    
    SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    let succeeded = AdjustWindowRect(
      &frameRect, // lpRect
      createWindowStyle(), // dwStyle
      false) // bMenu
    guard succeeded else {
      fatalError("Could not adjust frame rect.")
    }
    
    return SIMD4(
      Int(frameRect.left),
      Int(frameRect.top),
      Int(frameRect.right),
      Int(frameRect.bottom))
  }
}

#endif
