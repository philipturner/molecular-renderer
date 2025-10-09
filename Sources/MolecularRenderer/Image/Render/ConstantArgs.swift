struct RenderArgs {
  var atomCount: UInt32 = .zero
  var frameSeed: UInt32 = .zero
  var jitterOffset: SIMD2<Float> = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      uint atomCount;
      uint frameSeed;
      float2 jitterOffset;
    };
    """
  }
}
