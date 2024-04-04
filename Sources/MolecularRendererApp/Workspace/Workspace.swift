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
  //   - Include the SiH3 group on each leg in the simulation.
  //   - Anchor every atom in the SiH3 groups.
  // - Serialize the tripods as Swift source code.
  
  var tripod = CBNTripod()
  tripod.rotateLegs(slantAngleDegrees: 62, swingAngleDegrees: 5)
  
  #if true
  for legID in tripod.legs.indices {
    var topology = tripod.legs[legID].topology
    
    // NOTE: Ensure the Si-H bonds are oriented the same way as in the bulk.
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 14 else {
        continue
      }
      
      // Two possibilities for energy minimum:
      // - triangle length = 0.768 nm
      // - triangle length = 1.016 nm
      var silicon = atom
      print(silicon.position)
      
      var siliconXZVector = SIMD2(silicon.position.x, silicon.position.z)
      siliconXZVector /= (siliconXZVector * siliconXZVector).sum().squareRoot()
      siliconXZVector *= 1.016 / Float(3).squareRoot()
      silicon.position.x = siliconXZVector[0]
      silicon.position.z = siliconXZVector[1]
      topology.atoms[atomID] = silicon
      print(silicon.position)
      
      var baseOrbital: SIMD3<Float> = .init(0, 1, 0)
      let baseAngle: Float = 109.5 * .pi / 180
      let baseRotation = Quaternion(angle: baseAngle, axis: [0, 0, 1])
      baseOrbital = baseRotation.act(on: baseOrbital)
      
      for orbitalID in 0..<3 {
        let angle = Float(orbitalID) * .pi * 2 / 3
        let orbitalRotation = Quaternion(angle: angle, axis: [0, 1, 0])
        let orbital = orbitalRotation.act(on: baseOrbital)
        
        // Source: MM4 parameters
        let chBondLength: Float = 1.483 / 10
        let position = silicon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    tripod.legs[legID].topology = topology
  }
  #endif
//  tripod.passivateNHGroups(.hydrogen)
  
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 10 * h2k + 3 * l }
    Material { .elemental(.silicon) }
  }
  var latticeAtoms = lattice.atoms
  for atomID in latticeAtoms.indices {
    var atom = latticeAtoms[atomID]
    var position = atom.position
    position = SIMD3(position.x, position.z, position.y)
    
    atom.position = position
    latticeAtoms[atomID] = atom
  }
  
  var tripodAtoms = tripod.createAtoms()
  for atomID in tripodAtoms.indices {
    var atom = tripodAtoms[atomID]
    var position = atom.position
    
    let angle: Float = 0 * .pi / 180
    let rotation = Quaternion(angle: angle, axis: [0, 1, 0])
    position = rotation.act(on: position)
    
    let latticeConstant1 = Constant(.hexagon) { .elemental(.silicon) }
    let latticeConstant2 = Constant(.prism) { .elemental(.silicon) }
    position.y += 0.69417167
    position.z += latticeConstant1 / Float(3).squareRoot()
    print(Constant(.prism) { .elemental(.silicon) })
    
    position.x += latticeConstant1 * 3
    position.y += latticeConstant2 * 2.625
    position.z += latticeConstant1 * 3 * Float(3).squareRoot()
    
    atom.position = position
    tripodAtoms[atomID] = atom
  }
  
  var output: [Entity] = []
  output += latticeAtoms
  output += tripodAtoms
  return output
}
