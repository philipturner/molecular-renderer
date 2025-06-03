#if os(Windows)
import SwiftCOM
import WinSDK

// Once (or if) this works:
// - (1) Ensure it's saved in a Git commit to this repo.
// - (2) Upstream it to my fork of swift-com.
// - (3) Change this class to inherit from 'ID3D12InfoQueue'. Only possible
//       when declared in the same module as 'SwiftCOM.ID3D12InfoQueue'.

public class ID3D12InfoQueue1: SwiftCOM.IUnknown {
  // Replacing ID3D12InfoQueue1 with ID3D12InfoQueue that's compatible with
  // Windows 10.
  public override class var IID: IID { IID_ID3D12InfoQueue }
  
  public func GetMessage(_ MessageIndex: UINT64) throws -> (D3D12_MESSAGE, SIZE_T) {
    return try perform(as: WinSDK.ID3D12InfoQueue.self) { pThis in
      var pMessage: D3D12_MESSAGE = D3D12_MESSAGE()
      var pMessageByteLength: SIZE_T = SIZE_T()
      // FIXME(compnerd) GetMessage is also a free function which has a unicode
      // and ascii version.  As a result, `GetMessage` is a macro which happens
      // to expand incorrectly to `GetMessageA` here.
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, MessageIndex, nil, &pMessageByteLength))
      return (pMessage, pMessageByteLength)
    }
  }
  
  // Doesn't work.
  public func RegisterMessageCallback(_ CallbackFunc: D3D12MessageFunc, _ CallbackFilterFlags: D3D12_MESSAGE_CALLBACK_FLAGS, _ pContext: UnsafeMutableRawPointer?, _ pCallbackCookie: UnsafeMutablePointer<DWORD>?) throws {
    return try perform(as: WinSDK.ID3D12InfoQueue1.self) { pThis in
      try CHECKED(pThis.pointee.lpVtbl.pointee.RegisterMessageCallback(pThis, CallbackFunc, CallbackFilterFlags, pContext, pCallbackCookie))
    }
  }
  
  // Doesn't work.
  public func UnregisterMessageCallback(_ CallbackCookie: DWORD) throws {
    return try perform(as: WinSDK.ID3D12InfoQueue1.self) { pThis in
      try CHECKED(pThis.pointee.lpVtbl.pointee.UnregisterMessageCallback(pThis, CallbackCookie))
    }
  }
}

#endif
