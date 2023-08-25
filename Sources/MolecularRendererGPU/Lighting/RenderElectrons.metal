//
//  RenderElectrons.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 8/25/23.
//

#include <metal_stdlib>
using namespace metal;

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
// different phases. Use a blue (positive) to clear (zero) to red (negative)
// spectrum and only show the real parts, but the imaginary parts will be
// revealed through rotation (if present). Rotate so it makes a half-turn every
// 1 second.
kernel void renderElectrons()
{
  
}
