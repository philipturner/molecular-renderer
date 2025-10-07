

public struct Camera {
  /// The origin point of all primary rays.
  public var position: SIMD3<Float>
  
  /// 3x3 matrix with normalized vectors for describing the orientation.
  public var basis: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>)
  
  /// The camera angle field of view in the vertical direction (expressed in
  /// radians).
  public var fovAngleVertical: Float
  
  init() {
    self.position = SIMD3(0, 0, 0)
    self.basis = (
      SIMD3(1, 0, 0),
      SIMD3(0, 1, 0),
      SIMD3(0, 0, 1))
    self.fovAngleVertical = Float.pi / 180 * 60
  }
}

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
