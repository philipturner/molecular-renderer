#if os(Windows)
import SwiftCOM
import WinSDK

// TODO: Upstream this into my fork of swift-com.

public class IDXGIInfoQueue: SwiftCOM.IUnknown {
  public override class var IID: IID { IID_IDXGIInfoQueue }
  
  public func ClearRetrievalFilter(_ Producer: DXGI_DEBUG_ID) throws {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      pThis.pointee.lpVtbl.pointee.ClearRetrievalFilter(pThis, Producer)
    }
  }
  
  public func ClearStorageFilter(_ Producer: DXGI_DEBUG_ID) throws {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      pThis.pointee.lpVtbl.pointee.ClearStorageFilter(pThis, Producer)
    }
  }
  
  public func GetBreakOnSeverity(_ Producer: DXGI_DEBUG_ID, _ Severity: DXGI_INFO_QUEUE_MESSAGE_SEVERITY) throws -> Bool {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetBreakOnSeverity(pThis, Producer, Severity) == true
    }
  }
  
  /// See `ID3D12InfoQueue::GetMessage` for documentation.
  public func GetMessage(_ Producer: DXGI_DEBUG_ID, _ MessageIndex: UINT64) throws -> UnsafeMutablePointer<DXGI_INFO_QUEUE_MESSAGE> {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      // Call the function the first time.
      var messageByteLength: SIZE_T = SIZE_T()
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, Producer, MessageIndex, nil, &messageByteLength))
      
      // Allocate memory, then cast to a non-null, typed pointer.
      let rawPointer = malloc(Int(messageByteLength))
      guard let rawPointer else {
        fatalError("Failed to allocate memory for DXGI_INFO_QUEUE_MESSAGE.")
      }
      let pMessage = rawPointer.assumingMemoryBound(to: DXGI_INFO_QUEUE_MESSAGE.self)
      
      // Call the function the second time.
      try CHECKED(pThis.pointee.lpVtbl.pointee.GetMessageA(pThis, Producer, MessageIndex, pMessage, &messageByteLength))
      return pMessage
    }
  }
  
  public func GetMessageCountLimit(_ Producer: DXGI_DEBUG_ID) throws -> UINT64 {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetMessageCountLimit(pThis, Producer)
    }
  }
  
  public func GetMuteDebugOutput(_ Producer: DXGI_DEBUG_ID) throws -> Bool {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetMuteDebugOutput(pThis, Producer) == true
    }
  }
   
  public func GetNumMessagesAllowedByStorageFilter(_ Producer: DXGI_DEBUG_ID) throws -> UINT64 {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetNumMessagesAllowedByStorageFilter(pThis, Producer)
    }
  }
  
  public func GetNumMessagesDeniedByStorageFilter(_ Producer: DXGI_DEBUG_ID) throws -> UINT64 {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetNumMessagesDeniedByStorageFilter(pThis, Producer)
    }
  }
  
  public func GetNumStoredMessages(_ Producer: DXGI_DEBUG_ID) throws -> UINT64 {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetNumStoredMessages(pThis, Producer)
    }
  }
  
  public func GetNumStoredMessagesAllowedByRetrievalFilters(_ Producer: DXGI_DEBUG_ID) throws -> UINT64 {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetNumStoredMessagesAllowedByRetrievalFilters(pThis, Producer)
    }
  }
  
  public func GetRetrievalFilterStackSize(_ Producer: DXGI_DEBUG_ID) throws -> UINT {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetRetrievalFilterStackSize(pThis, Producer)
    }
  }
  
  public func GetStorageFilterStackSize(_ Producer: DXGI_DEBUG_ID) throws -> UINT {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      return pThis.pointee.lpVtbl.pointee.GetStorageFilterStackSize(pThis, Producer)
    }
  }
  
  public func SetBreakOnSeverity(_ Producer: DXGI_DEBUG_ID, _ Severity: DXGI_INFO_QUEUE_MESSAGE_SEVERITY, _ bEnabled: WindowsBool) throws {
    return try perform(as: WinSDK.IDXGIInfoQueue.self) { pThis in
      try CHECKED(pThis.pointee.lpVtbl.pointee.SetBreakOnSeverity(pThis, Producer, Severity, bEnabled))
    }
  }
}

#endif
