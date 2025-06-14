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
      // Render the window's contents for this frame.
      Application.global.renderFrame()
      
      let PM_QS: UInt32 = QS_INPUT << 16
      
      var message = MSG()
      let peekMessageOutput = PeekMessageA(
        &message, // lpMsg
        nil, // hWnd
        0, // wMsgFilterMin
        0, // wMsgFilterMax
        UInt32(PM_NOREMOVE) | PM_QS) // wRemoveMsg
      
      if peekMessageOutput,
         message.message == WM_KEYDOWN ||
         message.message == WM_NCMOUSEMOVE ||
         message.message == WM_MOUSEMOVE {
        var message = MSG()
        let peekMessageOutput = PeekMessageA(
          &message, // lpMsg
          nil, // hWnd
          0, // wMsgFilterMin
          0, // wMsgFilterMax
          UInt32(PM_REMOVE) | PM_QS) // wRemoveMsg
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
