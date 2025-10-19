# Tests: Medium Atom Count

## Acceleration Structure

Simple test that the ray tracing acceleration structure works correctly, with no bugs in the DDA. Tests a 9827-atom cube. Ambient occlusion is enabled and uses default settings. Alternates between the following camera distances at three-second intervals: 6.54 nm, 20 nm, 50 nm.

## MM4 Energy Minimization

> TODO: Implement in a future PR.

Proof of concept of energy minimization using custom FIRE algorithm, proving there is no need for the built-in minimizer from OpenMM. Relies on GitHub gist.

Use the same {100} reconstructed cube as the previous test.

## Key-Value SSD Caching

> TODO: Implement in a future PR.

Example that uses the `.build` folder for the Swift package to hold 3 different structures cached on disk. Builds on the previous test. Relies on GitHub gist.
