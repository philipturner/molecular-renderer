struct DispatchVoxelGroups {
  // [numthreads(4, 4, 4)]
  // dispatch threads SIMD3(repeating: worldDimension / 8)
  // dispatch groups  SIMD3(repeating: worldDimension / 32)
  //
  // Affected kernels:
  // - addProcess2
  // - removeProcess2
  // - rebuildProcess1
  // - resetIdle
  static func createSource(worldDimension: Float) -> String {
    
  }
}
