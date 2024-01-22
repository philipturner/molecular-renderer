//
//  GOSPEL_run_silicon.swift
//  MolecularRenderer
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
  let Atoms = Python.import("ase").Atoms
  let GOSPEL = Python.import("gospel.calculator").GOSPEL
  let bulk = Python.import("ase.build").bulk
  let torch = Python.import("torch")
  print(np)
  print(Atoms)
  print(GOSPEL)
  print(bulk)
  print(torch)
  
  torch.manual_seed(1)
  let upf_files =
  ["/Users/philipturner/Documents/OpenMM/GOSPEL/tests/DATA/Si.pbe-n-nc.UPF"]
  var atoms = bulk("Si", "diamond", a: 5.43, cubic: true)
  
  // ################ Supercell ###################
  let make_supercell = Python.import("ase.build").make_supercell
  let prim = np.diag([1, 1, 1])
  atoms = make_supercell(atoms, prim)
  print(atoms)
  // ##############################################
  
  // ##############################################
  let spacing = PythonObject(Double(0.2))
  let num_gapp_precond = PythonObject(Int(10))
  let num_inverse_precond = PythonObject(Int(0))
  let max_iter = num_inverse_precond + num_gapp_precond
  let precond_type = PythonObject("gapp")
  // ##############################################
  
  let solver_type = ["parallel_davidson", "lobpcg", "davidson"][2]
  var eigensolver: [PythonObject: PythonObject] = [:]
  
  if solver_type == "parallel_davidson" {
    eigensolver = [
      "type": "parallel_davidson",
      "maxiter": max_iter,
      "locking": false,
      "fill_block": false,
      "verbosity": 1,
    ]
  } else if solver_type == "lobpcg" {
    eigensolver = [
      "type": "lobpcg",
      "maxiter": max_iter,
    ]
  } else if solver_type == "davidson" {
    eigensolver = [
      "type": "davidson",
      "maxiter": max_iter,
      "locking": false,
      "fill_block": false,
    ]
  }
  
  let calc = GOSPEL(
    use_cuda: false,
    use_dense_kinetic: true,
    precond_type: precond_type,
    eigensolver: eigensolver,
    grid: ["spacing": spacing],
    pp: ["upf": upf_files],
    print_energies: true,
    xc: ["type": "gga_x_pbe + gga_c_pbe"],
    convergence: ["density_tol": 1e-5, "orbital_energy_tol": 1e-5],
    occupation: [
      "smearing": PythonObject("Fermi-Dirac"),
      "temperature": PythonObject(0.01)]
  )
  
  atoms.calc = calc
  _ = atoms.get_potential_energy()
  
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
   */
  
  /*
   let solver_type = ["parallel_davidson", "lobpcg", "davidson"][0]
   
   ============ Energy (Hartree) ==============
   |   Total Energy        : -38.3610988659   |
   --------------------------------------------
   | * Ion-ion Energy      : 0.0              |
   | * Eigenvals sum for 0 : -0.9352001888    |
   | * Hartree Energy      : 13.7099738514    |
   | * XC Energy           : -17.5386697336   |
   | * Kinetic Energy      : 13.0624449494    |
   | * External Energy     : -54.4941466788   |
   | * Non-local Energy    : 6.8992987456     |
   ============================================
   Elapsed time[calc_and_print_energies]: 0.028607845306396484 sec
   Total Energy: -38.36109886590981 Ha
   Fermi Level : 4.224461371458071 eV
   Gap: 0.617 eV
   Transition (v -> c):
     (s=0, k=0, n=15, [0.00, 0.00, 0.00]) -> (s=0, k=0, n=16, [0.00, 0.00, 0.00])

   * TOTAL TIME : 6.115700006484985 sec
   */
  
  /*
   let solver_type = ["parallel_davidson", "lobpcg", "davidson"][1]
   
   ============ Energy (Hartree) ==============
   |   Total Energy        : -38.3610652924   |
   --------------------------------------------
   | * Ion-ion Energy      : 0.0              |
   | * Eigenvals sum for 0 : -0.9351925233    |
   | * Hartree Energy      : 13.7099731908    |
   | * XC Energy           : -17.5386678233   |
   | * Kinetic Energy      : 13.0625004161    |
   | * External Energy     : -54.4941494907   |
   | * Non-local Energy    : 6.8992784147     |
   ============================================
   Elapsed time[calc_and_print_energies]: 0.026829004287719727 sec
   Total Energy: -38.361065292386975 Ha
   Fermi Level : 4.224305342270574 eV
   Gap: 0.617 eV
   Transition (v -> c):
     (s=0, k=0, n=15, [0.00, 0.00, 0.00]) -> (s=0, k=0, n=16, [0.00, 0.00, 0.00])

   * TOTAL TIME : 2.420485019683838 sec
   */
  
  /*
   let solver_type = ["parallel_davidson", "lobpcg", "davidson"][2]
   
   ============ Energy (Hartree) ==============
   |   Total Energy        : -38.3610988659   |
   --------------------------------------------
   | * Ion-ion Energy      : 0.0              |
   | * Eigenvals sum for 0 : -0.9352001888    |
   | * Hartree Energy      : 13.7099738514    |
   | * XC Energy           : -17.5386697336   |
   | * Kinetic Energy      : 13.0624449494    |
   | * External Energy     : -54.4941466788   |
   | * Non-local Energy    : 6.8992987456     |
   ============================================
   Elapsed time[calc_and_print_energies]: 0.0295259952545166 sec
   Total Energy: -38.36109886590981 Ha
   Fermi Level : 4.224461371458071 eV
   Gap: 0.617 eV
   Transition (v -> c):
     (s=0, k=0, n=15, [0.00, 0.00, 0.00]) -> (s=0, k=0, n=16, [0.00, 0.00, 0.00])

   * TOTAL TIME : 5.5521240234375 sec
   */
}

