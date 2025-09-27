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
