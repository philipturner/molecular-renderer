import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Film Storyboard
//
// Preparing Surface
// - H-passivated silicon wafer
// - molecular dynamics at 1200 C
// - hydrogens leave surface
// - molecular dynamics at 400 C
//   - set HMR to 1
//   - give ghost hydrogens the atomic mass of Cl
//   - set equilibrium bond length to Si-Cl length
// - form chlorinated Si(111) with chlorine gas
// - form partially hydrogenated, partially chlorinated Si(111) with atomic H
//   - 50% hydrogenation, randomly distributed
// - deposit tripods as vapor
//   - recycle leg design from HDL test suite
//   - energy-minimize the following variants in xTB
//     - C*
//     - C-Br
//     - Ge*
//     - Ge-CH**
//     - Ge-CHBr2
//     - Ge-CH2*
//     - Ge-CH2Br
//     - Sn*
//     - Sn-H
// - remove halogen caps with 254 nm light
//
// Mechanosynthesis
// - one AFM probe appears, with tip already sharpened
//   - silicon-(H3C)3-Si*
//   - use relaxed structure after energy minimization with MM4
// - probe scans the surface
// - select a site near center of surface, with three nearby Si-H groups
// - compile three times
//   - voltage pulse:               Si* + H-Si          surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            Si* + *CH2-Ge       tripod
//   - methylation:                 Si-CH2* + *Si       surface
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *H2C-Si      surface
// - 6-membered ring forms
//   - voltage pulse:               Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse:               Si* + H3C-Si        surface
//   - 5-membered ring forms:       Si-CH* + *HC-Si     surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            carbene feedstock   tripod
//   - carbene addition:            Si-CH** + HCCH      surface
// - adamantange cage forms
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *HC-(CH2)2   surface
//   - voltage pulse                Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse                Si* + H2C-(CH2)2    surface
//   - adamantane cage forms:       Si-CH* + *HC-(CH2)2 surface
//
// System Construction
// - move camera to an empty silicon surface
// - synthesize diamond lattice: AFM follows atoms in Morton order
// - compile abbreviated mechanosynthesis animation for every part
// - lift parts into exploded view
// - energy-minimize from compiled to relaxed structure
//   - show each frame of the minimization, if practical
// - assemble parts on top of each other
// - rotate so the flywheel points toward viewer
//
// System Operation
// - animate the flywheel-piston system moving
// - parallel 8-bit half adder, due to restriction to 3 unique clock phases
// - will include MD simulation at 298 K
// - [storyboard in progress]
//
// Credits
// - Author
// - Music
// - Inspiration (for mechanosynthesis and computing)

func createGeometry() -> [Entity] {
  // First task:
  // - Find Si-Cl, Cl-Cl bond length with xTB.
  // - Record Si-H, Si-Cl, Cl-Cl bond length in a source file.
  //
  // Second task:
  // - Compile and minimize the tripod tooltips.
  // - Serialize the tripods as Swift source code.
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 4 * h + 4 * k + 4 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Origin { 2 * h + 2 * k + 2 * l }
      Origin { 0.25 * (h + k - l) }
      
      // Remove the front plane.
      Convex {
        Origin { 0.25 * (h + k + l) }
        Plane { h + k + l }
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
      
      // Remove three sides forming a triangle.
      triangleCut(sign: +1)
      
      // Remove their opposites.
      triangleCut(sign: -1)
      
      // Remove the back plane.
      Convex {
        Origin { -0.25 * (h + k + l) }
        Plane { -(h + k + l) }
      }
      
      Replace { .empty }
    }
  }
  
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  
  // Form bonds between bulk atoms.
  do {
    let matches = topology.match(topology.atoms)
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  // Form bonds to chlorine atoms.
  do {
    let orbitals = topology.nonbondingOrbitals()
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let silicon = topology.atoms[atomID]
      for orbital in orbitals[atomID] {
        var siClBondLength: Float = .zero
        siClBondLength += Element.silicon.covalentRadius
        siClBondLength += Element.chlorine.covalentRadius
        let position = silicon.position + siClBondLength * orbital
        let chlorine = Entity(position: position, type: .atom(.chlorine))
        
        let chlorineID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(chlorineID))
        insertedAtoms.append(chlorine)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  var solver = XTBSolver(cpuID: 0)
  solver.atoms = topology.atoms
  solver.solve(arguments: ["--opt"])
  solver.load()
  
  return solver.atoms
}
