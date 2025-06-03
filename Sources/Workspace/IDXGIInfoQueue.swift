#if os(Windows)
import SwiftCOM
import WinSDK

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
}

#endif
