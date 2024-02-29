//
//  XTBTutorial.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/29/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  var energy: Double = 0
  var natoms: Int32 = 7
  var attyp: [Int32] = [6, 6, 6, 1, 1, 1, 1]
  var charge: Double = 0
  var uhf: Int32 = 0
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
  
  XTBLibrary.loadLibrary(
    path: "/opt/homebrew/Cellar/xtb/6.6.1/lib/libxtb.6.dylib")
  print(xtb_getAPIVersion())
  
  var env = xtb_newEnvironment()
  print("env:", env)
  
  var calc = xtb_newCalculator()
  print("calc:", calc)
  
  var res = xtb_newResults()
  print("res:", res)
  
  var mol = xtb_newMolecule(
    env, &natoms, attyp, coord, &charge, &uhf, nil, nil)
  print("mol:", mol)
  
  do {
    let check = xtb_checkEnvironment(env)
    print(check)
    if check != 0 {
      fatalError("Call xtb_showEnvironment.")
    }
  }
  
  /*
   * Apply changes to the environment which will be respected
   * in all further API calls.
   **/
  print("setting verbosity")
  xtb_setVerbosity(env, XTB_VERBOSITY_FULL)
  print("set verbosity")
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  print("Set verbosity to \(XTB_VERBOSITY_FULL)")
  
  /*
     * Load a parametrisation, the last entry is a char* which can
     * be used to provide a particular parameter file.
     *
     * Otherwise the XTBPATH environment variable is used to find
     * parameter files.
     *
     * The calculator has to be reconstructed if the molecular
     * structure is reconstructed.
    **/
  print("setting GFN2-xTB")
  xtb_loadGFN2xTB(env, mol, calc, nil)
  print("set GFN2-xTB")
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  /*
     * Actual calculation, will populate the results object,
     * the API can raise errors on failed SCF convergence or other
     * numerical problems.
     *
     * Not supported boundary conditions are usually raised here.
    **/
  print("running singlepoint")
  xtb_singlepoint(env, mol, calc, res)
  print("ran singlepoint")
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  
  /*
    * Query the environment for properties, an error in the environment
    * is not considered blocking for this calls and allows to query
    * for multiple entries before handling possible errors
   **/
  print("getting energy")
  xtb_getEnergy(env, res, &energy)
  print("got energy")
  if xtb_checkEnvironment(env) != 0 {
    fatalError("Call xtb_showEnvironment.")
  }
  print("energy:", energy)
  
  /*
     * deconstructor will deallocate the objects and overwrite the
     * pointer with NULL
    **/
  print("deleting objects")
  xtb_delResults(&res)
  print("deleted results")
  xtb_delCalculator(&calc)
  print("deleted calculator")
  xtb_delMolecule(&mol)
  print("deleted molecule")
  xtb_delEnvironment(&env)
  print("deleted environment")
  
  print("env:", env)
  print("calc:", calc)
  print("res:", res)
  print("mol:", mol)
  
  exit(0)
}
