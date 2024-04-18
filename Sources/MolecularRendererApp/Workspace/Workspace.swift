import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Stick with cubic diamond for this, despite the warping issue.
  // - Keep the cylinder, but shrink it.
  // - Superimpose an H structure, then warp into a strained shell.
  // - Check the radius of curvature and curl of protrusions with Ge dopants.
  //
  // - Create a piecewise function to only warp certain chunks of the structure,
  //   each at a slightly different center of curvature.
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 14 * k + 10 * l }
    Material { .elemental(.carbon) }
    
    // TODO: Replace each instance of 'h' with a series of one-atomic-layer
    // ledges.
    Volume {
      Concave {
        Convex {
          Origin { 1.25 * h }
          Plane { h }
        }
        Convex {
          Origin { 6 * k }
          Plane { -k }
        }
        Convex {
          Origin { 8.75 * h }
          Plane { -h }
        }
      }
      
      Concave {
        Convex {
          Origin { 1.25 * h }
          Plane { h }
        }
        Convex {
          Origin { 8 * k }
          Plane { k }
        }
        Convex {
          Origin { 8.75 * h }
          Plane { -h }
        }
      }
      
      Replace { .empty }
    }
    
    Volume {
//      for indexK in 0...20 {
//        Concave {
//          Origin { Float(indexK) * 1 * k }
//          Origin { -0.125 * (h + k) }
//          Plane { h }
//          Plane { k }
//          Origin { 0.25 * (h + k) }
//          Plane { -h }
//          Plane { -k }
//        }
//      }
      
      Convex {
        Origin { 0.125 * h }
        Plane { -h }
      }
      Convex {
        Origin { 9.875 * h }
        Plane { h }
      }
      
      Replace { .atom(.germanium) }
    }
  }
  
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .elemental(.carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize()
  
  for atomID in topology.atoms.indices {
    let position = forceField.positions[atomID]
    topology.atoms[atomID].position = position
  }
  return topology.atoms
}
