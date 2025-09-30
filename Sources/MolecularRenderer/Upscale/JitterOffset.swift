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
