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
class OpenMM_DynamicAtomProvider: MRStaticAtomProvider {
  private(set) var psPerStep: Double
  private(set) var stepsPerFrame: Int
  private(set) var styles: [MRAtomStyle]
  private(set) var elements: [UInt8]
  private(set) var states: [[MRAtom]] = []
  
  private(set) var replayingFrameID: Int = 0
  
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
  
  var atoms: [MolecularRenderer.MRAtom] {
    states[replayingFrameID]
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
  
  func logReplaySpeed(framesPerSecond: Int) {
    let psPerFrame = psPerStep * Double(stepsPerFrame)
    let replaySpeed = Float(psPerFrame * Double(framesPerSecond))
    print("Replaying at \(replaySpeed) ps/s.")
  }
  
  func reset() {
    self.replayingFrameID = 0
  }
  
  // Move to the next frame. Call this **after** reading from the states.
  func nextFrame() {
    self.replayingFrameID += 1
    
    // If you reach the end, don't make forward progress.
    if replayingFrameID >= states.count {
      self.replayingFrameID -= 1
    }
  }
}
