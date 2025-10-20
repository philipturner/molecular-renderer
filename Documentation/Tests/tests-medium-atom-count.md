# Tests: Medium Atom Count

## Acceleration Structure

Simple test that the ray tracing acceleration structure works correctly, with no bugs in the DDA. Tests a 9827-atom cube. Ambient occlusion is enabled and uses default settings. Alternates between the following camera distances at three-second intervals: 6.54 nm, 20 nm, 50 nm.

## MM4 Energy Minimization

> TODO: Implement in the acceleration structure PR. We can make this more doable by omitting key-value SSD caching.

Proof of concept of energy minimization using custom FIRE algorithm, proving there is no need for the built-in minimizer from OpenMM. Relies on GitHub gist.

Uses the same {100} reconstructed cube as the previous test. Quite literally a visualization of atoms moving to reconstruct into dimers. Since the nanopart is a cube, surface strain does not significantly warp the physical dimensions.

TODO: Create and link a YouTube video in a future commit.

## Critical Pixel Count

Test obviously bad thresholds for the critical pixel count heuristic and check for unacceptable quality. The correct value is 50 pixels.

The camera slowly moves away and activates different tiers of the ray count. Test the following surfaces: hydrogen passivated C(111), unpassivated C(110), Au(111), GaAs(110).

| Surface   |
| --------- |
| C(111)    |
| C(110)    |
| GaAs(110) |
| Au(111)   |

_Whether self-shadowing appears grainy at 60 Hz._

_Whether self-shadowing appears grainy at 120 Hz._

_Whether self-shadowing appears grainy at 120 Hz, with the secondary ray count overridden to 7._
