// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func createNanomachinery() -> [MRAtom] {
  // diamond claw
  let robotClaw = createRobotClawLattice()
  var robotClawDiamondoid = Diamondoid(atoms: robotClaw.entities.map(MRAtom.init))
  let robotClawCoM = robotClawDiamondoid.createCenterOfMass()
  robotClawDiamondoid.translate(offset: [-robotClawCoM.x, 0, -robotClawCoM.z])
  
  // diamond claw topper - several small hexagonal prisms, each
  // rotated a bit
  
  // silicon carbide band
  let band = createBandLattice()
  var bandDiamondoid = Diamondoid(atoms: band.entities.map(MRAtom.init))
  bandDiamondoid.translate(offset: -bandDiamondoid.createCenterOfMass())
  bandDiamondoid.rotate(angle: Quaternion(angle: -.pi / 2, axis: [1, 0, 0]))
  bandDiamondoid.rotate(angle: Quaternion(angle: -.pi / 2, axis: [0, 1, 0]))
  
  let maxX = bandDiamondoid.atoms.reduce(-Float.greatestFiniteMagnitude) {
    max($0, $1.x)
  }
  let minY = bandDiamondoid.atoms.reduce(Float.greatestFiniteMagnitude) {
    min($0, $1.y)
  }
  bandDiamondoid.translate(offset: [6.15 - maxX, 0, 0])
  bandDiamondoid.translate(offset: [0, 2.5 - minY, 0])
  
  // silicon roof piece
  let roofPiece = createRoofPieceLattice()
  var roofPieceDiamondoid = Diamondoid(
    atoms: roofPiece.entities.map(MRAtom.init))
  roofPieceDiamondoid.translate(offset: [0, 17, 0])
  
  let diamondoids = [
    robotClawDiamondoid,
    bandDiamondoid,
    roofPieceDiamondoid
  ]
  let output = diamondoids.flatMap { $0.atoms }
//  + roofPiece.entities.map(MRAtom.init).map {
//    var copy = $0
//    copy.y += 10
//    return copy
//  }
  print(output.count)
  return output
}

func createRobotClawLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 70 * h2k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 15 * h + 10 * h2k + 2 * l }
      
      Concave {
        for direction in [h, -h, k, h + k] {
          Convex {
            Origin { 9 * direction }
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
              Origin { 14 * direction }
              Plane { direction }
            }
          }
          for direction in [-k, -h - k] {
            Convex {
              Origin { -2 * h2k }
              Origin { 14 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      for hSign in [Float(1), -1] {
        Concave {
          Origin { 35 * h2k }
          Convex {
            Origin { 6 * hSign * h }
            Plane { hSign * h + h2k }
          }
          Convex {
            Origin { 4 * hSign * h }
            Plane { hSign * h }
          }
          Convex {
            Origin { 20 * h2k }
            Origin { 6 * hSign * h }
            Plane { hSign * h - h2k  }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createBandLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 9 * h2k + 40 * l }
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
}

func createRoofPieceLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let holeSpacing: Float = 8
    let holeWidth: Float = 5
    
    let xWidth: Float = 22
    let yHeight: Float = 4
    let xCenter: Float = 7.5
    let zWidth: Float = (3*2) * holeSpacing
    let h2k = h + 2 * k
    Bounds { xWidth * h + yHeight * h2k + zWidth * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Convex {
        Origin { 1 * h }
        Plane { -h }
      }
      Convex {
        Origin { xWidth * h }
        Concave {
          Origin { yHeight/2 * h2k }
          Origin { -4 * h }
          Plane { -k + h }
          Plane { h + k + h }
        }
        
        Origin { -6 * h }
        Concave {
          Origin { 1 * h2k }
          Plane { -h2k }
          Plane { -h - k }
        }
        Concave {
          Origin { (yHeight - 1) * h2k }
          Plane { h2k }
          Plane { k }
        }
      }
      Origin { xCenter * h + yHeight/2 * h2k + 0 * l }
      
      for hDirection in [h, -h] {
        for lIndex in 0...Int(zWidth / holeSpacing + 1e-3) {
          Concave {
            Origin { 2 * hDirection }
            Plane { hDirection }
            
            Origin { holeSpacing * Float(lIndex) * l }
            Convex {
              Origin { -holeWidth/2 * l }
              Origin { -0.25 * l }
              Plane { l }
            }
            Convex {
              Origin { holeWidth/2 * l }
              Plane { -l }
            }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}
