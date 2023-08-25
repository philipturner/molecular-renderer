//
//  RenderElectrons.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/25/23.
//

#include <metal_stdlib>
using namespace metal;

// Geometry pass:
//
// Enter the un-normalized wavefunction of each electron in each cell,
// a complex FP32 number. The grid origin is (0, 0, 0) nm, and cell
// coordinates are given as integers. Cell resolution in whole number
// fractions of a nanometer. Not all cells need to be present; a min/max
// operation is performed on the CPU to determine grid size.

// Render pass:
//
// No AI upscaling or antialiasing; wave functions are continuous and
// unlikely to generate aliasing artifacts. Both the total electron
// density and a single electron wave function can be rendered. The latter
// feature should be paired with a mechanism for finding the nearest
// electron interactively, or selecting a point in space that's known
// beforehand. This allows individual electrons to be debugged across
// simulations.
//
// The electron's wave function should rotate over time, to show parts in
// different phases. Use a blue (positive) to red (negative) spectrum and
// only show the real parts, but the imaginary parts will be revealed
// through rotation (if present).
kernel void renderElectrons
(
 // Add a density scale factor to arguments, allowing storage in FP16.
 // [density, r, g, b]
 )
{
  
}
