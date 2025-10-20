# Tests: Medium Atom Count

## Acceleration Structure

Simple test that the ray tracing acceleration structure works correctly, with no bugs in the DDA. Tests a 9827-atom cube. Ambient occlusion is enabled and uses default settings. Alternates between the following camera distances at three-second intervals: 6.54 nm, 20 nm, 50 nm.

## MM4 Energy Minimization

> TODO: Implement in the acceleration structure PR. We can make this more doable by omitting key-value SSD caching.

Proof of concept of energy minimization using custom FIRE algorithm, proving there is no need for the built-in minimizer from OpenMM. Relies on GitHub gist.

Uses the same {100} reconstructed cube as the previous test. Quite literally a visualization of atoms moving to reconstruct into dimers. Since the nanopart is a cube, surface strain does not significantly warp the physical dimensions.

TODO: Create and link a YouTube video in a future commit.

## Voxel Group Marks

Test for a case that would trigger a compute cost bottleneck, if 8 nm scoping of the per-dense-voxel compute work went wrong. A small object that moves through many cells in the world volume, ultimately covering a massive volume.

> TODO: Nevermind; we can recycle the rotating beam test, re-activate the code for inspecting the general counters. Remember 164, 184, 190-194 growing all the way to ~230 after 16 iterations with beamDepth = 2 (80k atoms in cross, 40k atoms in beam). Make the shader code intentionally wrong and watch the results change.

## Critical Pixel Count

Test obviously bad thresholds for the critical pixel count heuristic and check for unacceptable quality.

The camera slowly moves away and activates different tiers of the ray count. Test the following surfaces: hydrogen passivated C(111), unpassivated C(110), Au(111), GaAs(110).

Unlike the long distances test, the lattice doesn't need to cover 100% of the FOV for the entire duration of the test. We can compile a small lattice that shows some empty space when the user is far away.
