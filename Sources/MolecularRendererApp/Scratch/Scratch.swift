// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Recreate C2DonationNH using CBN's benzene geometry, attached to a silicon
// surface. This will be a challenging test of the compiler and how nonbonding
// orbitals can be used to attach atoms. It may also be interesting to see how
// this compiler can facilitate deformation/animation of individual atoms.
//
// In addition, experience using xTB for more advanced analysis:
// - derive structural parameters from simulation data (C-N bond length)
// - perform energy minimizations of the strain from germanium instead of
//   manually adjusting nearby carbons
// - potentially using minimized structures in the middle of the compilation
//   process (e.g. the strained germ-adamantane to more accurately place
//   remaining functional groups)
//
// Estimated completion date: Dec 30, 2023

// TODO:
// - minimize the leg structure in GFN2-xTB
//   - change the NH into NH2 groups
//   - add hydrogens where it will attach to the adamantane
//   - use bond lengths extracted from the results for further compilation
// - minimize the adamantane cage using GFN2-xTB
//   - add sp1-bonded carbons to the top
//   - use the results for further compilation
// - minimize the entire tripod using GFN-FF
//   - change the N-SiH3 into N-H
//   - don't add positional constraints, see whether benzenes stay in position
//   - don't use the results during further compilation; just run the simulation
//     as a sanity check
// - minimize a surface using GFN-FF
//   - passivate all silicons
//   - use the results to adjust the Si-Si and Si-H bond lengths before
//     constraining the ends of the lattice
// - minimize the entire scene using GFN-FF
//   - a silicon atom attached to the tripod can be overlaid on the lattice
//   - using Topology.match(), the closest silicon on the surface will
//     automatically be detected and bonded to the nitrogen
//   - constrain silicon and hydrogen atoms on the boundary
// - save the results
//   - remove hydrogens underneath the surface as a final touch-up
//   - save all of the code in "Materials/CBNTripod"
//   - save a screenshot
//   - copy portions of the code into an HDL unit test

func createCBNTripod() -> [MRAtom] {
  let cage = CBNTripodCage()
  let topology = cage.topology
  
  return topology.atoms.map(MRAtom.init)
}

extension CBNTripodCage {
  // Create a lattice with a germanium dopant. This will be extremely far from
  // equilibrium, but the compiled structure doesn't need to be close. It only
  // needed to be close for the tripod leg, where replacing with the minimized
  // structure constituted unacceptable information loss.
  func createLattice() -> [Entity] {
    // Create the adamantane cage with Ge and with 3 methyl groups in place of
    // the leg structures.
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 4 * h + 4 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2 * h + 2 * k + 2 * l }
        Origin { 0.25 * (h + k - l) }
        
        // Remove the front plane.
        Convex {
          Origin { 0.25 * (h + k + l) }
          Plane { h + k + l }
        }
        
        Volume {
          Convex {
            Origin { 0.2 * (h + k + l) }
            Plane { h + k + l }
          }
          
          Replace { .atom(.germanium) }
        }
        
        func triangleCut(sign: Float) {
          Convex {
            Origin { 0.25 * sign * (h - k - l) }
            Plane { sign * (h - k / 2 - l / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (k - l - h) }
            Plane { sign * (k - l / 2 - h / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (l - h - k) }
            Plane { sign * (l - h / 2 - k / 2) }
          }
        }
        
        // Keep the 3 carbons representing the legs.
        // triangleCut(sign: +1)
        
        // Remove the remaining carbons.
        triangleCut(sign: -1)
        
        // Remove the back plane.
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Replace { .empty }
      }
    }
    var atoms = lattice.atoms
    
    // Rotate the cage so the germanium points straight up, and one of the
    // legs points toward +Z.
    let basisX = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    let basisY = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
    precondition((basisX * basisY).sum().magnitude < 1e-3)
    
    func cross<T: Real & SIMDScalar>(
      _ x: SIMD3<T>, _ y: SIMD3<T>
    ) -> SIMD3<T> {
      // Source: https://en.wikipedia.org/wiki/Cross_product#Computing
      let s1 = x[1] * y[2] - x[2] * y[1]
      let s2 = x[2] * y[0] - x[0] * y[2]
      let s3 = x[0] * y[1] - x[1] * y[0]
      return SIMD3(s1, s2, s3)
    }
    let basisZ = -cross(basisX, basisY)
    let basisZLength = (basisZ * basisZ).sum().squareRoot()
    precondition((basisZLength - 1).magnitude < 1e-3)
    
    for i in atoms.indices {
      var atom = atoms[i]
      let componentX = (atom.position * basisX).sum()
      let componentY = (atom.position * basisY).sum()
      let componentZ = (atom.position * basisZ).sum()
      atom.position = SIMD3(componentX, componentY, componentZ)
      atoms[i] = atom
    }
    
    var germaniumID: Int = -1
    for i in atoms.indices {
      let atom = atoms[i]
      if atom.atomicNumber == 32 {
        germaniumID = i
      }
    }
    precondition(germaniumID != -1)
    
    // Center the cage so the germanium is at (0, 0, 0).
    let germaniumPosition = atoms[germaniumID].position
    let translation = SIMD3<Float>.zero - germaniumPosition
    for i in atoms.indices {
      atoms[i].position += translation
    }
    return atoms
  }
}
