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
    print("Called the message procedure with message code \(message).")
    
    // Defer to the OS default function.
    return DefWindowProcA(hwnd, message, wParam, lParam)
  }
}

#endif
