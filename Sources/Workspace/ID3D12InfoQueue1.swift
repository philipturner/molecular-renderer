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
  
  /// Modified binding for `ID3D12InfoQueue::GetMessage`.
  ///
  /// DirectX creates a combined memory allocation, with the `D3D12_MESSAGE`
  /// struct in the first 32 bytes, and the string in the rest. You can
  /// calculate the total allocation size as 32 + `DescriptionByteLength`.
  ///
  /// The caller is responsible for deallocating the pointer. Use `free`
  /// instead of `UnsafeMutablePointer.deallocate`.
  public func GetMessage(_ MessageIndex: UINT64) throws -> UnsafeMutablePointer<D3D12_MESSAGE> {
    return try perform(as: WinSDK.ID3D12InfoQueue.self) { pThis in
      // Call the function the first time.
      var messageByteLength: SIZE_T = SIZE_T()
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, MessageIndex, nil, &messageByteLength))
      
      // Allocate memory, then cast to a non-null, typed pointer.
      let rawPointer = malloc(Int(messageByteLength))
      guard let rawPointer else {
        fatalError("Failed to allocate memory for D3D12_MESSAGE.")
      }
      let pMessage = rawPointer.assumingMemoryBound(to: D3D12_MESSAGE.self)
      
      // Call the function the second time.
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, MessageIndex, pMessage, &messageByteLength))
      return pMessage
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
