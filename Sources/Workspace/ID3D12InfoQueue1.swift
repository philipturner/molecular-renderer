#if os(Windows)
import SwiftCOM
import WinSDK

// Once (or if) this works:
// - (1) Ensure it's saved in a Git commit to this repo.
// - (2) Upstream it to my fork of swift-com.
// - (3) Change this class to inherit from 'ID3D12InfoQueue'. Only possible
//       when declared in the same module as 'SwiftCOM.ID3D12InfoQueue'.

public class ID3D12InfoQueue1: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_ID3D12InfoQueue1 }
    
  public func RegisterMessageCallback(_ CallbackFunc: D3D12MessageFunc, _ CallbackFilterFlags: D3D12_MESSAGE_CALLBACK_FLAGS, _ pContext: UnsafeMutableRawPointer?, _ pCallbackCookie: UnsafeMutablePointer<DWORD>?) throws {
    return try perform(as: WinSDK.ID3D12InfoQueue1.self) { pThis in
      try CHECKED(pThis.pointee.lpVtbl.pointee.RegisterMessageCallback(pThis, CallbackFunc, CallbackFilterFlags, pContext, pCallbackCookie))
    }
  }
  
  public func UnregisterMessageCallback(_ CallbackCookie: DWORD) throws {
    return try perform(as: WinSDK.ID3D12InfoQueue1.self) { pThis in
      try CHECKED(pThis.pointee.lpVtbl.pointee.UnregisterMessageCallback(pThis, CallbackCookie))
    }
  }
}

#endif
