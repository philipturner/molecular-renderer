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
      // The fix for the crash: use two function calls. The first has the
      // message pointer set to nil. The second has the message pointer set to
      // an actual pointer.
      //
      // // Get the size of the message
      // SIZE_T messageLength = 0;
      // HRESULT hr = pInfoQueue->GetMessage(0, NULL, &messageLength);
      //
      // // Allocate space and get the message
      // D3D12_MESSAGE * pMessage = (D3D12_MESSAGE*)malloc(messageLength);
      // hr = pInfoQueue->GetMessage(0, pMessage, &messageLength);
      
      var messageByteLength: SIZE_T = SIZE_T()
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, MessageIndex, nil, &messageByteLength))
      
      // The string length is (returned byte length) - (theoretical byte length).
      print()
      print("Queried message.")
      print("returned byte length:", messageByteLength)
      print("theoretical byte length:", MemoryLayout<D3D12_MESSAGE>.stride)
      print("theoretical byte length:", MemoryLayout<D3D12_MESSAGE>.size)
      print("component byte length:", MemoryLayout<D3D12_MESSAGE_ID>.stride)
      
      let pMessage = malloc(Int(messageByteLength)).assumingMemoryBound(to: D3D12_MESSAGE.self)
      print("pMessage =", pMessage)
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, MessageIndex, pMessage, &messageByteLength))
      
      print()
      print("Passed second function call.")
      print("returned byte length:", messageByteLength)
      print("message =", pMessage.pointee)
      
      // The string is allocated in the region of the memory allocation
      // immediately after the 'D3D12_MESSAGE' struct.
      print("pointer pair: (\(pMessage), \(pMessage.pointee.pDescription))")
      
      let string = String(cString: pMessage.pointee.pDescription)
      print("string =", string)
      
      return (pMessage.pointee, messageByteLength)
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
