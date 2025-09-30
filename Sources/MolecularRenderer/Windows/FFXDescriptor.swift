#if os(Windows)
import FidelityFX

public class FFXDescriptor<T> {
  private let pValue: UnsafeMutablePointer<T>
  
  public init() {
    self.pValue = .allocate(capacity: 1)
    
    // Prevent an easy memory corruption bug from not manually setting pNext.
    // Remove the need for the client to explicitly set pNext when 'nil'.
    pHeader.pointee.pNext = nil
  }
  
  deinit {
    pHeader.deallocate()
  }
  
  public var pHeader: UnsafeMutablePointer<ffxApiHeader> {
    let opaque = UnsafeMutableRawPointer(pValue)
    return opaque.assumingMemoryBound(to: ffxApiHeader.self)
  }
  
  public var type: Int32 {
    get {
      let value64 = pHeader.pointee.type
      return Int32(value64)
    }
    set {
      let value64 = UInt64(newValue)
      pHeader.pointee.type = value64
    }
  }
  
  public var pNext: UnsafeMutablePointer<ffxApiHeader>? {
    get {
      pHeader.pointee.pNext
    }
    set {
      pHeader.pointee.pNext = newValue
    }
  }
  
  public var value: T {
    _read {
      yield pValue.pointee
    }
    _modify {
      yield &pValue.pointee
    }
  }
}
#endif
