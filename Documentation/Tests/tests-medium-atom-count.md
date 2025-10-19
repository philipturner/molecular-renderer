# Tests: Medium Atom Count

## Acceleration Structure

Simple test that the ray tracing acceleration structure works correctly, with no bugs in the DDA. Tests a 9827-atom cube. Ambient occlusion is enabled and uses default settings. Alternates between the following camera distances at three-second intervals: 6.54 nm, 20 nm, 50 nm.

## MM4 Energy Minimization

> TODO: Implement in the acceleration structure PR. We can make this more doable by omitting key-value SSD caching.

Proof of concept of energy minimization using custom FIRE algorithm, proving there is no need for the built-in minimizer from OpenMM. Relies on GitHub gist.

Use the same {100} reconstructed cube as the previous test.

## Critical Pixel Count

Test obviously bad thresholds for the critical pixel count heuristic and check for unacceptable quality.

The camera slowly moves away and activates different tiers of the ray count. Tests several different surfaces: hydrogen passivated C(111), Au(111), GaAs(110).

Unlike the long distances test, the lattice doesn't need to cover 100% of the FOV for the entire duration of the test. We can compile a small lattice that shows some empty space when the user is far away.
