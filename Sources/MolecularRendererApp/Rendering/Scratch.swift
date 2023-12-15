// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func createNanomachinery() -> [MRAtom] {
  // diamond claw
  let robotClaw = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 30 * h2k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 15 * h + 10 * h2k + 2 * l }
      
      Concave {
        for direction in [h, -h, k, h + k] {
          Convex {
            Origin { 7 * direction }
            Plane { -direction }
          }
        }
      }
      Concave {
        Convex {
          for direction in [h, -h] {
            Convex {
              Origin { 6 * direction }
              Plane { direction }
            }
          }
        }
        Convex {
          for direction in [h, -h, k, h + k] {
            Convex {
              Origin { 12 * direction }
              Plane { direction }
            }
          }
          for direction in [-k, -h - k] {
            Convex {
              Origin { -2 * h2k }
              Origin { 12 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      Replace { .empty }
    }
  }
  var robotClawDiamondoid = Diamondoid(atoms: robotClaw.entities.map(MRAtom.init))
  let robotClawCoM = robotClawDiamondoid.createCenterOfMass()
  robotClawDiamondoid.translate(offset: [-robotClawCoM.x, 0, -robotClawCoM.z])
  
  // silicon carbide band
  let band = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 9 * h2k + 20 * l }
    Material { .checkerboard(.carbon, .silicon) }
    
    Volume {
      Origin { 5 * h + 3.5 * h2k + 0 * l }
      
      Concave {
        Origin { -0.25 * h2k }
        for direction in [4 * h, 1.75 * h2k, -4 * h, -2.25 * h2k] {
          Convex {
            Origin { 1 * direction }
            Plane { -direction }
          }
        }
      }
      
      for directionPair in [(h, 2 * h + k), (-h, k - h)] {
        Concave {
          Convex {
            Origin { 2 * directionPair.0 }
            Plane { directionPair.0 }
          }
          Convex {
            Origin { 3.75 * directionPair.1 }
            Plane { directionPair.1 }
          }
        }
      }
      
      Concave {
        Origin { 2.8 * l }
        Plane { l }
        Origin { 2 * h2k }
        Plane { -h2k }
      }
      
      for direction in [h, -h] {
        Concave {
          Origin { 2.8 * l }
          Plane { l }
          Origin { 2 * direction }
          Plane { direction }
        }
      }
      
      Replace { .empty }
    }
  }
  var bandDiamondoid = Diamondoid(atoms: band.entities.map(MRAtom.init))
  bandDiamondoid.translate(offset: -bandDiamondoid.createCenterOfMass())
  bandDiamondoid.rotate(angle: Quaternion(angle: -.pi / 2, axis: [1, 0, 0]))
  bandDiamondoid.rotate(angle: Quaternion(angle: -.pi / 2, axis: [0, 1, 0]))
  bandDiamondoid.translate(offset: [4.2, 0, 0])
  bandDiamondoid.translate(offset: [0, 7, 0])
  
  // silicon housing
  
  let diamondoids = [
    robotClawDiamondoid,
    bandDiamondoid
  ]
  let output = diamondoids.flatMap { $0.atoms }
  print(output.count)
  return output
}
