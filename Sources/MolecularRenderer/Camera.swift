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
  
  /// The number of AO rays for ambient occlusion. Must be at least 3.
  ///
  /// Defaults to 15 (real-time rendering), 64 (offline rendering). Change to
  /// `nil` to disable ambient occlusion.
  public var secondaryRayCount: Int?
  
  /// The number of pixels an atom spans on-screen, before the secondary ray
  /// count starts dropping off with the reciprocal of distance.
  ///
  /// Defaults to 50. Change to `nil` to disable the critical pixel count
  /// heuristic.
  public var criticalPixelCount: Float?
  
  init(isOffline: Bool) {
    self.position = SIMD3(0, 0, 0)
    self.basis = (
      SIMD3(1, 0, 0),
      SIMD3(0, 1, 0),
      SIMD3(0, 0, 1))
    self.fovAngleVertical = Float.pi / 180 * 60
    if isOffline {
      self.secondaryRayCount = 64
    } else {
      self.secondaryRayCount = 15
    }
    self.criticalPixelCount = 50
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
