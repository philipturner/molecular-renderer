import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [MM4RigidBody] {
  var part = RotaryPart()
  part.minimize(bulkAtomIDs: [])
  
  var minRadius: Float = .greatestFiniteMagnitude
  var maxRadius: Float = .zero
  let center = SIMD3<Float>(part.rigidBody.centerOfMass)
  
  for atomID in part.rigidBody.parameters.atoms.indices {
    let position = part.rigidBody.positions[atomID]
    var delta = position - center
    delta.z = .zero
    
    let r = (delta.x * delta.x + delta.y * delta.y).squareRoot()
    minRadius = min(minRadius, r)
    maxRadius = max(maxRadius, r)
  }
  print(minRadius)
  print(maxRadius)
  
  exit(0)
}
