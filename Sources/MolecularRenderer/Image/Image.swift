public struct Image {
  /// Array of pixels in the image, formatted in RGBA order. Only available for
  /// offline rendering.
  public var pixels: [SIMD4<Float16>] = []
  
  var scaleFactor: Float = .zero
}
