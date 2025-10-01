// Manual implementation of 'float3x3' to work around either a compiler bug,
// or a difference in handling of transposes / row vs. column major, between
// MSL and HLSL.
func createMatrixUtility() -> String {
  return """
  struct Matrix3x3 {
    float3 col0;
    float3 col1;
    float3 col2;
    
    float3 multiply(float3 input) {
      float3 output = col0 * input.x;
      output += col1 * input.y;
      output += col2 * input.z;
      return output;
    }
    
    Matrix3x3 multiply(Matrix3x3 input) {
      Matrix3x3 output;
      output.col0 = multiply(input.col0);
      output.col1 = multiply(input.col1);
      output.col2 = multiply(input.col2);
      return output;
    }
    
    Matrix3x3 transpose() {
      Matrix3x3 output;
      output.col0 = float3(col0[0], col1[0], col2[0]);
      output.col1 = float3(col0[1], col1[1], col2[1]);
      output.col2 = float3(col0[2], col1[2], col2[2]);
      return output;
    }
  };
  """
}
