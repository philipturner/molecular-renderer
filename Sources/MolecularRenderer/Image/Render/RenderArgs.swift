struct RenderArgs {
  var frameSeed: UInt32 = .zero
  var jitterOffset: SIMD2<Float> = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      uint frameSeed;
      float2 jitterOffset;
    };
    """
  }
}
