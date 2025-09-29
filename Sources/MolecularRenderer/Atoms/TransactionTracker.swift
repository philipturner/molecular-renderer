// Mock acceleration structure to facilitate testing of the 'application.atoms'
// API.
public struct TransactionTracker {
  public let atomCount: Int
  public var positions: [SIMD4<Float>]
  public var motionVectors: [SIMD3<Float16>]
  public var occupied: [Bool]
  public var previousMovedAtomIDs: [UInt32] = []
  
  public init(atomCount: Int) {
    self.atomCount = atomCount
    self.positions = Array(repeating: .zero, count: atomCount)
    self.motionVectors = Array(repeating: .zero, count: atomCount)
    self.occupied = Array(repeating: false, count: atomCount)
  }
  
  public mutating func register(transaction: Atoms.Transaction) {
    // Reset the motion vectors to zero.
    for atomID in previousMovedAtomIDs {
      let motionVector: SIMD3<Float16> = .zero
      motionVectors[Int(atomID)] = motionVector
    }
    
    // Handle the removed atoms.
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
    
    // Handle the moved atoms.
    guard transaction.movedIDs.count ==
            transaction.movedPositions.count else {
      fatalError("Incorrect array sizes.")
    }
    
    for i in transaction.movedIDs.indices {
      let atomID = transaction.movedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      guard occupied[Int(atomID)] else {
        fatalError("Incorrect move transaction was registered.")
      }
      
      let previousPosition = positions[Int(atomID)]
      let currentPosition = transaction.movedPositions[i]
      positions[Int(atomID)] = currentPosition
      
      let motionVector32 = previousPosition - currentPosition
      let motionVector16 = SIMD3<Float16>(
        Float16(motionVector32[0]),
        Float16(motionVector32[1]),
        Float16(motionVector32[2]))
      motionVectors[Int(atomID)] = motionVector16
    }
    
    // Handle the added atoms.
    guard transaction.addedIDs.count ==
            transaction.addedPositions.count else {
      fatalError("Incorrect array sizes.")
    }
    
    for i in transaction.addedIDs.indices {
      let atomID = transaction.addedIDs[i]
      guard atomID < atomCount else {
        fatalError("Out of bounds memory access.")
      }
      guard !occupied[Int(atomID)] else {
        fatalError("Incorrect add transaction was registered.")
      }
      
      let position = transaction.addedPositions[i]
      occupied[Int(atomID)] = true
      positions[Int(atomID)] = position
    }
    
    // Prepare to reset the next frame's motion vectors.
    self.previousMovedAtomIDs = transaction.movedIDs
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
