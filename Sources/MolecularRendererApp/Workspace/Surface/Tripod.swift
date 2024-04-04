//
//  Tripod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Tripod {
  var topology: Topology
  
  init() {
    var tripod = CBNTripod()
    tripod.rotateLegs(slantAngleDegrees: 62, swingAngleDegrees: 5)
    Self.passivate(tripod: &tripod)
    
    topology = Topology()
    topology.atoms = tripod.createAtoms()
    Self.shift(topology: &topology)
  }
}

extension Tripod {
  private static func passivate(tripod: inout CBNTripod) {
    for legID in tripod.legs.indices {
      var topology = tripod.legs[legID].topology
      
      // NOTE: Ensure the Si-H bonds are oriented the same way as in the bulk.
      var insertedAtoms: [Entity] = []
      var insertedBonds: [SIMD2<UInt32>] = []
      for atomID in topology.atoms.indices {
        let atom = topology.atoms[atomID]
        guard atom.atomicNumber == 14 else {
          continue
        }
        
        // Two possibilities for energy minimum:
        // - triangle length = 0.768 nm
        // - triangle length = 1.016 nm
        var silicon = atom
        print(silicon.position)
        
        var siliconXZVector = SIMD2(silicon.position.x, silicon.position.z)
        siliconXZVector /= (siliconXZVector * siliconXZVector).sum().squareRoot()
        siliconXZVector *= 1.016 / Float(3).squareRoot()
        silicon.position.x = siliconXZVector[0]
        silicon.position.z = siliconXZVector[1]
        topology.atoms[atomID] = silicon
        print(silicon.position)
        
        var baseOrbital: SIMD3<Float> = .init(0, 1, 0)
        let baseAngle: Float = 109.5 * .pi / 180
        let baseRotation = Quaternion(angle: baseAngle, axis: [0, 0, 1])
        baseOrbital = baseRotation.act(on: baseOrbital)
        
        for orbitalID in 0..<3 {
          let angle = Float(orbitalID) * .pi * 2 / 3 + .pi / 6
          let orbitalRotation = Quaternion(angle: angle, axis: [0, 1, 0])
          let orbital = orbitalRotation.act(on: baseOrbital)
          
          // Source: MM4 parameters
          let chBondLength: Float = 1.483 / 10
          let position = silicon.position + orbital * chBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        }
      }
      
      topology.insert(atoms: insertedAtoms)
      topology.insert(bonds: insertedBonds)
      tripod.legs[legID].topology = topology
    }
  }
  
  private static func shift(topology: inout Topology) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      
      // Align the tripod with the lattice.
      let latticeConstant = Constant(.hexagon) { .elemental(.silicon) }
      position.y += 0.69417167
      position.z += latticeConstant / Float(3).squareRoot()
      
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
}
