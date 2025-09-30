#if os(Windows)
import FidelityFX
#endif

public struct JitterOffsetDescriptor {
  public var index: Int?
  public var upscaleFactor: Float?
  
  public init() {
    
  }
}

public struct JitterOffset {
  public static func createPhaseCount(upscaleFactor: Float) -> Int {
    #if os(macOS)
    return 8 * Int(upscaleFactor) * Int(upscaleFactor)
    #else
    let jitterPhaseCount = FFXDescriptor<ffxQueryDescUpscaleGetJitterPhaseCount>()
    jitterPhaseCount.type = FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTERPHASECOUNT
    jitterPhaseCount.value.renderWidth = 1000
    jitterPhaseCount.value.displayWidth = 1000 * UInt32(upscaleFactor)
    
    let pOutPhaseCount: UnsafeMutablePointer<Int32> = .allocate(capacity: 1)
    defer { pOutPhaseCount.deallocate() }
    pOutPhaseCount.pointee = 5
    jitterPhaseCount.value.pOutPhaseCount = pOutPhaseCount
    
    FFXContext.query(descriptor: jitterPhaseCount)
    return Int(pOutPhaseCount.pointee)
    #endif
  }
  
  public static func create(
    descriptor: JitterOffsetDescriptor
  ) -> SIMD2<Float> {
    guard let index = descriptor.index,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("This should never happen.")
    }
    
    fatalError("Not implemented.")
  }
}
