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
  
  private static func halton(index: Int, base: Int) -> Float {
    var result: Float = 0.0
    var fractional: Float = 1.0
    var currentIndex: Int = index
    while currentIndex > 0 {
      fractional /= Float(base)
      result += fractional * Float(currentIndex % base)
      currentIndex /= base
    }
    return result
  }
  
  public static func create(
    descriptor: JitterOffsetDescriptor
  ) -> SIMD2<Float> {
    guard let index = descriptor.index,
          let upscaleFactor = descriptor.upscaleFactor else {
      fatalError("This should never happen.")
    }
    let phaseCount = createPhaseCount(upscaleFactor: upscaleFactor)
    
    #if os(macOS)
    // The sample uses a Halton sequence rather than purely random numbers to
    // generate the sample positions to ensure good pixel coverage. This has the
    // result of sampling a different point within each pixel every frame.
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: (index % phaseCount) + 1, base: 2) - 0.5
    let y = halton(index: (index % phaseCount) + 1, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
    #else
    let jitterOffset = FFXDescriptor<ffxQueryDescUpscaleGetJitterOffset>()
    jitterOffset.type = FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTEROFFSET
    jitterOffset.value.index = Int32(index)
    jitterOffset.value.phaseCount = Int32(phaseCount)
    
    let pOut: UnsafeMutablePointer<Float> = .allocate(capacity: 2)
    defer { pOut.deallocate() }
    pOut[0] = 5
    pOut[1] = 5
    jitterOffset.value.pOutX = pOut
    jitterOffset.value.pOutY = pOut + 1
    
    FFXContext.query(descriptor: jitterOffset)
    
    var output: SIMD2<Float> = .zero
    output[0] = pOut[0]
    output[1] = pOut[1]
    return output
    #endif
  }
}
