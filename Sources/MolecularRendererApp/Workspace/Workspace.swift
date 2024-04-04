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
// - Inspiration (for mechanosynthesis and rod logic)

func createGeometry() -> [Entity] {
  // Second task:
  // - Compile and minimize the tripod tooltips.
  //   - Anchor every atom in the SiH3 groups.
  //   - Get the xtb command-line binary running with Accelerate.
  // - Serialize the tripods as Swift source code.
  
  var surface = Surface()
  var tripod = Tripod()
  
  var germanium: Entity?
  for atom in tripod.topology.atoms {
    if atom.atomicNumber == 32 {
      germanium = atom
    }
  }
  guard let germanium else {
    fatalError("Could not find germanium.")
  }
  
  // Add the feedstock to the tripod (hasty solution).
  do {
    var position = germanium.position
    position.y += Element.germanium.covalentRadius
    position.y += Element.carbon.covalentRadius
    let carbon = Entity(position: position, type: .atom(.carbon))
    let carbonID = tripod.topology.atoms.count
    
    var insertedAtoms = [carbon]
    var insertedBonds: [SIMD2<UInt32>] = []
    for passivatorID in 0..<3 {
      var element: Element
      if passivatorID == 0 {
        element = .hydrogen
      } else {
        element = .bromine
      }
      
      let baseAngle: Float = 109.47 * .pi / 180
      let baseRotation = Quaternion(angle: baseAngle, axis: [0, 0, 1])
      let secondAngle = Float(passivatorID) * .pi * 2 / 3
      let secondRotation = Quaternion(angle: secondAngle, axis: [0, 1, 0])
      
      var orbital: SIMD3<Float> = .init(0, -1, 0)
      orbital = baseRotation.act(on: orbital)
      orbital = secondRotation.act(on: orbital)
      
      var bondLength: Float = .zero
      bondLength += Element.carbon.covalentRadius
      bondLength += element.covalentRadius
      let position = carbon.position + bondLength * orbital
      let passivator = Entity(position: position, type: .atom(element))
      
      let passivatorID = tripod.topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(carbonID), UInt32(passivatorID))
      insertedAtoms.append(passivator)
      insertedBonds.append(bond)
    }
    tripod.topology.insert(atoms: insertedAtoms)
    tripod.topology.insert(bonds: insertedBonds)
  }
  
  // Passivate the surface (hasty solution).
  do {
    var squashedTopology = tripod.topology
    for atomID in squashedTopology.atoms.indices {
      squashedTopology.atoms[atomID].position.y = .zero
    }
    
    // Return value has same dimensions as function argument.
    let closeMatches = tripod.topology.match(
      surface.topology.atoms, algorithm: .absoluteRadius(0.010))
    let farMatches = squashedTopology.match(
      surface.topology.atoms, algorithm: .absoluteRadius(0.200))
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in surface.topology.atoms.indices {
      let silicon = surface.topology.atoms[atomID]
      if silicon.position.y < -0.010 {
        continue
      }
      
      // Exclude the silicon where the nitrogen attaches.
      if closeMatches[atomID].count > 0 {
        continue
      }
      
      // Make the passivators under the tripod all be hydrogen.
      var element: Element
      if farMatches[atomID].count > 0 {
        element = .hydrogen
      } else {
        if Bool.random() {
          element = .hydrogen
        } else {
          element = .chlorine
        }
      }
      
      var bondLength: Float
      if element == .hydrogen {
        bondLength = 1.483 / 10
      } else {
        bondLength = 2.029 / 10
      }
      let orbital: SIMD3<Float> = [0, 1, 0]
      let position = silicon.position + bondLength * orbital
      let passivator = Entity(position: position, type: .atom(element))
      
      let passivatorID = surface.topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(atomID), UInt32(passivatorID))
      insertedAtoms.append(passivator)
      insertedBonds.append(bond)
    }
    surface.topology.insert(atoms: insertedAtoms)
    surface.topology.insert(bonds: insertedBonds)
  }
  
  // Set the silyl group as anchors (hasty solution).
  var anchors: [Int] = []
  for atomID in tripod.topology.atoms.indices {
    let atom = tripod.topology.atoms[atomID]
    if atom.atomicNumber == 14 || atom.position.y < 0 {
      anchors.append(atomID)
    }
  }
  
  var solver = XTBSolver(cpuID: 0)
  solver.atoms = tripod.topology.atoms
  solver.process.anchors = anchors
  solver.solve(arguments: ["--opt"])
  solver.load()
  tripod.topology.atoms = solver.atoms
  
  var output: [Entity] = []
  output += tripod.topology.atoms
  output += surface.topology.atoms
  return output
}
