// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  var descriptor = IsobutaneDescriptor()
  let isobutane = Isobutane(descriptor: descriptor)
  return isobutane.topology.atoms
}

// MARK: - Structures

enum Passivation {
  case acetyleneRadical
  case hydrogen
  case radical
}

struct IsobutaneDescriptor {
  var bulkElement: Element = .carbon
  var tipElement: Element = .carbon
  var passivation: Passivation = .hydrogen
}

// TODO: Modify this to be an arbitrary tooltip. Allow the body to consist of
// hydrogen atoms, with a smaller atom count and different identity of anchor
// atoms.
struct Isobutane {
  var topology = Topology()
  var anchors: [UInt32] = []
  var tipAtomID: UInt32 = .max
  
  init(descriptor: IsobutaneDescriptor) {
    compilationPass0(bulkElement: descriptor.bulkElement)
    compilationPass1()
    compilationPass2(bulkElement: descriptor.bulkElement)
    compilationPass3(bulkElement: descriptor.bulkElement)
    compilationPass4(bulkElement: descriptor.bulkElement)
    compilationPass5(descriptor: descriptor)
    compilationPass6(tipElement: descriptor.tipElement)
  }
  
  // Create the center atoms.
  mutating func compilationPass0(bulkElement: Element) {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 2 * (h + k + l) }
      Material { .elemental(bulkElement) }
      
      Volume {
        Convex {
          let direction = -h + k + l
          Origin { direction }
          Plane { -direction }
        }
        Convex {
          let direction = -h + k + l
          Origin { 1.2 * direction }
          Plane { direction }
        }
        Replace { .empty }
        
        // Mark the apex atom with lead. This will never be used as a bulk or
        // tip element.
        Convex {
          let direction = -h + k + l
          Origin { 1.05 * direction }
          Plane { direction }
        }
        Replace { .atom(.lead) }
      }
    }
    topology.atoms = lattice.atoms
  }
  
  // Rotate so the tip points right.
  mutating func compilationPass1() {
    var basisVector1: SIMD3<Float> = [-1, 1, 1]
    var basisVector2: SIMD3<Float> = [1, 0, 1]
    basisVector1 /= (basisVector1 * basisVector1).sum().squareRoot()
    basisVector2 /= (basisVector2 * basisVector2).sum().squareRoot()
    
    var basisVector3 = cross_platform_cross(basisVector1, basisVector2)
    basisVector3 /= (basisVector3 * basisVector3).sum().squareRoot()
    
    for atomID in topology.atoms.indices {
      var position = topology.atoms[atomID].position
      let xComponent = (position * basisVector1).sum()
      let zComponent = (position * basisVector2).sum()
      let yComponent = (position * basisVector3).sum()
      position = [xComponent, yComponent, zComponent]
      topology.atoms[atomID].position = position
    }
    
    // Adjust so the tip atom is the origin.
    var tipPosition: SIMD3<Float>?
    for atom in topology.atoms {
      if atom.atomicNumber == Element.lead.rawValue {
        tipPosition = atom.position
      }
    }
    for atomID in topology.atoms.indices {
      topology.atoms[atomID].position -= tipPosition!
    }
  }
  
  // Remove the pathological atoms.
  mutating func compilationPass2(bulkElement: Element) {
    let matches = topology.match(
      topology.atoms,
      algorithm: .absoluteRadius(bulkElement.covalentRadius * 2.2))
    
    var removedAtoms: [UInt32] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
      if matches[i].count == 1 {
        removedAtoms.append(UInt32(i))
      }
    }
    topology.insert(bonds: insertedBonds)
    topology.remove(atoms: removedAtoms)
  }
  
  // Add the hydrogens pointing in the X direction.
  // - NOTE: This sets the anchor indices. It assumes the atoms at the
  //   beginning of the list won't change position.
  mutating func compilationPass3(bulkElement: Element) {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        continue
      } else {
        let chBondLength = Self.hydrogenBondLength(element: bulkElement)
        let orbital: SIMD3<Float> = [-1, 0, 0]
        let position = atom.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
        
        anchors.append(UInt32(hydrogenID))
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Add hydrogens to the sidewall atoms.
  mutating func compilationPass4(bulkElement: Element) {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        continue
      } else {
        for orbital in orbitals[atomID] {
          let chBondLength = Self.hydrogenBondLength(element: bulkElement)
          let position = atom.position + orbital * chBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        }
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Add the passivator.
  mutating func compilationPass5(descriptor: IsobutaneDescriptor) {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        switch descriptor.passivation {
        case .acetyleneRadical:
          let xcBondLength = Self.acetyleneBondLength(
            element: descriptor.tipElement)
          let orbital1: SIMD3<Float> = [1, 0, 0]
          let position1 = atom.position + orbital1 * xcBondLength
          let carbon1 = Entity(position: position1, type: .atom(.carbon))
          
          let carbonID1 = topology.atoms.count + insertedAtoms.count
          let bond1 = SIMD2(UInt32(atomID), UInt32(carbonID1))
          insertedAtoms.append(carbon1)
          insertedBonds.append(bond1)
          
          let ccBondLength: Float = 1.2100 / 10
          let orbital2: SIMD3<Float> = [1, 0, 0]
          let position2 = position1 + orbital2 * ccBondLength
          let carbon2 = Entity(position: position2, type: .atom(.carbon))
          
          let carbonID2 = topology.atoms.count + insertedAtoms.count
          let bond2 = SIMD2(UInt32(carbonID1), UInt32(carbonID2))
          insertedAtoms.append(carbon2)
          insertedBonds.append(bond2)
        case .hydrogen:
          let xhBondLength = Self.hydrogenBondLength(
            element: descriptor.tipElement)
          let orbital: SIMD3<Float> = [1, 0, 0]
          let position = atom.position + orbital * xhBondLength
          let hydrogen = Entity(position: position, type: .atom(.hydrogen))
          
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        case .radical:
          break
        }
      } else {
        continue
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Transmute the lead marker into the tip element.
  mutating func compilationPass6(tipElement: Element) {
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == Element.lead.rawValue {
        topology.atoms[atomID].atomicNumber = tipElement.rawValue
        self.tipAtomID = UInt32(atomID)
      }
    }
  }
}

extension Isobutane {
  // The bond length between and sp3 element and hydrogen.
  static func hydrogenBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.1120 / 10
    case .silicon:
      return 1.483 / 10
    case .germanium:
      return 1.529 / 10
    case .tin:
      return 1.6960 / 10
    default:
      fatalError("Unexpected element for X-H bond.")
    }
  }
  
  // The bond length between and sp3 element and sp1 carbon.
  static func acetyleneBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.4700 / 10
    case .silicon:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      return (1.8540 + sp1sp2Difference) / 10
    case .germanium:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      return (1.9350 + sp1sp2Difference) / 10
    case .tin:
      let sp1sp2Difference: Float = 1.4700 - 1.4990
      let snGeDifference: Float = 2.1470 - 1.9490
      return (1.9350 + sp1sp2Difference + snGeDifference) / 10
    default:
      fatalError("Unexpected element for X-CC bond.")
    }
  }
}

struct Graphene {
  var topology = Topology()
  var anchors: [UInt32] = []
  
  init() {
    let lattice = createLattice()
    topology.insert(atoms: lattice.atoms)
    
    adjustLatticeAtoms()
    removeCenterMarker()
    addHydrogens()
    removeAnchorMarkers()
  }
  
  mutating func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 2 * h + 2 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.3 * l }
          Plane { l }
        }
        Convex {
          Origin { 1 * h + 1.75 * h2k }
          Plane { k - h }
          Plane { k + 2 * h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Replace { .empty }
      }
      
      Volume {
        Origin { h + 0.8 * h2k }
        Concave {
          var directions: [SIMD3<Float>] = []
          directions.append(h)
          directions.append(h2k)
          directions.append(-h)
          directions.append(-h2k)
          for direction in directions {
            Convex {
              Origin { 0.3 * direction }
              Plane { -direction }
            }
          }
        }
        Replace { .atom(.gold) }
      }
      
      Volume {
        Origin { h + 0.625 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h2k)
        directions.append(-k + h)
        directions.append(-k - 2 * h)
        for direction in directions {
          Convex {
            Origin { 0.55 * direction }
            Plane { direction }
          }
        }
        Replace { .atom(.silicon) }
      }
    }
  }
  
  // Center the lattice at the origin, and scale it to the graphene lattice
  // constant.
  mutating func adjustLatticeAtoms() {
    var goldPosition: SIMD3<Float>?
    for atom in topology.atoms {
      if atom.atomicNumber == 79 {
        goldPosition = atom.position
      }
    }
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position -= goldPosition!
      atom.position.z = 0
      topology.atoms[atomID] = atom
    }
    
    let grapheneConstant: Float = 2.45 / 10
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    let scaleFactor = grapheneConstant / lonsdaleiteConstant
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position *= scaleFactor
      topology.atoms[atomID] = atom
    }
  }
  
  // Transmute the gold atom to carbon.
  mutating func removeCenterMarker() {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 79 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Add hydrogens to the perimeter of the graphene flake.
  mutating func addHydrogens() {
    let searchRadius = 2.1 * Element.carbon.covalentRadius
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(searchRadius))
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in matches.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      for orbital in orbitals[atomID] {
        // Source: MM4/TinkerParameters
        let chBondLength: Float = 1.1010 / 10
        let position = atom.position + chBondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Mark the anchors and transmute the silicon atoms to carbon.
  mutating func removeAnchorMarkers() {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let map = atomsToAtomsMap[atomID]
      if map.count == 1 {
        let otherID = Int(map[0])
        let otherAtom = topology.atoms[otherID]
        if otherAtom.atomicNumber == 14 {
          anchors.append(UInt32(atomID))
        }
      }
    }
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 14 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
}

// MARK: - Utility Functions

// Requires that the environment is already created.
// - Accepts atom positions in nm.
func createMolecule(
  env: xtb_TEnvironment,
  atoms: [Entity],
  charge: Float,
  uhf: Int
) -> xtb_TMolecule {
  var atomTypes: [Int32] = []
  var coordinates: [Double] = []
  for atom in atoms {
    atomTypes.append(Int32(atom.storage.w))
    coordinates.append(Double(atom.position.x))
    coordinates.append(Double(atom.position.y))
    coordinates.append(Double(atom.position.z))
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let mPerBohr: Double = 5.29177210903e-11
  let nmPerM: Double = 1e9
  let conversionFactor = 1 / (mPerBohr * nmPerM)
  coordinates = coordinates.map {
    $0 * conversionFactor
  }
  
  var _natoms = Int32(atoms.count)
  var _charge = Double(charge)
  var _uhf = Int32(uhf)
  let output = xtb_newMolecule(
    env, &_natoms, &atomTypes, &coordinates,
    &_charge, &_uhf, nil, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  guard let output else {
    fatalError("Failed to create molecule from atoms: \(atoms)")
  }
  return output
}

// Requires that the molecule is already created.
// - Accepts atom positions in nm.
func updateMolecule(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  atoms: [Entity]
) {
  var coordinates: [Double] = []
  for atom in atoms {
    coordinates.append(Double(atom.position.x))
    coordinates.append(Double(atom.position.y))
    coordinates.append(Double(atom.position.z))
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let mPerBohr: Double = 5.29177210903e-11
  let nmPerM: Double = 1e9
  let conversionFactor = 1 / (mPerBohr * nmPerM)
  coordinates = coordinates.map {
    $0 * conversionFactor
  }
  
  xtb_updateMolecule(env, mol, &coordinates, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
}

// Requires that the environment is already created.
func initializeEnvironment(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  calc: xtb_TCalculator,
  verbosityLevel: Int32 = XTB_VERBOSITY_MUTED
) {
  xtb_setVerbosity(env, verbosityLevel)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  xtb_loadGFN2xTB(env, mol, calc, nil)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
}

// Requires that GFN2-xTB is already loaded.
// - Outputs forces in pN.
func createForces(
  env: xtb_TEnvironment,
  mol: xtb_TMolecule,
  calc: xtb_TCalculator,
  res: xtb_TResults,
  atomCount: Int
) -> [SIMD3<Float>] {
  xtb_singlepoint(env, mol, calc, res)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  var gradient = [Double](repeating: 0, count: atomCount * 3)
  xtb_getGradient(env, res, &gradient)
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  // https://en.wikipedia.org/wiki/Atomic_units
  let NPerHaPerBohr: Double = 8.2387234983e-8
  let pNPerN: Double = 1e12
  let conversionFactor = NPerHaPerBohr * pNPerN
  
  var output: [SIMD3<Float>] = []
  for atomID in 0..<atomCount {
    let x = gradient[atomID * 3 + 0]
    let y = gradient[atomID * 3 + 1]
    let z = gradient[atomID * 3 + 2]
    var xyz = SIMD3<Double>(x, y, z)
    xyz *= conversionFactor
    
    // Force is the negative gradient.
    xyz = -xyz
    output.append(SIMD3<Float>(xyz))
  }
  return output
}

// Requires that the elements are recognized by the switch block.
func createMasses(atoms: [Entity]) -> [Float] {
  let conversionFactor: Double = MM4YgPerAmu
  
  var output: [Float] = []
  for atom in atoms {
    var mass: Float = .zero
    switch atom.atomicNumber {
    case 1: mass = 1.008
    case 6: mass = 12.011
    case 7: mass = 14.007
    case 8: mass = 15.999
    case 9: mass = 18.9984031636
    case 14: mass = 28.085
    case 15: mass = 30.9737619985
    case 16: mass = 32.06
    case 32: mass = 72.6308
    case 50: mass = 118.7100
    default:
      fatalError("Unrecognized atomic number: \(atom.atomicNumber)")
    }
    mass *= Float(conversionFactor)
    output.append(mass)
  }
  return output
}
