import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms, and serialize the atoms as a
// base64 string. Place the adder somewhere in the scene. Also, design the
// drive wall that actuates the rods.
// - Lay out all of the housing and drive walls, before adding any patterns to
//   the logic rods.
// - Try just serializing the surface atoms. Erase the bond topology and move
//   the serialized atoms to the end of the list.
// - Serialize the results of a few energy-conserving RBD simulations. You only
//   need to store the offset and rotation matrix for each rigid body, in each
//   simulation frame.
//
// Extract each logic rod, remove the hydrogens on one side, and place the
// finished products on the silicon surface. If we can compile a build
// sequence for one, compiling sequences for the rest should be trivial.

func createGeometry() -> [MM4RigidBody] {
  // TODO:
  // - Create the patterns on the logic rods, once you know the directions
  //   they will move. TODO: What if I can simplify the knob / <s>dopant</s>
  //   [NOT YET] placement procedure? Using parametric methods to locate an
  //   integer multiple of the lattice constant.
  
  // TODO: Visualize each design specification. Design it once, then throw away
  // the code for designing it. Reformulate what you've learned into a
  // semi-automated procedure for getting the right lattice constant. Perhaps
  // SurfaceReconstruction already automates the required trimming.
  
  let createDriveWallInterface: KnobPattern = { h, h2k, l in
    Concave {
      Concave {
        Origin { 1 * h2k }
        Plane { h2k }
        Origin { 1 * h }
        Plane { h2k - 3 * h } // k - h
      }
      Convex {
        Origin { 1.5 * h2k }
        Plane { h2k }
        Origin { 0.5 * h }
        Plane { -h }
      }
    }
    Replace { .empty }
  }
  
  // Inclusive bounds for each indent, in cubic diamond unit cells.
  var indents: [SIMD2<Float>] = []
  indents.append(SIMD2(2.5, 6.5))
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 1)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 2)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 3)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 4)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 5)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 6)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 7)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 8)
  indents.append(SIMD2(2.5, 6.5) + 6.25 * 9)
  
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 100 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      createDriveWallInterface(h, h2k, l)
    }
    
    Volume {
      for indent in indents {
        let cubicLatticeConstant = Constant(.square) {
          .elemental(.carbon)
        }
        let hexagonalLatticeConstant = Constant(.hexagon) {
          .elemental(.carbon)
        }
        let scaled = indent * cubicLatticeConstant / hexagonalLatticeConstant
        
        Concave {
          Concave {
            Origin { Float(scaled[0]).rounded(.down) * h }
            Plane { h }
          }
          Concave {
            Origin { 0.49 * h2k }
            Plane { -h2k }
          }
          Concave {
            Origin { Float(scaled[1]).rounded(.up) * h }
            Plane { -h }
          }
        }
      }
      Replace { .empty }
    }
  }
  
  let rod = Rod(lattice: lattice)
  
  return [rod.rigidBody]
}
