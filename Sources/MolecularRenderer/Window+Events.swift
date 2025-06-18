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
    _ wParam: WPARAM,
    _ lParam: LPARAM
  ) -> LRESULT {
    guard let hWnd else {
      fatalError("hWnd was null.")
    }
    
    // Branch over the possible message types.
    switch Int32(uMsg) {
    case WM_PAINT:
      // Render the window's contents for this frame.
      
      // Need a reference to the app's resources to invoke the render function.
      print("WM_PAINT not implemented.")
      
      var ps = PAINTSTRUCT()
      BeginPaint(hWnd, &ps)
      EndPaint(hWnd, &ps)
      
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
            contentRect.bottom == frameBufferSize[1] else {
        fatalError("Attempted to resize the window.")
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
