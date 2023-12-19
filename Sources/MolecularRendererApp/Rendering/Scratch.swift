// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

// TODO: Move this scratch into the hardware catalog instead of a
// GitHub gist. Name the folder "ConvergentAssemblyArchitecture".
// - Add thumbnail to folder once the film is released.
// - Also add poster cataloguing the crystolecules.

func createNanomachinery() -> [MRAtom] {
  let scene = FactoryScene()
  Media.reportBillOfMaterials(scene)
  
  // The final version of the output will sort crystolecules by their bounding
  // boxes and produce a better image. It will be a 2D arrangement, curved to
  // surround the user.
  // - Every crystolecule's maximum Z coordinate must be flush.
  // - Reorient the parts toward the best direction for presentation.
  // - Curve the flush Z sheet around the user.
  
  struct Figure {
    var atoms: [MRAtom]
    var bounds: SIMD3<Float>
    var offset: SIMD2<Float>?
  }
  var figures: [Figure?] = []
  
  for crystolecule in Media.Crystolecule.allCases {
    let (atoms, offset) = createCrystoleculeAtoms(crystolecule)
    guard let atoms else {
      figures.append(nil)
      continue
    }
    
    var min = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var max = -min
    for i in atoms.indices {
      let origin = atoms[i].origin
      min.replace(with: origin, where: origin .< min)
      max.replace(with: origin, where: origin .> max)
    }
    let median = (min + max) / 2
    var centeringOperation = SIMD3<Float>.zero - median
    centeringOperation.z = 0 - max.z
    
    var outputAtoms = atoms
    for i in outputAtoms.indices {
      outputAtoms[i].origin += centeringOperation
    }
    figures.append(
      Figure(atoms: outputAtoms, bounds: max - min, offset: offset))
  }
  
  var output: [MRAtom] = []
  for figureID in figures.indices {
    guard let figure = figures[figureID] else {
      continue
    }
    // Use these default values until all crystolecules have an offset
    // manually assigned.
    let xProgress = Float(figureID % 5)
    let yProgress = Float(figureID / 5)
    var x = 10 * xProgress
    var y = 10 * yProgress
    if let offset = figure.offset {
      x = offset.x
      y = offset.y
    }
    for var atom in figure.atoms {
      atom.origin += SIMD3(x, y, 0)
      output.append(atom)
    }
  }
  return output
}

// The function returns an optional value so it can function while partially
// incomplete.
func createCrystoleculeAtoms(
  _ crystolecule: Media.Crystolecule
) -> (
  atoms: [MRAtom]?, offset: SIMD2<Float>?
) {
  switch crystolecule {
  case .backBoard1:
    return (nil, nil)
  case .backBoard2:
    return (nil, nil)
  case .beltLink:
    return (nil, nil)
  case .broadcastRod:
    return (nil, nil)
  case .floorHexagon:
    let lattice = createFloorHexagon(radius: 8.5, thickness: 10)
    var master = Diamondoid(lattice: lattice)
    master.setCenterOfMass(.zero)
    return (master.atoms, nil)
  case .geHousing:
    let housingLattice = createAssemblyHousing(terminal: false)
    var housing1 = Diamondoid(lattice: housingLattice)
    housing1.setCenterOfMass(.zero)
    return (housing1.atoms, nil)
  case .geCDodecagon:
    return (nil, nil)
  case .receiverRod0:
    return (nil, nil)
  case .receiverRod1:
    return (nil, nil)
  case .receiverRod2:
    return (nil, nil)
  case .receiverRod3:
    return (nil, nil)
  case .receiverRod4:
    return (nil, nil)
  case .receiverRod5:
    return (nil, nil)
  case .robotArmBand:
    return (nil, nil)
  case .robotArmClaw:
    return (nil, nil)
  case .robotArmRoof1:
    return (nil, nil)
  case .robotArmRoof2:
    return (nil, nil)
  case .servoArmConnector:
    let lattice = createServoArmConnector()
    let connector = Diamondoid(lattice: lattice)
    return (connector.atoms, nil)
  case .servoArmGripper:
    let lattice = createServoArmGripper()
    let gripper = Diamondoid(lattice: lattice)
    return (gripper.atoms, nil)
  case .servoArmHexagon1:
    let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
    var hexagon = Diamondoid(lattice: latticeHexagon)
    hexagon.setCenterOfMass(.zero)
    hexagon.translate(offset: [0, 15.7, -2.5])
    return (hexagon.atoms, nil)
  case .servoArmHexagon2:
    let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
    var hexagon = Diamondoid(lattice: latticeHexagon)
    hexagon.setCenterOfMass(.zero)
    hexagon.translate(offset: [0, 15.7, -2.5])
    
    let hexagon2Atoms = hexagon.atoms.filter {
      $0.element != 1 && $0.x < 1e-3
    }
    let hexagon2 = Diamondoid(atoms: hexagon2Atoms)
    return (hexagon2.atoms, nil)
  case .servoArmHexagon3:
    let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
    var hexagon = Diamondoid(lattice: latticeHexagon)
    hexagon.setCenterOfMass(.zero)
    hexagon.translate(offset: [0, 15.7, -2.5])
    
    let boundingBox = hexagon.createBoundingBox()
    let y = (boundingBox.0.y + boundingBox.1.y) / 2
    let upperHexagonAtoms = hexagon.atoms.filter {
      ($0.origin.y > y - 1e-3) && ($0.element != 1)
    }
    let upperHexagon = Diamondoid(atoms: upperHexagonAtoms)
    return (upperHexagon.atoms, nil)
  case .servoArmPart1:
    let lattice1 = createServoArmPart1()
    let diamondoid1 = Diamondoid(lattice: lattice1)
    return (diamondoid1.atoms, nil)
  case .weldingStand:
    return (nil, nil)
  }
}
