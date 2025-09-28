struct CameraArgs {
  // There was a strange alignment problem in the HLSL compiler. It would
  // pack a single FP32 number into the 4th lane of a float3 vector, instead
  // of pushing that value to the next multiple of 16 bytes.
  //
  // The simplest remedy for now, is placing 'tangentFactor' at the very
  // start of the data structure.
  var tangentFactor: Float = .zero
  var position: SIMD3<Float> = .zero
  var basis: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (.zero, .zero, .zero)
  
  static var shaderDeclaration: String {
    """
    struct CameraArgs {
      float tangentFactor;
      float3 position;
      Matrix3x3 basis;
    };
    """
  }
}
