#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class MessageProcedure {
  static func globalProcedure(
    _ hwnd: HWND?,
    _ message: UInt32,
    _ wParam: WPARAM,
    _ lParam: LPARAM
  ) -> LRESULT {
    
    switch Int32(message) {
    case WM_PAINT:
      print("(2) Received WM_PAINT")
    case WM_SIZE:
      print("(2) Received WM_SIZE")
    case WM_DESTROY:
      print("(2) Received WM_DESTROY")
    default:
      print("(2) Received unknown message: \(message)")
    }
    
    // Branch over the possible message types.
    switch Int32(message) {
    case WM_PAINT:
      // Render the window's contents for this frame.
      //
      // We must render immediately in response to WM_PAINT messages, from
      // within this callback. Otherwise, the window freezes when being moved.
      Application.global.renderFrame()
      
    case WM_SIZE:
      // Retrieve the window size.
      let window = Application.global.window
      var clientRect = RECT()
      GetClientRect(window, &clientRect)
      
      // Assert that the size is correct.
      guard clientRect.left == 0,
            clientRect.top == 0,
            clientRect.right == 1440,
            clientRect.bottom == 1440 else {
        fatalError("Attempted to resize the window.")
      }
      
    case WM_DESTROY:
      PostQuitMessage(0)
      
    default:
      // Defer to the OS default function.
      return DefWindowProcA(hwnd, message, wParam, lParam)
    }
    
    return 0
  }
}

#endif
