// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Create a bearing 50 nanometers wide.
  let backBoardLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 400 * h + 100 * h2k + 6 * l }
    Material { .checkerboard(.silicon, .carbon) }
    
    Volume {
      Origin { 90 * h + 50 * h2k }
      
      func createHexagon() {
        var hexagonDirections: [SIMD3<Float>] = []
        hexagonDirections.append(k + 2 * h)
        hexagonDirections.append(h + 2 * k)
        hexagonDirections.append(k - h)
        hexagonDirections += hexagonDirections.map(-)
        
        for directionID in hexagonDirections.indices {
          let mainDirection = hexagonDirections[directionID]
          Convex {
            Origin { 43 * mainDirection }
            Plane { mainDirection }
          }
          Concave {
            let direction2 = hexagonDirections[(directionID + 1) % 6]
            let direction3 = hexagonDirections[(directionID + 5) % 6]
            Concave {
              Origin { 35 * mainDirection }
              Plane { -mainDirection }
              Convex {
                Origin { 10 * direction2 }
                Plane { -direction2 }
              }
              Convex {
                Origin { 10 * direction3 }
                Plane { -direction3 }
              }
            }
            Convex {
              Origin { 4 * direction2 }
              Plane { direction2 }
            }
            Convex {
              Origin { 4 * direction3 }
              Plane { direction3 }
            }
            Convex {
              Origin { 11.5 * mainDirection }
              Plane { mainDirection }
            }
          }
        }
      }
      
      Concave {
        Convex {
          createHexagon()
        }
        
        Convex {
          Plane { -h }
          Convex {
            Origin { 4 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { -4 * h2k }
            Plane { -h2k }
          }
        }
        
        Convex {
          Plane { -h2k }
          Convex {
            Origin { 86 * (k + h) }
            Plane { h2k }
            Plane { k + h + h2k / 3 }
          }
          
          Concave {
            Convex {
              Origin { 86 * (k + h) }
              Origin { -9 * (k + h + h2k / 3) }
              Plane { -(k + h + h2k / 3) }
            }
            Convex {
              Origin { 86 * (k + h) }
              Plane { -k - 2 * h }
              Origin { -30 * k }
              Plane { -k + h }
            }
            Convex {
              Origin { 171 * h }
              Plane { k - h }
            }
            Convex {
              Origin { 183 * h }
              Plane { -k - 2 * h }
            }
          }
        }
        Convex {
          Plane { h2k }
          Convex {
            Origin { 86 * (-k) }
            Plane { -h2k }
            Plane { -k - h2k / 3 }
          }
          
          Concave {
            Convex {
              Origin { 86 * (-k) }
              Origin { -9 * (-k - h2k / 3) }
              Plane { -(-k - h2k / 3) }
            }
            Convex {
              Origin { 86 * (-k) }
              Plane { k - h }
              Origin { -30 * (-k - h) }
              Plane { k + 2 * h }
            }
            Convex {
              Origin { 171 * h }
              Plane { -k - 2 * h }
            }
            Convex {
              Origin { 183 * h }
              Plane { k - h }
            }
          }
        }
      }
      
      Replace { .empty }
    }
  }
  
  var backBoardAtoms = backBoardLattice.atoms
  var accumulator: SIMD3<Double> = .zero
  var mass: Double = .zero
  for atom in backBoardAtoms {
    let atomMass = Float(atom.atomicNumber)
    accumulator += SIMD3<Double>(atomMass * atom.position)
    mass += Double(atomMass)
  }
  let centerOfMass = SIMD3<Float>(accumulator / mass)
  for i in backBoardAtoms.indices {
    backBoardAtoms[i].position -= centerOfMass
  }
  
  // 115 ms
  
  // 468 ms
  var topology = Topology()
  topology.insert(atoms: backBoardAtoms)
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .checkerboard(.silicon, .carbon)
  reconstruction.topology = topology
  reconstruction.removePathologicalAtoms()
  reconstruction.createBulkAtomBonds()
  reconstruction.createHydrogenSites()
  reconstruction.resolveCollisions()
  reconstruction.createHydrogenBonds()
  topology = reconstruction.topology
  topology.sort()
  
  // 2717 ms
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  // 11750 ms
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  forceFieldDesc.integrator = .verlet
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  _ = forceField.forces
  print(forceField.energy.kinetic)
  print(forceField.energy.potential)
  
  /*
   0.0
   -82574540.5
   atoms: 636834
   compile time: 11508.8 ms
   
   0.0
   -82574541.0
   atoms: 636834
   compile time: 11643.4 ms
   
   0.0
   -82574540.5
   atoms: 636834
   compile time: 11501.6 ms
   */
  
  /*
   0.0
   -82574540.5
   atoms: 636834
   compile time: 11457.7 ms
   */
  
  /*
   0.0
   -5648576.0625
   atoms: 636834
   compile time: 11376.1 ms
   */
  
  /*
   0.0
   -82574538.5
   atoms: 636834
   compile time: 11472.7 ms
   
   0.0
   -82574541.5
   atoms: 636834
   compile time: 11172.1 ms
   
   0.0
   -82574540.0
   atoms: 636834
   compile time: 1124
   
   0.0
   -82574540.0
   atoms: 636834
   compile time: 11067.7 ms
   */
  
  // Does the original code ever produce 40.0 or 38.5?
  
  /*
   0.0
   -82574538.5
   atoms: 636834
   compile time: 11534.1 ms
   
   0.0
   -82574540.0
   atoms: 636834
   compile time: 11461.1 ms
   */
  
  return topology.atoms
  
  /*
  
  // 11874 ms - 1 iteration
  // 17745 ms - full minimization
//  forceField.minimize()
//  for i in topology.atoms.indices {
//    topology.atoms[i].position = forceField.positions[i]
//  }
  
  var output: [[Entity]] = []
  for frameID in 0...120 {
    // run an MD simulation of the structure
    print("frame \(frameID)")
    if frameID > 0 {
      forceField.simulate(time: 0.010)
    }
    
    var frame: [Entity] = []
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position = forceField.positions[atomID]
      frame.append(atom)
    }
    output.append(frame)
  }
  return output
   */
}
