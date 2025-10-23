struct RenderArgs {
  var screenDimensions: SIMD2<UInt32> = .zero
  var jitterOffset: SIMD2<Float> = .zero
  var frameSeed: UInt32 = .zero
  var upscaleFactor: Float = .zero
  var secondaryRayCount: Float = .zero
  var criticalPixelCount: Float = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      uint2 screenDimensions;
      float2 jitterOffset;
      uint frameSeed;
      float upscaleFactor;
      float secondaryRayCount;
      float criticalPixelCount;
    };
    """
  }
}
