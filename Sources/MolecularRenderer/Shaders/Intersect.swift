func createIntersectUtility() -> String {
  func resultArgument() -> String {
    #if os(macOS)
    "thread IntersectionResult &result"
    #else
    "inout IntersectionResult result"
    #endif
  }
  
  return """
  struct IntersectionResult {
    bool accept;
    uint atomID;
    float distance;
  };
  
  struct IntersectionQuery {
    float3 rayOrigin;
    float3 rayDirection;
  };
  
  // For now, the 'atom' vector contains its atomic number in the 4th lane. In
  // the future, this will become the radius.
  void intersect(\(resultArgument()),
                 IntersectionQuery query,
                 float4 atom,
                 uint atomID)
  {
    float3 oc = query.rayOrigin - atom.xyz;
    float b2 = dot(float3(oc), query.rayDirection);
    
    uint atomicNumber = uint(atom[3]);
    float radius = atomRadii[atomicNumber];
    float c = dot(oc, oc) - radius * radius;
    
    float disc4 = b2 * b2 - c;
    if (disc4 > 0) {
      float distance = -disc4 * rsqrt(disc4) - b2;
      if (distance >= 0 && distance < result.distance) {
        result.atomID = atomID;
        result.distance = distance;
      }
    }
  }
  """
}
