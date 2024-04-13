import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Test whether it works in a
// constrained MD simulation.

func createGeometry() -> [MM4RigidBody] {
  let flywheel = Flywheel()
  let bonds = flywheel.rigidBody.parameters.bonds.indices
  
  var lastAtomID: UInt32 = .zero
  var compressableCount8: Int = .zero
  var compressableCount16: Int = .zero
  var compressableCount32: Int = .zero
  for bond in bonds {
    guard bond[0] >= lastAtomID,
          bond[0] - lastAtomID < 256 else {
      fatalError("Bond could not be compressed.")
    }
    guard bond[1] > bond[0] else {
      fatalError("Bond was not sorted.")
    }
    
    let difference = bond[1] - bond[0]
    if difference < 256 {
      compressableCount8 += 1
      
      // We rely on there always being an 8-compressed atom nearby.
      lastAtomID = bond[0]
    }
    if difference < 65536 {
      compressableCount16 += 1
    }
    compressableCount32 += 1
  }
  
  print(compressableCount8, compressableCount16, compressableCount32)
  print(compressableCount32 * 8, "->", (compressableCount32 - compressableCount8) * 8 + compressableCount8 * 2, "->", (compressableCount32 - compressableCount8) * 4 + compressableCount8 * 2)
  
  print()
  let serializedBonds = Serialization.serialize(bonds: bonds)
  Serialization.deserialize(bonds: serializedBonds)
  
  exit(0)
}

/*
 // Sort the bonds into compressable and non-compressable groups.
 var compressedBonds: [SIMD2<UInt8>] = []
 var decompressedBonds: [SIMD2<UInt32>] = []
 for bond in bonds {
   // We rely on there always being an 8-compressed atom nearby.
   guard bond[0] >= lastAtomID,
         bond[0] - lastAtomID < 256 else {
     fatalError("Bond could not be compressed.")
   }
   guard bond[1] > bond[0] else {
     fatalError("Bond was not sorted.")
   }
   
   let difference = bond[1] - bond[0]
   if difference < 256 {
     let startDelta = UInt8(bond[0] - lastAtomID)
     let lengthDelta = UInt8(bond[1] - bond[0])
     let compressedBond = SIMD2(startDelta, lengthDelta)
     compressedBonds.append(compressedBond)
     
     // Update the atom cursor.
     lastAtomID = bond[0]
   } else {
     // Do not update the atom cursor.
     decompressedBonds.append(bond)
   }
 }
 
 // Allocate an array for the raw data.
 var rawData: [SIMD2<UInt32>] = []
 
 // Write to the header.
 var header: SIMD2<UInt32> = .zero
 header[0] = UInt32(compressedBonds.count)
 header[1] = UInt32(decompressedBonds.count)
 rawData.append(header)
 
 // Pad the compressable bonds to a multiple of four.
 while compressedBonds.count % 4 != 0 {
   compressedBonds.append(SIMD2<UInt8>.zero)
 }
 
 // Write the compressable bonds.
 for groupID in 0..<compressedBonds.count / 4 {
   var vector: SIMD8<UInt8> = .zero
   for laneID in 0..<4 {
     let compressedBond = compressedBonds[groupID * 4 + laneID]
     vector[laneID * 2 + 0] = compressedBond[0]
     vector[laneID * 2 + 1] = compressedBond[1]
   }
   let castedVector = unsafeBitCast(vector, to: SIMD2<UInt32>.self)
   rawData.append(castedVector)
 }
 
 // Write the non-compressable bonds.
 rawData.append(contentsOf: decompressedBonds)
 */
