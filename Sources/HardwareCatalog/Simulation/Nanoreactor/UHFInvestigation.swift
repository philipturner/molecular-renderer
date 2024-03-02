//
//  UHFInvestigation.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 3/2/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // MARK: - Scene Setup
  
  // Methylene
  // - startSeparation = 0.65
  // - endSeparation = 0.40
  // MethyleneGraphene
  // - startSeparation = 0.60
  // - endSeparation = 0.35
  // MethyleneSilicon
  // - startSeparation = 0.70
  // - endSeparation = 0.45
  // Silylene
  // - startSeparation = 0.75
  // - endSeparation = 0.50
  
  // Speed is in kilometers per second.
  let startSeparation: Float = 10.65
  let endSeparation: Float = 0.40
  let framesStationary: Int = 90
  let speed: Float = 2
  let simulating: Bool = false
  
  // Make the tooltip approach from above. Orient the molecules vertically
  // instead of horizontally.
  
  var descriptor = TooltipDescriptor()
  descriptor.feedstock = .methylene
  descriptor.bridgehead = .silicon
  descriptor.sidewall = .hydrogen
  
  var tooltip = Tooltip(descriptor: descriptor)
  for i in tooltip.topology.atoms.indices {
    var atom = tooltip.topology.atoms[i]
    atom.position = SIMD3(atom.position.x, -atom.position.z, atom.position.y)
    atom.position.y += startSeparation - 0.4
    tooltip.topology.atoms[i] = atom
  }
  
  descriptor.feedstock = .radical
  descriptor.bridgehead = .carbon
  descriptor.sidewall = .carbon
  
  var workpiece = Tooltip(descriptor: descriptor)
  for i in workpiece.topology.atoms.indices {
    var atom = workpiece.topology.atoms[i]
    atom.position = SIMD3(atom.position.x, atom.position.z, atom.position.y)
    atom.position.y += -0.4
    workpiece.topology.atoms[i] = atom
  }
  
  // MARK: - Simulation Setup
  
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  
  // This does not deallocate the xTB objects, leaving zombie objects.
  func createCharges(uhf: Int) -> [Float] {
    let initialAtoms = tooltip.topology.atoms + workpiece.topology.atoms
    let env = xtb_newEnvironment()!
    let calc = xtb_newCalculator()!
    let res = xtb_newResults()!
    let mol = createMolecule(
      env: env, atoms: initialAtoms, charge: 0, uhf: uhf)
    initializeEnvironment(env: env, mol: mol, calc: calc)
    updateMolecule(env: env, mol: mol, atoms: initialAtoms)
    
    xtb_singlepoint(env, mol, calc, res)
    guard xtb_checkEnvironment(env) == 0 else {
      fatalError("Call xtb_showEnvironment.")
    }
    
    var charges = [Double](repeating: .zero, count: initialAtoms.count)
    xtb_getCharges(env, res, &charges)
    return charges.map(Float.init)
  }
  
  let charges0 = createCharges(uhf: 0)
  let charges2 = createCharges(uhf: 2)
  let charges4 = createCharges(uhf: 4)
  
  let initialAtoms = tooltip.topology.atoms + workpiece.topology.atoms
  for i in initialAtoms.indices {
    let atom = initialAtoms[i]
    print(atom.atomicNumber, terminator: "")
    
    var chargeDeltas: [Float] = []
    chargeDeltas.append(charges2[i] - charges0[i])
    chargeDeltas.append(charges4[i] - charges0[i])
    for chargeDelta in chargeDeltas {
      print(" ", terminator: "")
      if chargeDelta < 0 {
        print("-", separator: "", terminator: "")
      } else {
        print("+", separator: "", terminator: "")
      }
      let repr = String(format: "%.3f", chargeDelta.magnitude)
      print(repr, terminator: "")
    }
    print()
  }
  
  if simulating {
    fatalError("Not implemented.")
  }
  
  return tooltip.topology.atoms + workpiece.topology.atoms
}

// Determine whether keeping spin multiplicity at 0, or changing to 2, affects
// the results. Do the molecules become charged in order to keep the same
// number of doubly occupied orbitals?
//
// Store this data in a file "UHF investigation".

/*
 0 14 SIMD3<Float>(0.0, 0.24999997, 0.0)
 1 1 SIMD3<Float>(0.0, 0.2994303, 0.13981965)
 2 1 SIMD3<Float>(-0.12108738, 0.2994303, -0.06990982)
 3 1 SIMD3<Float>(0.12108734, 0.2994303, -0.06990987)
 4 6 SIMD3<Float>(0.0, 0.064599976, 0.0)
 5 1 SIMD3<Float>(-0.09534939, 0.0095499605, 0.0)
 6 1 SIMD3<Float>(0.09534939, 0.0095499605, 8.335709e-09)
 7 6 SIMD3<Float>(0.0, -0.4, 0.0)
 8 6 SIMD3<Float>(0.0, -0.45089692, 0.14396803)
 9 1 SIMD3<Float>(0.0, -0.56209695, 0.14396803)
 10 6 SIMD3<Float>(-0.12467998, -0.45089692, -0.071984)
 11 1 SIMD3<Float>(-0.12467998, -0.56209695, -0.071984)
 12 6 SIMD3<Float>(0.124679945, -0.45089692, -0.07198406)
 13 1 SIMD3<Float>(0.124679945, -0.56209695, -0.07198406)
 14 1 SIMD3<Float>(0.09079442, -0.41382968, 0.19638781)
 15 1 SIMD3<Float>(-0.09079442, -0.41382968, 0.19638781)
 16 1 SIMD3<Float>(-0.21547404, -0.41382968, -0.019563612)
 17 1 SIMD3<Float>(-0.124679655, -0.41382968, -0.17682417)
 18 1 SIMD3<Float>(0.12467956, -0.41382968, -0.17682423)
 19 1 SIMD3<Float>(0.21547404, -0.41382968, -0.019563708)
 
 UHF  0-1  2-3 4
 0 14 +.00
 1  1 +.00
 2  1 +.00
 3  1 +.00
 4  6 +.00
 5  1 +.00
 6  1 +.00
 7  6 +.00
 8  6 +.00
 9  1 +.00
 10 6 +.00
 11 1 +.00
 12 6 +.00
 13 1 +.00
 14 1 +.00
 15 1 +.00
 16 1 +.00
 17 1 +.00
 18 1 +.00
 19 1 +.00
 
 14 +0.004 -0.229
 1 +0.008 +0.060
 1 +0.007 +0.102
 1 +0.007 +0.102
 6 +0.009 +0.042
 1 +0.009 -0.011
 1 +0.009 -0.011
 6 -0.014 -0.014
 6 +0.002 +0.003
 1 -0.006 -0.006
 6 +0.002 +0.004
 1 -0.006 -0.006
 6 +0.002 +0.004
 1 -0.006 -0.006
 1 -0.005 -0.005
 1 -0.005 -0.005
 1 -0.005 -0.005
 1 -0.005 -0.006
 1 -0.005 -0.006
 1 -0.005 -0.005
 
 14 +0.004 -0.230
 1 +0.008 +0.061
 1 +0.007 +0.103
 1 +0.007 +0.103
 6 +0.008 +0.040
 1 +0.008 -0.013
 1 +0.008 -0.013
 6 -0.012 -0.012
 6 +0.002 +0.002
 1 -0.006 -0.006
 6 +0.002 +0.002
 1 -0.006 -0.006
 6 +0.002 +0.002
 1 -0.006 -0.006
 1 -0.004 -0.004
 1 -0.004 -0.004
 1 -0.004 -0.005
 1 -0.004 -0.005
 1 -0.004 -0.005
 1 -0.004 -0.005
 
 14 +0.003 -0.231
 1 +0.008 +0.061
 1 +0.007 +0.103
 1 +0.007 +0.103
 6 +0.008 +0.039
 1 +0.007 -0.014
 1 +0.007 -0.014
 6 -0.011 -0.011
 6 +0.002 +0.002
 1 -0.006 -0.006
 6 +0.002 +0.002
 1 -0.006 -0.006
 6 +0.002 +0.002
 1 -0.006 -0.006
 1 -0.004 -0.004
 1 -0.004 -0.004
 1 -0.004 -0.004
 1 -0.004 -0.004
 1 -0.004 -0.004
 1 -0.004 -0.004
 
 */

/*
 UHF=0
 
 :: total energy             -19.387987566711 Eh    ::
 :: gradient norm              0.090538065208 Eh/a0 ::
 :: HOMO-LUMO gap              0.005549872590 eV    ::
 
 [0.4146175644186763, -0.10860930828992775, -0.12144197861711693, -0.1214419379524618, -0.18494548336536326, 0.03406371193862707, 0.03406370868609129, -0.024681617599840555, -0.10082701457767625, 0.04897436663473399, -0.10079023812063545, 0.0489456685085108, -0.10079021978105068, 0.048945676882609736, 0.039023516128477424, 0.03902352638862199, 0.03873395728231667, 0.039201071821478084, 0.03920109176555564, 0.03873393784839573]
 */

/*
 UHF=1
 
 :: total energy             -19.387987566711 Eh    ::
 :: gradient norm              0.090538065208 Eh/a0 ::
 :: HOMO-LUMO gap              0.005549872590 eV    ::
 
 [0.4146175644186763, -0.10860930828992775, -0.12144197861711693, -0.1214419379524618, -0.18494548336536326, 0.03406371193862707, 0.03406370868609129, -0.024681617599840555, -0.10082701457767625, 0.04897436663473399, -0.10079023812063545, 0.0489456685085108, -0.10079021978105068, 0.048945676882609736, 0.039023516128477424, 0.03902352638862199, 0.03873395728231667, 0.039201071821478084, 0.03920109176555564, 0.03873393784839573]
 */

/*
 UHF=2
 
 :: total energy             -19.384775425018 Eh    ::
 :: gradient norm              0.086063225595 Eh/a0 ::
 :: HOMO-LUMO gap              4.061359128637 eV    ::
 
 [0.41829308367693074, -0.10071009710653352, -0.11448934177048167, -0.1144893015801973, -0.1755530209000488, 0.043474492532022825, 0.04347448935578582, -0.03841433197803193, -0.09835685876766599, 0.04305438503156926, -0.09832134945682691, 0.043027126968540254, -0.0983213310949877, 0.04302713492672467, 0.03408720839080098, 0.03408721881970516, 0.03379811544075375, 0.03426713125474729, 0.034267151350582656, 0.03379809490660585]
 */

/*
 UHF=3
 
 :: total energy             -19.384775425018 Eh    ::
 :: gradient norm              0.086063225595 Eh/a0 ::
 :: HOMO-LUMO gap              4.061359128637 eV    ::
 
 [0.4182930836769118, -0.10071009710652795, -0.11448934177047643, -0.1144893015801919, -0.17555302090004582, 0.04347449253202189, 0.0434744893557833, -0.03841433197803351, -0.09835685876766509, 0.043054385031566896, -0.0983213494568267, 0.043027126968539435, -0.09832133109498895, 0.04302713492672384, 0.034087208390802246, 0.034087218819704806, 0.033798115440755706, 0.03426713125474794, 0.0342671513505848, 0.033798094906608504]
 */

/*
 UHF=4
 
 :: total energy             -19.132617188096 Eh    ::
 :: gradient norm              0.125519760859 Eh/a0 ::
 :: HOMO-LUMO gap              0.541588162723 eV    ::
 
 [0.18514746520795466, -0.04850424592520525, -0.01993826191394901, -0.01993834961914293, -0.14295843200088587, 0.02309661214681296, 0.023096579519104175, -0.03866491928974328, -0.09739698264217334, 0.04285061752583108, -0.0972510362254356, 0.042799321466752284, -0.09725101854367456, 0.04279932956040325, 0.03388684001651249, 0.033886849605638245, 0.03350431857045585, 0.03366549616050314, 0.03366551685602689, 0.03350429946025993]
 */

// MARK: - Structures

enum Feedstock {
  case radical
  case methylene
  case silylene
}

struct TooltipDescriptor {
  var feedstock: Feedstock?
  var bridgehead: Element?
  var sidewall: Element?
}

// A tooltip pointing toward the Z direction.
struct Tooltip {
  var topology = Topology()
  var anchors: [UInt32] = []
  var tipAtomID: UInt32 = .max
  
  init(descriptor: TooltipDescriptor) {
    guard descriptor.feedstock != nil,
          descriptor.bridgehead != nil,
          descriptor.sidewall != nil else {
      fatalError("Descriptor not complete.")
    }
    
    createBaseAtoms(descriptor: descriptor)
    createSidewallHydrogens()
    createFeedstock(descriptor: descriptor)
  }
  
  mutating func createBaseAtoms(descriptor: TooltipDescriptor) {
    let tipAtom = Entity(position: .zero, type: .atom(descriptor.bridgehead!))
    topology.insert(atoms: [tipAtom])
    tipAtomID = 0
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for sidewallID in 0..<3 {
      let angle = Float(sidewallID) * (2 * .pi) / 3
      let rotation1 = Quaternion<Float>(
        angle: 109.47 * .pi / 180, axis: [-1, 0, 0])
      let rotation2 = Quaternion<Float>(
        angle: angle, axis: [0, 0, 1])
      
      var orbital: SIMD3<Float> = [0, 0, 1]
      orbital = rotation1.act(on: orbital)
      orbital = rotation2.act(on: orbital)
      
      var hydrogen: Entity
      switch descriptor.sidewall! {
      case .hydrogen:
        let xhBondLength = Tooltip.hydrogenBondLength(
          element: descriptor.bridgehead!)
        let position = tipAtom.position + xhBondLength * orbital
        hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let bond = SIMD2(UInt32(0), UInt32(topology.atoms.count - 1))
        insertedBonds.append(bond)
      case .carbon, .silicon:
        var position1: SIMD3<Float>
        if descriptor.sidewall! == .carbon {
          let xcBondLength = Tooltip.carbonBondLength(
            element: descriptor.bridgehead!)
          position1 = tipAtom.position + xcBondLength * orbital
          let carbon = Entity(position: position1, type: .atom(.carbon))
          topology.insert(atoms: [carbon])
        } else {
          let xSiBondLength = Tooltip.siliconBondLength(
            element: descriptor.bridgehead!)
          position1 = tipAtom.position + xSiBondLength * orbital
          let silicon = Entity(position: position1, type: .atom(.silicon))
          topology.insert(atoms: [silicon])
        }
        
        let chBondLength = Tooltip.hydrogenBondLength(element: .carbon)
        let position2 = position1 + chBondLength * SIMD3<Float>(0, 0, -1)
        hydrogen = Entity(position: position2, type: .atom(.hydrogen))
        
        let bond1 = SIMD2(UInt32(0), UInt32(topology.atoms.count - 1))
        let bond2 = SIMD2(bond1[1], UInt32(topology.atoms.count))
        insertedBonds.append(bond1)
        insertedBonds.append(bond2)
      default:
        fatalError("Unsupported sidewall element.")
      }
      
      let hydrogenID = UInt32(topology.atoms.count)
      anchors.append(hydrogenID)
      topology.insert(atoms: [hydrogen])
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createSidewallHydrogens() {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      guard orbitals[atomID].count == 2 else {
        continue
      }
      let atom = topology.atoms[atomID]
      let element = Element(atom.atomicNumber)
      
      for orbital in orbitals[atomID] {
        let xhBondLength = Tooltip.hydrogenBondLength(element: element)
        let position = atom.position + xhBondLength * orbital
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
  
  mutating func createFeedstock(descriptor: TooltipDescriptor) {
    let feedstock = descriptor.feedstock!
    if feedstock == .radical {
      return
    }
    
    var feedstockElement: Element
    var feedstockHBondLength: Float
    var feedstockTipBondLength: Float
    if feedstock == .methylene {
      feedstockElement = .carbon
      feedstockHBondLength = 1.1010 / 10
      feedstockTipBondLength = Self.methyleneBondLength(
        element: descriptor.bridgehead!)
    } else {
      feedstockElement = .silicon
      feedstockHBondLength = Self.hydrogenBondLength(element: .silicon)
      feedstockTipBondLength = Self.siliconBondLength(
        element: descriptor.bridgehead!)
    }
    
    // Add the carbon or silicon atom.
    var centerAtomPosition: SIMD3<Float>
    var centerAtomID: Int
    do {
      let orbital: SIMD3<Float> = [0, 0, 1]
      let position = SIMD3<Float>.zero + feedstockTipBondLength * orbital
      let atom = Entity(position: position, type: .atom(feedstockElement))
      let bond = SIMD2(UInt32(0), UInt32(topology.atoms.count))
      centerAtomPosition = position
      centerAtomID = topology.atoms.count
      topology.insert(atoms: [atom])
      topology.insert(bonds: [bond])
    }
    
    var angle1: Float
    var angle2: Float
    if feedstock == .methylene {
      angle1 = 120
      angle2 = 180
    } else {
      angle1 = 109.47
      angle2 = 120
    }
    angle1 *= .pi / 180
    angle2 *= .pi / 180
    
    let rotation1 = Quaternion<Float>(angle: angle1, axis: [0, 1, 0])
    let orbital1 = rotation1.act(on: [0, 0, -1])
    let position1 = centerAtomPosition + feedstockHBondLength * orbital1
    
    let rotation2 = Quaternion<Float>(angle: angle2, axis: [0, 0, 1])
    let orbital2 = rotation2.act(on: orbital1)
    let position2 = centerAtomPosition + feedstockHBondLength * orbital2
    
    for position in [position1, position2] {
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count
      let bond = SIMD2(UInt32(centerAtomID), UInt32(hydrogenID))
      topology.insert(atoms: [hydrogen])
      topology.insert(bonds: [bond])
    }
  }
}

extension Tooltip {
  // The bond length between an sp3 element and hydrogen.
  // - This is not correct for methylene.
  // - This is correct for silylene.
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
  
  // The bond length between an sp3 element and sp2 carbon.
  static func methyleneBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.4990 / 10
    case .silicon:
      return 1.8540 / 10
    case .germanium:
      return 1.9350 / 10
    case .tin:
      let snGeDifference: Float = 2.1470 - 1.9490
      return (1.9350 + snGeDifference) / 10
    default:
      fatalError("Unexpected element for X-CH2* bond.")
    }
  }
  
  // The bond length between an sp3 element and sp3 carbon.
  static func carbonBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.5270 / 10
    case .silicon:
      return 1.876 / 10
    case .germanium:
      return 1.949 / 10
    case .tin:
      return 2.1470 / 10
    default:
      fatalError("Unexpected element for X-CH3 bond.")
    }
  }
  
  // The bond length between an sp3 element and sp3 silicon.
  // - Use this for silylene as well.
  static func siliconBondLength(element: Element) -> Float {
    switch element {
    case .carbon:
      return 1.876 / 10
    case .silicon:
      return 2.322 / 10
    case .germanium:
      // Source:
      // https://www.degruyter.com/document/doi/10.1515/MGMC.1999.22.6.385/pdf
      return 2.372 / 10
    case .tin:
      // Source:
      // https://www.degruyter.com/document/doi/10.1515/MGMC.1999.22.6.385/pdf
      return 2.610 / 10
    default:
      fatalError("Unexpected element for X-SiH3 bond.")
    }
  }
}

// A graphene flake whose normal is the Z direction.
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
