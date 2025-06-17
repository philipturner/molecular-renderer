// Reference code
#if os(Windows)
import MolecularRenderer
import SwiftCOM
import WinSDK

class MessageProcedure {
  static func windowProcedure(
    _ hWnd: HWND?,
    _ uMsg: UInt32,
    _ wParam: WPARAM,
    _ lParam: LPARAM
  ) -> LRESULT {
    guard let hWnd else {
      fatalError("hWnd was null.")
    }
    print("Invoked the message procedure with message \(uMsg).")
    
    // Branch over the possible message types.
    switch Int32(uMsg) {
    case WM_PAINT:
      // Render the window's contents for this frame.
      var ps = PAINTSTRUCT()
      BeginPaint(hWnd, &ps)
      EndPaint(hWnd, &ps)
      
    case WM_SIZE:
      // Retrieve the window size.
      var clientRect = RECT()
      GetClientRect(hWnd, &clientRect)
      
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
      return DefWindowProcA(hWnd, uMsg, wParam, lParam)
    }
    
    return 0
  }
}

#endif
