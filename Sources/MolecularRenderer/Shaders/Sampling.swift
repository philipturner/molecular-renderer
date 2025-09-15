func createSamplingUtility() -> String {
  func asFloat() -> String {
    #if os(macOS)
    "as_type<float>"
    #else
    "asfloat"
    #endif
  }
  
  func reverseBits() -> String {
    #if os(macOS)
    "reverse_bits"
    #else
    "reversebits"
    #endif
  }
  
  return """
  // Partially sourced from:
  // https://github.com/nvpro-samples/gl_vk_raytrace_interop/blob/master/shaders/sampling.h
  
  namespace Sampling {
    uint tea(uint val0, uint val1) {
      uint v0 = val0;
      uint v1 = val1;
      uint s0 = 0;
      
      for (uint n = 0; n < 9; n++) {
        s0 += 0x9e3779b9;
        v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
        v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
      }
      
      return v0;
    }
    
    // Compute radical inverse of n to the base 2.
    float radinv2(uint n) {
      return \(asFloat())(0x3F800000 | (\(reverseBits())(n) >> 9)) - 1;
    }
    
    // Faure-Lemieux scrambled radical inverse
    float radinv3(uint n) {
      uint n_copy = n;
      float val = 0;
      float invBase = \(Float(1) / 3));
      float invBi = invBase;
      
      while (n_copy > 0) {
        uint nDiv = n_copy / 3;
        uint d_i = n_copy - nDiv * 3;
        n_copy = nDiv;
        
        // Ensure this doesn't go out-of-bounds.
        val = saturate(val + float(d_i) * invBi);
        invBi *= invBase;
      }
      return val;
    }
  };
  """
}
