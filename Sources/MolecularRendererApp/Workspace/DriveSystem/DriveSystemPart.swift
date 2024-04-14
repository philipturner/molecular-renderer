//
//  DriveSystemPartData.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/14/24.
//

import Foundation
import HDL
import MM4
import Numerics

protocol DriveSystemPart {
  var rigidBody: MM4RigidBody { get }
  var knobAtomIDs: [UInt32] { get }
}

struct DriveSystemPartData {
  var bodyCenter: SIMD3<Double> = .zero
  var bodyMass: Double = .zero
  var knobCenter: SIMD3<Double> = .zero
  var knobMass: Double = .zero
  
  init(source: DriveSystemPart) {
    let rigidBody = source.rigidBody
    let knobAtomIDSet = Set(source.knobAtomIDs)
    for atomID in rigidBody.parameters.atoms.indices {
      let mass = Double(rigidBody.parameters.atoms.masses[atomID])
      let position = SIMD3<Double>(rigidBody.positions[atomID])
      
      if knobAtomIDSet.contains(UInt32(atomID)) {
        knobCenter += mass * position
        knobMass += mass
      } else {
        bodyCenter += mass * position
        bodyMass += mass
      }
    }
    bodyCenter /= bodyMass
    knobCenter /= knobMass
  }
}
