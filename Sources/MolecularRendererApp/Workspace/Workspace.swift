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
// End Product
// - compile an atomically exact sequence to build an entire ~1000 atom logic
//   rod, assuming hexagonal Si has the same lattice constant as hexagonal C
// - show the housing and other rods, but without investing the time into a
//   mechanosynthetic build sequence for them
// - show the half adder working, with a truth table
//
// Credits
// - Author
// - Music
// - Inspiration (Systems and Methods for Mechanosynthesis)
//
// TODO: Move the above notes and relevant code into "silicon-experiment".
// TODO: Finish fixing up the flywheel before moving on to that project.

// Separate media (not part of this video)
// - Get the flywheel working with MD, publish short animation
// - Don't have to get working method to link up to logic; just explain how
//   that would work
// - Don't have to finish patterning all the logic rods in the CLA; the
//   existing progress is enough
//
// Flywheel System Animation
// - lift parts into exploded view
// - energy-minimize from compiled to relaxed structure
//   - show each frame of the minimization, if practical
// - assemble parts on top of each other
// - rotate so the flywheel points toward viewer

func createGeometry() -> [Entity] {
  return [Entity(position: .zero, type: .atom(.carbon))]
}
