//
//  OpenMM_Provider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import Foundation
import OpenMM
import MolecularRenderer

// The results of an OpenMM simulation. Currently, the data must be generated
// inside OpenMM at app launch time.

// Create a number of steps per frame; to add another frame, it validates the
// number of steps equals what you set. Also check that the number of atoms
// equals the number of atomic numbers.
class OpenMM_AtomProvider: MRAtomProvider {
  private(set) var psPerStep: Double
  private(set) var stepsPerFrame: Int
  private(set) var styles: [MRAtomStyle]
  private(set) var elements: [UInt8]
  private(set) var states: [[MRAtom]] = []
  
  // Specify each atom's atomic number beforehand; OpenMM doesn't provide that.
  init(
    psPerStep: Double,
    stepsPerFrame: Int,
    styles: [MRAtomStyle],
    elements: [UInt8]
  ) {
    self.psPerStep = psPerStep
    self.stepsPerFrame = stepsPerFrame
    self.styles = styles
    self.elements = elements
  }
  
  func append(state: OpenMM_State, steps: Int) {
    let positions = state.positions
    precondition(positions.size == elements.count, "Incorrect number of atoms.")
    if states.count == 0 {
      precondition(steps == 0, "First frame must have zero steps.")
    } else {
      precondition(steps == stepsPerFrame, "Incorrect number of steps.")
    }
    
    let atoms = [MRAtom](
      unsafeUninitializedCapacity: elements.count
    ) { buffer, count in
      for i in 0..<elements.count {
        let posInNm = SIMD3<Float>(positions[i])
        let atom = MRAtom(styles: styles, origin: posInNm, element: elements[i])
        buffer[i] = atom
      }
      count = elements.count
    }
    self.states.append(atoms)
  }
  
  // Move to the next frame. Call this **after** reading from the states.
  func atoms(time: MRTimeContext) -> [MRAtom] {
    let fps = MRGetFrameRate()
    precondition(120 % fps == 0)
    let frameAmplificationFactor = 120 / fps
    
    var frameID = time.absolute.frames * frameAmplificationFactor
    frameID = min(frameID, states.count - 1)
    return states[frameID]
  }
}
