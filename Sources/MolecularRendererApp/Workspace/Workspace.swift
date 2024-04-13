import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Test whether it works in a
// constrained MD simulation.

func createGeometry() -> [MM4RigidBody] {
  // TODO: Finish the process of serializing the half adder's housing
  // to minimize load time.
  //
  // TODO: Repeat the process to accelerate drive system load time. Serialize
  // the flywheel and connecting rod as source literals. Then, you can analyze
  // the rigid body kinetic energies with fast feedback loops.
  
  let halfAdder = HalfAdder()
//  let driveWall = halfAdder.intermediateUnit.driveWall
//  let surfaceAtoms = driveWall.extractSurfaceAtoms()
//  let serializedString = Serialization.serialize(atoms: surfaceAtoms)
//  
//  let totalAtoms = driveWall.rigidBody.parameters.atoms.count
//  let ratio = 100 * Double(surfaceAtoms.count) / Double(totalAtoms)
//  
//  print()
//  print("total atoms:", totalAtoms)
//  print("surface atoms:", surfaceAtoms.count, "(\(Int(ratio.rounded()))%)")
//  print("serialized string")
//  print(serializedString)
  
  return halfAdder.rigidBodies
}
