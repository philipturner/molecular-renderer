//
//  GOSPEL_tucker_diamond.swift
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
  let GOSPEL = Python.import("gospel").GOSPEL
  let bulk = Python.import("ase.build").bulk
  let Bohr = Python.import("ase.units").Bohr
  print(np)
  print(GOSPEL)
  print(bulk)
  print(Bohr)
  
  let upf_files =
  ["/Users/philipturner/Documents/OpenMM/GOSPEL/tests/DATA/C.pbe-n-nc.UPF"]
  
  let ranks = PythonObject(tupleOf: 12, 12, 12)
  
  let atoms = bulk("C", "diamond", a: 3.57, cubic: true)
  let calc = GOSPEL(
    grid: ["spacing": 0.3 * Bohr],
    pp: ["upf": PythonObject(upf_files), "filtering": PythonObject(true)],
    print_energies: true,
    xc: ["type": "gga_x_pbe + gga_c_pbe"],
    kpts: PythonObject(tupleOf: 4, 4, 4, "gamma"),
    eigensolver: [
      "type": PythonObject("tucker"),
      "ignore_kbproj": PythonObject(true),
      "ranks": ranks,
      "check_residue": PythonObject(false),
      "convg_tol": PythonObject(1e-5)
    ],
    occupation: [
      "smearing": PythonObject("Fermi-Dirac"),
      "temperature": PythonObject(0.01)],
    use_cuda: false
  )
  
  atoms.calc = calc
  let forces = atoms.get_forces()
  print("forces = \(forces)")
  
  /*
   There was a runtime crash due to an uninitialized variable somewhere. I could
   not figure out how to make this test case execute.
   
   PythonKit/Python.swift:621: Fatal error: 'try!' expression unexpectedly raised an error: Python exception: 'Tucker' object has no attribute 'convg_tol'
   Traceback:
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/ase/atoms.py", line 788, in get_forces
       forces = self._calc.get_forces(self)
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/ase/calculators/abc.py", line 23, in get_forces
       return self.get_property('forces', atoms)
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/ase/calculators/calculator.py", line 737, in get_property
       self.calculate(atoms, [name], system_changes)
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/gospel-0.0.1-py3.11.egg/gospel/calculator.py", line 315, in calculate
       self.initialize(self.atoms)
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/gospel-0.0.1-py3.11.egg/gospel/util.py", line 20, in wrapper
       result = func(*args, **kwargs)
                ^^^^^^^^^^^^^^^^^^^^^
     File "/Users/philipturner/miniforge3/lib/python3.11/site-packages/gospel-0.0.1-py3.11.egg/gospel/calculator.py", line 254, in initialize
       if self.eigensolver.convg_tol is None:
          ^^^^^^^^^^^^^^^^^^^^^^^^^^
   */
}
