struct RenderArgs {
  var jitterOffsetX: Float = .zero
  var jitterOffsetY: Float = .zero
  var frameSeed: UInt32 = .zero
  var upscaleFactor: Float = .zero
  var secondaryRayCount: UInt32 = .zero
  var criticalPixelCount: Float = .zero
  
  static var shaderDeclaration: String {
    """
    struct RenderArgs {
      float jitterOffsetX;
      float jitterOffsetY;
      uint frameSeed;
      float upscaleFactor;
      uint secondaryRayCount;
      float criticalPixelCount;
    };
    """
  }
}
