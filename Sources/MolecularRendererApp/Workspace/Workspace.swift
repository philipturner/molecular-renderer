import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Place the adder in the scene.
// Test whether it works in a constrained MD simulation, but delete the code
// and don't worry about animating it right now.
//
// Extract each logic rod, remove the hydrogens on one side, and arrange the
// finished products on the silicon surface. Compile a complete build sequence
// for every rod.

func createGeometry() -> [MM4RigidBody] {
  let halfAdder = HalfAdder()
  let output = halfAdder.rigidBodies
  
  var minPosition = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maxPosition = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for position in output.flatMap(\.positions) {
    minPosition.replace(with: position, where: position .< minPosition)
    maxPosition.replace(with: position, where: position .> maxPosition)
  }
  
  // atoms: 57846            | 4820 atoms/switch
  // 10.5 nm x 6.5 nm x 8 nm | Fits within a 10 nm cube.
  //
  // SIMD3<Float>(-0.31116438, -0.080884695, -2.0427346)
  // SIMD3<Float>(9.890136, 6.144785, 5.3840904)
  // SIMD3<Float>(10.5293, 6.55367, 7.754825)
  print(minPosition)
  print(maxPosition)
  print(maxPosition - minPosition + 2 * 1.640 / 10)
  
  return output
}
