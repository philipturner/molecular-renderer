struct CameraArgs {
  // Workaround for HLSL alignment issue.
  var position: (Float, Float, Float) = (.zero, .zero, .zero)
  var tangentFactor: Float = .zero
  
  var basis: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (.zero, .zero, .zero)
  
  static var shaderDeclaration: String {
    func packedFloat3() -> String {
      #if os(macOS)
      "packed_float3"
      #else
      "float3"
      #endif
    }
    
    return """
    struct CameraArgs {
      \(packedFloat3()) position;
      float tangentFactor;
      Matrix3x3 basis;
    };
    """
  }
}
