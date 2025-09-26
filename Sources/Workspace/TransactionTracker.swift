import MolecularRenderer

// Mock acceleration structure to facilitate testing of the 'application.atoms'
// API.
struct TransactionTracker {
  let atomCount: Int
  var positions: [SIMD4<Float>]
  var occupied: [Bool]
  
  init(atomCount: Int) {
    self.atomCount = atomCount
    self.positions = Array(repeating: .zero, count: atomCount)
    self.occupied = Array(repeating: false, count: atomCount)
  }
}
