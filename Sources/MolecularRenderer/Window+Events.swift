#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

#if os(macOS)
extension Window {
  func registerCloseNotification() {
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(windowWillClose(notification:)),
      name: NSWindow.willCloseNotification,
      object: nsWindow)
  }
  
  @objc
  func windowWillClose(notification: NSNotification) {
    // End the application elegantly.
    let application = NSApplication.shared
    application.stop(nil)
  }
  
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let characters = event.charactersIgnoringModifiers!
      if characters == "w" {
        // End the application elegantly.
        let application = NSApplication.shared
        application.stop(nil)
      }
    }
  }
}
#endif

#if os(Windows)
extension Window {
  static func windowProcedure(
    _ hWnd: HWND?,
    _ uMsg: UInt32,
    _ wParam: WPARAM, // UInt64
    _ lParam: LPARAM // Int64
  ) -> LRESULT {
    guard let hWnd else {
      fatalError("hWnd was null.")
    }
    
    // Branch over the possible message types.
    switch Int32(uMsg) {
    case WM_PAINT:
      // Render the window's contents for this frame.
      guard let application = Application.singleton,
            let runLoop = application.runLoop else {
        fatalError("Could not retrieve run loop.")
      }
      runLoop.outputHandler()

    case WM_SIZE:
      // Retrieve the expected size.
      guard let application = Application.singleton else {
        fatalError("Could not retrieve the application.")
      }
      let frameBufferSize = application.display.frameBufferSize
      
      // Retrieve the actual size.
      var contentRect = RECT()
      GetClientRect(hWnd, &contentRect)
      
      // Assert that the size is correct.
      guard contentRect.left == 0,
            contentRect.top == 0,
            contentRect.right == frameBufferSize[0],
            contentRect.bottom == frameBufferSize[1] else {\
        // Example: 1080x1080 window on 1920x1080 screen exceeds display
        // dimensions because 19-pixel bar on the top makes the actual window
        // 1080x1099.
        //
        // Solution: shrink all dimensions by a small constant factor, so the
        // window doesn't get cut off by the screen. Make sure the new
        // dimensions are still divisible by 2 or 3, if you're using upscaling.
        // - 1080x1080 * 0.8 -> 864x864
        // - 1440x1080 * 0.8 -> 1152x864
        // - 1080x1440 * 0.6 -> 648x864
        // - 1440x1440 * 0.6 -> 864x864
        fatalError("""
          Window dimensions approached or exceeded display resolution. Make the 
          window smaller in DisplayDescriptor.frameBufferSize.
          """)
      }
      
    case WM_KEYDOWN:
      // Implementation of 'Ctrl + W' shortcut:
      //
      // VK_W = 0x57
      if UInt64(wParam) == Int32(0x57) {
        // Check whether 'Ctrl' was pressed.
        let ctrlState = GetKeyState(VK_CONTROL)
        if ctrlState < 0 {
          // End the application elegantly.
          PostQuitMessage(0)
        }
      }
      
    case WM_DESTROY:
      // End the application elegantly.
      PostQuitMessage(0)
      
    default:
      // Defer to the OS default function.
      return DefWindowProcA(hWnd, uMsg, wParam, lParam)
    }
    
    return 0
  }
}
#endif
