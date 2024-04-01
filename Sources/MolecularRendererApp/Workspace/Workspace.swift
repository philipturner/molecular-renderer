import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [MM4RigidBody] {
  // TODO: Set up a flywheel-driven clocking mechanism for a system of four
  // logic rods, with a single clock phase. This enables autonomous RBD/MD
  // simulation without any positional constraints.
  
  let flywheelHousingLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 100 * h + 50 * h2k + 6 * l }
    Material { .checkerboard(.carbon, .germanium) }
    
    Volume {
      Origin { 50 * h + 25 * h2k }
      
      var directions: [SIMD3<Float>] = []
      directions.append(h)
      directions.append((h + k + h) / Float(3).squareRoot())
      directions.append(k + h)
      directions.append((k + h + k) / Float(3).squareRoot())
      directions.append(k)
      directions.append((k - h) / Float(3).squareRoot())
      directions += directions.map(-)
      
      // Trim the inner side, where the flywheel will reside.
      Concave {
        Convex {
          Origin { 3.99 * l }
          Plane { l }
        }
        for direction in directions {
          Convex {
            Origin { 33 * direction }
            Plane { -direction }
          }
        }
      }
      Concave {
        for direction in directions {
          Convex {
            Origin { 25 * direction }
            Plane { -direction }
          }
        }
      }
      
      // Trim the outer side.
      for direction in directions {
        Convex {
          Origin { 40 * direction }
          Plane { direction }
        }
      }
      for direction in directions {
        Convex {
          Origin { 35 * direction }
          Plane { direction - l }
        }
      }
      
      Replace { .empty }
    }
  }
  
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .checkerboard(.carbon, .germanium)
  reconstruction.topology.insert(atoms: flywheelHousingLattice.atoms)
  reconstruction.compile()
  reconstruction.topology.sort()
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = reconstruction.topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = reconstruction.topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = reconstruction.topology.atoms.map(\.position)
  forceField.minimize()
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.parameters = parameters
  rigidBodyDesc.positions = forceField.positions
  let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  return [rigidBody]
}
