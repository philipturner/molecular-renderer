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
    // Branch over the possible message types.
    switch Int32(message) {
    case WM_PAINT:
      break
      
    case WM_KEYDOWN:
      print("Identified KEYDOWN message.")
    
    case WM_CHAR:
      print("Identified CHAR message.")
      
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
