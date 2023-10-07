//
//  MM4Parameters+Rings.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/7/23.
//

import Foundation

// MARK: - Functions for generating rings and assigning ring types.

/// Parameters for a group of 5 atoms.
///
/// The forcefield parameters may be slightly inaccurate for rings with mixed
/// carbon and silicon atoms (not sure). In the future, this may be expanded to
/// 3-atom and 4-atom rings.
public struct MM4Rings {
  /// Groups of atom indices that form a ring.
  public var indices: [SIMD8<Int32>] = []
  
  /// The number of atoms in the ring.
  public var ringTypes: [UInt8] = []
}

extension MM4Parameters {
  func createTopology() {
    // Traverse the bond topology.
    var anglesMap: [SIMD3<Int32>: Bool] = [:]
    var torsionsMap: [SIMD4<Int32>: Bool] = [:]
    for atom1 in 0..<Int32(atoms.atomicNumbers.count) {
      let map1 = atomsToBondsMap[Int(atom1)]
      var ringType: UInt8 = 6
      
      for lane2 in 0..<4 where map1[lane2] != -1 {
        let atom2 = other(atomID: atom1, bondID: map1[lane2])
        let map2 = atomsToBondsMap[Int(atom2)]
        
        for lane3 in 0..<4 where map2[lane3] != -1 {
          let atom3 = other(atomID: atom2, bondID: map2[lane3])
          if atom1 == atom3 { continue }
          
          if atom1 < atom3 {
            anglesMap[SIMD3(atom1, atom2, atom3)] = true
          }
          let map3 = atomsToBondsMap[Int(atom3)]
          for lane4 in 0..<4 where map3[lane4] != -4 {
            let atom4 = other(atomID: atom3, bondID: map3[lane4])
            if atom2 == atom4 {
              continue
            } else if atom1 == atom4 {
              ringType = min(3, ringType)
              continue
            } else if atom1 < atom4 {
              torsionsMap[SIMD4(atom1, atom2, atom3, atom4)] = true
            }
            
            let map4 = atomsToBondsMap[Int(atom4)]
            @inline(__always)
            func iterate(lane5: Int) -> SIMD4<Int32> {
              let atom5 = other(atomID: atom4, bondID: map4[lane5])
              let map5 = atomsToBondsMap[Int(atom5)]
              var atoms6 = SIMD4<Int32>(repeating: -1)
              for lane6 in 0..<4 {
                atoms6[lane6] = other(atomID: atom5, bondID: map5[lane6])
              }
              
              var ringType = SIMD4<Int32>(repeating: 6)
              ringType.replace(
                with: .init(repeating: 5), where: atom1 .== atoms6)
              ringType.replace(
                with: .init(repeating: 4),
                where: .init(repeating: atom1 == atom5))
              return ringType
            }
            
            // This code is no longer needed. It can be repurposed in the
            // future, if we need to debug the newer mechanism for mapping rings
            // to atoms.
            var mask1 = iterate(lane5: 0)
            let mask2 = iterate(lane5: 1)
            var mask3 = iterate(lane5: 2)
            let mask4 = iterate(lane5: 3)
            mask1.replace(with: mask2, where: mask2 .< mask1)
            mask3.replace(with: mask4, where: mask4 .< mask3)
            mask1.replace(with: mask3, where: mask1 .< mask3)
            ringType = min(ringType, UInt8(truncatingIfNeeded: mask1.min()))
          }
        }
      }
      
      guard ringType >= 5 else {
        fatalError("3- and 4-member rings not supported yet.")
      }
    }
    
    angles.indices = anglesMap.keys.map { $0 }
    torsions.indices = torsionsMap.keys.map { $0 }
  }
}
