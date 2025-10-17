struct RenderArgs {
  var jitterOffset: SIMD2<Float> = .zero
  var frameSeed: UInt32 = .zero
  var upscaleFactor: Float = .zero
  var secondaryRayCount: UInt32 = .zero
  var criticalPixelCount: Float = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      float2 jitterOffset;
      uint frameSeed;
      float upscaleFactor;
      uint secondaryRayCount;
      float criticalPixelCount;
    };
    """
  }
}
