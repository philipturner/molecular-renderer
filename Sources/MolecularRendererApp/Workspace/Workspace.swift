import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Can the carbene group successfully transfer from the tinCarbene tripod
// to the germaniumRadical tripod? From the tin tripod to the AFM probe with a
// germanium tip? What about leaving it partially activated (with a different
// halogen that will be activated at a different wavelength)? Then, covering
// the tripods with a thin shield to protect them from the UV light.

// TODO: You can just mount the Ge tripod on the AFM probe, instead of building
// a sharped silicon lattice. That makes it much more viable within the limited
// amount of time to present the project.

func createGeometry() -> [Entity] {
  // Use the hydrogen transfer between Sn and Ge as a simpler test case, for
  // troubleshooting the other components of the simulation.
  let tinTripod = TripodCache.tinSet.hydrogen
  let germaniumTripod = TripodCache.germaniumSet.radical
  
  let tinTip = Tooltip(tripod: tinTripod)
  let tinLegs = Array(tinTripod[22..<70])
  let germaniumTip = Tooltip(tripod: germaniumTripod)
  let germaniumLegs = Array(germaniumTripod[22..<70])
  
  // Store the tripods in their own reference frame. "project" the tripods to
  // render and/or query forces from the simulator. Then, invert the Y
  // component of the force for the germanium tip.
  
  var output: [Entity] = []
  output += tinTip.topology.atoms
  output += tinLegs
  output += germaniumTip.topology.atoms.map {
    var copy = $0
    copy.position.y = -copy.position.y
    copy.position.y += 2.00
    return copy
  }
  output += germaniumLegs.map {
    var copy = $0
    copy.position.y = -copy.position.y
    copy.position.y += 2.00
    return copy
  }
  return output
}

// A tooltip with an adamantane cage, formed by stripping a tripod of its legs.
//
// The legs can be extracted from the pre-compiled tripod separately. That way,
// both the cage and legs can be rendered. It will be possible to formalize
// inter-tripod distances as the distances between the approaching silicon
// surfaces that attach at the legs.
struct Tooltip {
  var topology = Topology()
  
  // The carbon atoms attached to legs must have their position fixed. In
  // addition, the ghost hydrogens must be held fixed throughout simulations.
  var anchorIDs: [UInt32] = []
  
  // Ghost hydrogens are generated in a location that doesn't perfectly line
  // up with where the leg once was.
  var hydrogenIDs: [UInt32] = []
  
  // The feedstock atoms, which you might want to treat differently in the
  // dynamic simulation. For example, assuming the reaction worked, you would
  // treat them as part of a different object.
  var feedstockIDs: [UInt32] = []
  
  init(tripod: [Entity]) {
    var tripodAtoms = tripod
    tripodAtoms.removeSubrange(22..<70)
    topology.insert(atoms: tripodAtoms)
    
    // Fetch the feedstock atom IDs before adding the ghost hydrogens.
    for atomID in 22..<topology.atoms.count {
      feedstockIDs.append(UInt32(atomID))
    }
    
    createBonds()
    createGhostLegs()
  }
  
  // Forms a (potentially incorrect) bonding topology for the entire structure,
  // but the important part (leg attachment point) will always be correct.
  mutating func createBonds() {
    // 1.2 covalent bond lengths produces a completely correct topology for:
    // - 'TripodCache.germaniumSet.radical'
    // - 'TripodCache.tinSet.hydrogen'
    var matches = topology.match(
      topology.atoms, algorithm: .covalentBondLength(1.2))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  // Detects the carbons that were attached to the legs, and sets them as
  // anchors.
  mutating func createGhostLegs() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAnchorIDs: [UInt32] = []
    var insertedHydrogenIDs: [UInt32] = []
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let orbitalSet = orbitals[atomID]
      guard orbitalSet.count > 0 else {
        continue
      }
      guard atom.atomicNumber == 6, atom.position.y < 0.4600 else {
        continue
      }
      
      guard orbitalSet.count == 1 else {
        fatalError("Orbital set had unexpected size.")
      }
      let orbital = orbitalSet.first!
      
      // Source: MM4Parameters
      let chBondLength: Float = 1.112 / 10
      let hydrogenPosition = atom.position + orbital * chBondLength
      let hydrogen = Entity(position: hydrogenPosition, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      
      insertedAnchorIDs.append(UInt32(atomID))
      insertedAnchorIDs.append(UInt32(hydrogenID))
      insertedHydrogenIDs.append(UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(SIMD2(UInt32(atomID), UInt32(hydrogenID)))
    }
    anchorIDs = insertedAnchorIDs
    hydrogenIDs = insertedHydrogenIDs
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
}

// MARK: - xTB Simulation Utilities

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
