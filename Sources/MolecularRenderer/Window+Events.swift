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
    exit(0)
  }
  
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let characters = event.charactersIgnoringModifiers!
      if characters == "w" {
        exit(0)
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
      fatalError("Not implemented.")
      
    case WM_SIZE:
      // Retrieve the window size.
      
      /*
      var clientRect = RECT()
      GetClientRect(hWnd, &clientRect)
      
      // Assert that the size is correct.
      guard clientRect.left == 0,
            clientRect.top == 0,
            clientRect.right == 1440,
            clientRect.bottom == 1440 else {
        fatalError("Attempted to resize the window.")
      }
      */
      
      // Need a reference to the app's resources to retrieve expected size.
      fatalError("Not implemented.")
      
    case WM_DESTROY:
      // End the application elegantly, unlike on macOS. It is too early to be
      // able to reason about divergent program behavior after app launch.
      PostQuitMessage(0)
      
    default:
      // Defer to the OS default function.
      return DefWindowProcA(hWnd, uMsg, wParam, lParam)
    }
    
    return 0
  }
}
#endif
