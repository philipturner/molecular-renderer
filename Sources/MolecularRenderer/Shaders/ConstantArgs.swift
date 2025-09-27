struct ConstantArgs {
  var atomCount: UInt32 = .zero
  var frameSeed: UInt32 = .zero
  var tangentFactor: Float = .zero
  var cameraPosition: SIMD3<Float> = .zero
  
  var cameraBasis: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (.zero, .zero, .zero)
  
  static var shaderDeclaration: String {
    """
    struct ConstantArgs {
      uint atomCount;
      uint frameSeed;
      float tangentFactor;
      float3 cameraPosition;
      Matrix3x3 cameraBasis;
    };
    """
  }
}
