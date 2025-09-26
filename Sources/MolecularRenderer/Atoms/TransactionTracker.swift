// Mock acceleration structure to facilitate testing of the 'application.atoms'
// API.
public struct TransactionTracker {
  public let atomCount: Int
  public var positions: [SIMD4<Float>]
  public var occupied: [Bool]
  
  public init(atomCount: Int) {
    self.atomCount = atomCount
    self.positions = Array(repeating: .zero, count: atomCount)
    self.occupied = Array(repeating: false, count: atomCount)
  }
  
  public mutating func register(transaction: Atoms.Transaction) {
    for i in transaction.removedIDs.indices {
      let atomID = transaction.removedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      
      guard occupied[Int(atomID)] else {
        fatalError("Incorrect remove transaction was registered.")
      }
      occupied[Int(atomID)] = false
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
      let position = transaction.movedPositions[i]
      
      guard occupied[Int(atomID)] else {
        fatalError("Incorrect move transaction was registered.")
      }
      positions[Int(atomID)] = position
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
      let position = transaction.addedPositions[i]
      
      guard !occupied[Int(atomID)] else {
        fatalError("Incorrect add transaction was registered.")
      }
      occupied[Int(atomID)] = true
      positions[Int(atomID)] = position
    }
  }
  
  public func compactedAtoms() -> [SIMD4<Float>] {
    var output: [SIMD4<Float>] = []
    for atomID in 0..<atomCount {
      guard occupied[atomID] else {
        continue
      }
      
      let position = positions[atomID]
      output.append(position)
    }
    
    return output
  }
}
