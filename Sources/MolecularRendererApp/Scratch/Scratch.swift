// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import xtb

func createGeometry() -> [Entity] {
  var energy: Double = 0
  var nAtoms: Int32 = 8
  var attyp: [Int32] = [6, 6, 6, 1, 1, 1, 1]
  var charge: Double = 0
  var uhf: Int = 0
  var coord: [Double] = [
    0.00000000000000, 0.00000000000000,-1.79755622305860,
    0.00000000000000, 0.00000000000000, 0.95338756106749,
    0.00000000000000, 0.00000000000000, 3.22281255790261,
    -0.96412815539807,-1.66991895015711,-2.53624948351102,
    -0.96412815539807, 1.66991895015711,-2.53624948351102,
    1.92825631079613, 0.00000000000000,-2.53624948351102,
    0.00000000000000, 0.00000000000000, 5.23010455462158
  ]
  
  /*
     * All objects except for the molecular structure can be
     * constructued without other objects present.
     *
     * The construction of the molecular structure locks the
     * number of atoms, atomic number, total charge, multiplicity
     * and boundary conditions.
    **/
  var env: xtb_TEnvironment = xtb_newEnvironment()
  exit(0)
}
