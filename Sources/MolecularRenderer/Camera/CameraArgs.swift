struct CameraArgs {
  var position: SIMD3<Float> = .zero
  var basis:  (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (.zero, .zero, .zero)
  var tangentFactor: Float = .zero
  
  static var shaderDeclaration: String {
    """
    struct CameraArgs {
      float3 position;
      Matrix3x3 basis;
      float tangentFactor;
    };
    """
  }
}
