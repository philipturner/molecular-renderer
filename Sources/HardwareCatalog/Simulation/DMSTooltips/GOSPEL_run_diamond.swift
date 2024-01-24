//
//  GOSPEL_run_diamond.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/22/24.
//

import Foundation
import HDL
import MM4
import Numerics
import PythonKit

func testGOSPEL() {
  let np = Python.import("numpy")
  let GOSPEL = Python.import("gospel").GOSPEL
  let bulk = Python.import("ase.build").bulk
  print(np)
  print(GOSPEL)
  print(bulk)
  
  let upf_files =
  ["/Users/philipturner/Documents/OpenMM/GOSPEL/tests/DATA/C.pbe-n-nc.UPF"]
  
  let atoms = bulk("C", "diamond", a: 3.57, cubic: true)
  let calc = GOSPEL(
    centered: true,
    use_cuda: false,
    use_dense_kinetic: true,
    grid: ["spacing": 0.15],
    pp: ["upf": PythonObject(upf_files), "filtering": PythonObject(true)],
    print_energies: true,
    xc: ["type": "gga_x_pbe + gga_c_pbe"],
    occupation: [
      "smearing": PythonObject("Fermi-Dirac"),
      "temperature": PythonObject(0.01)]
  )
  
  atoms.calc = calc
  let forces = atoms.get_forces()
  print("forces = \(forces)")
  
  /*
   ============================ [ Density ] ===========================
   * nelec         : 32.0
   * nspins        : 1
   * magmom        : 0.0
   * fix_magmom    : True
   * density guess : rhoatom
   * orbital guess : None
   * occ guess     : None
   =====================================================================
   
   ============ Energy (Hartree) ==============
   |   Total Energy        : -45.0027902743   |
   --------------------------------------------
   | * Ion-ion Energy      : 0.0              |
   | * Eigenvals sum for 0 : -4.4135508105    |
   | * Hartree Energy      : 1.7740259607     |
   | * XC Energy           : -14.3867501359   |
   | * Kinetic Energy      : 35.9475381665    |
   | * External Energy     : -52.3220828409   |
   | * Non-local Energy    : -16.0155214246   |
   ============================================
   Elapsed time[calc_and_print_energies]: 0.09417176246643066 sec
   Total Energy: -45.00279027425339 Ha
   Fermi Level : 6.260905530989438 eV
   Gap: 4.728 eV
   Transition (v -> c):
   
   * TOTAL TIME : 3.4246201515197754 sec
   forces = [[ 0.00025756 -0.00030462 -0.00029292]
    [ 0.00058263  0.00041014  0.00071209]
    [-0.00028288  0.0006408   0.00069998]
    [ 0.00033036  0.00142718  0.00151196]
    [ 0.00041961 -0.00019306  0.00086308]
    [ 0.00114906  0.00078813  0.00078647]
    [ 0.00017718  0.00057838 -0.00038744]
    [ 0.0011576   0.0010464   0.00043977]]
   */
}
