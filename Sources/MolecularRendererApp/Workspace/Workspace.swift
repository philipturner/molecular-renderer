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
// - molecular dynamics at 77 K?
// - remove halogen caps with 254 nm light
//
// Mechanosynthesis
// - one AFM probe appears, with tip already sharpened
//   - silicon-(H3C)3-Si*
//   - use relaxed structure after energy minimization with MM4
// - probe scans the surface
// - select a site near center of surface, with three nearby Si-H groups
// - compile three times:
//   - voltage pulse:               Si* + H-Si          surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            Si* + *CH2-Ge       tripod
//   - methylation:                 Si-CH2* + *Si       surface
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *H2C-Si      surface
// - 6-membered ring forms:
//   - voltage pulse:               Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse:               Si* + H3C-Si        surface
//   - 5-membered ring forms:       Si-CH* + *HC-Si     surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            Si* + **HC-Ge       tripod
//   - carbene addition:            Si-CH** + HCCH      surface
// - adamantange cage forms:
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *HC-(CH2)2   surface
//   - voltage pulse:               Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse:               Si* + H2C-(CH2)2    surface
//   - sila-adamantane cage forms:  Si-CH* + *HC-(CH2)2 surface
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
  // Current task:
  // - Compile and minimize the tripod tooltips.
  //   - Anchor every atom in the SiH3 groups.
  // - Serialize the tripods as Swift source code.
  return [Entity(position: .zero, type: .atom(.carbon))]
}
