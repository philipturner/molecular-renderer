struct RenderArgs {
  var jitterOffset: SIMD2<Float> = .zero
  var frameSeed: UInt32 = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      float2 jitterOffset;
      uint frameSeed;
    };
    """
  }
}
