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
    case WM_CREATE:
      print("Encountered WM_CREATE.")
    
    case WM_ACTIVATE:
      print("Encountered WM_ACTIVATE: \(wParam) \(lParam).")
      
    case WM_ACTIVATEAPP:
      print("Encountered WM_ACTIVATEAPP: \(wParam) \(lParam).")
      
    case WM_POWERBROADCAST:
      print("Encountered WM_POWERBROADCAST.")
      
    case WM_ENTERSIZEMOVE:
      print("Encountered WM_ENTERSIZEMOVE.")
      Application.global.inSizeMove = true
      
    case WM_EXITSIZEMOVE:
      print("Encountered WM_EXITSIZEMOVE.")
      Application.global.inSizeMove = false
      
    case WM_PAINT:
      if Application.global.inSizeMove {
        print("Hello world")
        Application.global.renderFrame()
      } else {
        // Fake paint operation to get the OS to start rendering.
        let window = Application.global.window
        var ps = PAINTSTRUCT()
        BeginPaint(window, &ps)
        EndPaint(window, &ps)
      }
      
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
