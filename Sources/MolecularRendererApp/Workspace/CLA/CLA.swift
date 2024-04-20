//
//  CLA.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLA {
  var logic: CLALogic
  var housing: CLAHousing
  
  var rigidBodies: [MM4RigidBody] {
    var output: [MM4RigidBody] = []
    output.append(contentsOf: logic.rods.map(\.rigidBody))
    output.append(housing.rigidBody)
    return output
  }
  
  init() {
    logic = CLALogic()
    
    var housingDesc = CLAHousingDescriptor()
    housingDesc.rods = logic.rods
    housingDesc.cachePath = "/Users/philipturner/Documents/OpenMM/cache/CLAHousing.data"
    housing = CLAHousing(descriptor: housingDesc)
  }
}
