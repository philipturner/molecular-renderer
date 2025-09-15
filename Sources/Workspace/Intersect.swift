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
  
  // WARNING: Set the fourth lane of the 'atom' vector to its radius.
  void intersect(\(resultArgument()),
                 IntersectionQuery query,
                 float4 atom)
  {
  
  }
  """
}
