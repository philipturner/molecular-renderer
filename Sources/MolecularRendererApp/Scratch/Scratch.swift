// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Create a setup that can test all of the 2-input gates.
// - Use the new "Collision Detection" level of theory.
//
// Speculation about how one would explain the levels of theory in
// a video:
//
// There are four levels of theory:
// - Semiempirical Quantum Mechanics
//   - CBN tripod adding carbenic feedstock to logic rod fragment,
//     with frame interpolation *
// - Molecular Mechanics
//   - Obstructed and mobile states of a single logic switch
// - Rigid Body Mechanics
//   - Experiment with the SiC drive wall, with a cross-section
// - Collision Detection
//   - Clock cycle of a 4-bit RCA, with housing omitted
//
// Multiscale simulation enables the design and testing of
// large nanosystems, in full atomic detail.
//
// With only the compute power of a single GPU.
//
// * Project idea: simulate the CBN tripod HDon reaction with frame
//   interpolation. Profile xTB in Xcode, to see whether most of the
//   time is spent in LAPACK.
func createGeometry() -> [[Entity]] {
  let inputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 15 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  let outputRodLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 1.5 * h2k }
      Concave {
        Plane { h2k }
        Origin { 3 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 7 * h }
        Plane { h }
        Origin { 7 * h }
        Plane { -h }
      }
      Concave {
        Plane { h2k }
        Origin { 18 * h }
        Plane { h }
      }
      Replace { .empty }
    }
  }
  
  // Set the starting position for the first input rod.
  var atomsInput1 = inputRodLattice.atoms
  for atomID in atomsInput1.indices {
    var atom = atomsInput1[atomID]
    atom.position.y = -atom.position.y
    atom.position.y += 2.0
    atom.position = SIMD3(
      atom.position.z, atom.position.y, atom.position.x)
    atom.position.z += -0.9
    atomsInput1[atomID] = atom
  }
  
  // Set the starting position for the second input rod.
  var atomsInput2 = atomsInput1
  for atomID in atomsInput2.indices {
    var atom = atomsInput2[atomID]
    atom.position.x += 2.8
    atomsInput2[atomID] = atom
  }
  
  #if false
  do {
    var atomsInput = atomsInput1
    
    // Change into a NOT gate.
    var inputCenterOfMass: SIMD3<Float> = .zero
    for atom in atomsInput {
      inputCenterOfMass += atom.position
    }
    inputCenterOfMass /= Float(atomsInput.count)
    for atomID in atomsInput.indices {
      var atom = atomsInput[atomID]
      var deltaZ = atom.position.z - inputCenterOfMass.z
      deltaZ = -deltaZ
      atom.position.z = deltaZ + inputCenterOfMass.z
      atomsInput[atomID] = atom
    }
    
    atomsInput1 = atomsInput
  }
  #endif
  
  #if true
  do {
    var atomsInput = atomsInput2
    
    // Change into a NOT gate.
    var inputCenterOfMass: SIMD3<Float> = .zero
    for atom in atomsInput {
      inputCenterOfMass += atom.position
    }
    inputCenterOfMass /= Float(atomsInput.count)
    for atomID in atomsInput.indices {
      var atom = atomsInput[atomID]
      var deltaZ = atom.position.z - inputCenterOfMass.z
      deltaZ = -deltaZ
      atom.position.z = deltaZ + inputCenterOfMass.z
      atomsInput[atomID] = atom
    }
    
    atomsInput2 = atomsInput
  }
  #endif
  
  // Set the starting position for the output rod.
  var atomsOutput = outputRodLattice.atoms
  for atomID in atomsOutput.indices {
    var atom = atomsOutput[atomID]
    atom.position.x += -2.3
    atomsOutput[atomID] = atom
  }
  
  // Setup:
  // - Move the input rods forward, independently of whether you
  //   turned them into NOT gates. Specify an array of input bits
  //   and print a bit representing the output to the console.
  var frames: [[Entity]] = []
  for _ in 0..<60 {
    for atomID in atomsInput1.indices {
      atomsInput1[atomID].position.z += -0.02
    }
    for atomID in atomsInput2.indices {
      atomsInput2[atomID].position.z += -0.02
    }
    frames.append(atomsInput1 + atomsInput2 + atomsOutput)
  }
  
  // Turn the parts red, until ~1 second after the collision. This
  // could allow for debugging the time at which events occur.
  
  for _ in 0..<300 {
    var nextAtomsOutput = atomsOutput
    for atomID in nextAtomsOutput.indices {
      nextAtomsOutput[atomID].position.x += 0.02
    }
    atomsOutput = nextAtomsOutput
    
    // Profile how much latency is incurred by 300 frames of
    // collision detection here.
        
    frames.append(atomsInput1 + atomsInput2 + atomsOutput)
  }
  
  return frames
}
