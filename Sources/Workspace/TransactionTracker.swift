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
  
  mutating func register(transaction: Atoms.Transaction) {
    for i in transaction.removedIDs.indices {
      let atomID = transaction.removedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      
      // TODO: work
    }
    
    guard transaction.movedIDs.count ==
            transaction.movedPositions.count else {
      fatalError("Incorrect array sizes.")
    }
    
    for i in transaction.movedIDs.indices {
      let atomID = transaction.movedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      
      // TODO: work
    }
    
    guard transaction.addedIDs.count ==
            transaction.addedPositions.count else {
      fatalError("Incorrect array sizes.")
    }
    
    for i in transaction.addedIDs.indices {
      let atomID = transaction.addedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      
      // TODO: work
    }
  }
  
  func compactedAtoms() -> [SIMD4<Float>] {
    fatalError("Not implemented.")
  }
}
