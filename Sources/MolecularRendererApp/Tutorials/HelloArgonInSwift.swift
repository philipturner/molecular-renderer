//
//  HelloArgonInSwift.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/18/23.
//

import Foundation
import OpenMM

func writePdbFrame(frameNum: Int, state: OpaquePointer!) {
  let posInNm = OpenMM_State_getPositions(state)
  
  print("MODEL     \(frameNum)")
  for a in 0..<Int(OpenMM_Vec3Array_getSize(posInNm)) {
    
  }
}
