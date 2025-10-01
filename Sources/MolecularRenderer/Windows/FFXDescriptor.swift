#if os(Windows)
import FidelityFX

class FFXDescriptor<T> {
  private let pValue: UnsafeMutablePointer<T>
  
  init() {
    self.pValue = .allocate(capacity: 1)
    
    // Prevent an easy memory corruption bug from not manually setting pNext.
    // Remove the need for the client to explicitly set pNext when 'nil'.
    pHeader.pointee.pNext = nil
  }
  
  deinit {
    pHeader.deallocate()
  }
  
  var pHeader: UnsafeMutablePointer<ffxApiHeader> {
    let opaque = UnsafeMutableRawPointer(pValue)
    return opaque.assumingMemoryBound(to: ffxApiHeader.self)
  }
  
  var type: UInt32 {
    get {
      let value64 = pHeader.pointee.type
      return UInt32(value64)
    }
    set {
      let value64 = UInt64(newValue)
      pHeader.pointee.type = value64
    }
  }
  
  var pNext: UnsafeMutablePointer<ffxApiHeader>? {
    get {
      pHeader.pointee.pNext
    }
    set {
      pHeader.pointee.pNext = newValue
    }
  }
  
  var value: T {
    _read {
      yield pValue.pointee
    }
    _modify {
      yield &pValue.pointee
    }
  }
}
#endif
