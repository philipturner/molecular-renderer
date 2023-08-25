//
//  ElectronGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/25/23.
//

#include <metal_stdlib>
#include "UniformGrid.metal"
using namespace metal;

// Geometry pass:
//
// Enter the un-normalized wavefunction of each electron in each cell,
// a complex FP32 number. The grid origin is (0, 0, 0) nm, and cell
// coordinates are given as integers. Cell resolution in whole number
// fractions of a nanometer. Not all cells need to be present; a min/max
// operation is performed on the CPU to determine grid size.
//
// Need three modes:
// - Many-electron density
//   - most often, all electrons
// - Many-electron wave function
//   - most often, one electron
//   - normalize color by dividing by the greatest absolute value
//   - use density instead of wave magnitude for absorbance
