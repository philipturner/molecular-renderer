# Tests: Medium Atom Count

## Acceleration Structure

Simple test that the ray tracing acceleration structure works correctly, with no bugs in the DDA. Tests a 9,827-atom cube. Ambient occlusion is enabled and uses default settings. Alternates between the following camera distances at three-second intervals: 6.54 nm, 20 nm, 50 nm.

## MM4 Energy Minimization

Copy the two Swift files from this [GitHub Gist](https://gist.github.com/philipturner/cc15677a76178521176eb64b362b8b34) into "Sources/Workspace".

Proof of concept of energy minimization using custom FIRE algorithm, proving there is no need for the built-in minimizer from OpenMM. Uses the same (100) reconstructed cube as the previous test. Quite literally a visualization of atoms moving to reconstruct into dimers. Since the nanopart is a cube, surface strain does not significantly warp the physical dimensions.

The trajectory of the minimization varies slightly due to randomness. Perhaps random accumulation of atomics in the GPU code, or random reordering of floating point operations. The convergence criterion is that all atoms have under 10 pN of force. Perhaps floating point rounding error can be the deciding factor for this. Here are the outcomes I have seen:

| end trial | energy      |
| --------: | ----------: |
| 230       | -6216.84 eV |
| 236       | -6216.85 eV |
| 238       | -6216.88 eV |
| 252       | -6216.88 eV |
| 260       | -6216.90 eV |
| 269       | -6216.90 eV |
| 291       | -6216.91 eV |

Reference video: [YouTube](https://youtube.com/shorts/2B3KiKqO_Wc)

## Critical Pixel Count

Test obviously bad thresholds for the critical pixel count heuristic and check for unacceptable quality. The correct value is 50 pixels.

The camera slowly moves away and activates different tiers of the ray count. Test the following surfaces: hydrogen passivated C(111), unpassivated C(110), unpassivated GaAs(110), Au(111).

| Surface   | 500 px | 250 px | 150 px | 50 px  | 15 px  |
| --------- | ------ | ------ | ------ | ------ | ------ |
| C(111)    | yes    | yes    | barely | no     | no     |
| C(110)    | yes    | barely | barely | no     | no     |
| GaAs(110) | yes!   | yes    | yes    | barely | no     |
| Au(111)   | yes!   | yes    | barely | no     | no     |

_Whether self-shadowing appears grainy at 60 Hz._

| Surface   | 500 px | 250 px | 150 px | 50 px  | 15 px  |
| --------- | ------ | ------ | ------ | ------ | ------ |
| C(111)    | yes    | barely | no     | no     | no     |
| C(110)    | yes    | barely | no     | no     | no     |
| GaAs(110) | yes    | yes    | barely | no     | no     |
| Au(111)   | yes    | barely | no     | no     | no     |

_Whether self-shadowing appears grainy at 120 Hz._

| Surface   | 500 px | 250 px | 150 px | 50 px  | 15 px  |
| --------- | ------ | ------ | ------ | ------ | ------ |
| C(111)    | yes    | yes    | barely | no     | no     |
| C(110)    | yes    | yes    | barely | no     | no     |
| GaAs(110) | yes    | yes    | yes    | no     | no     |
| Au(111)   | yes    | yes    | barely | no     | no     |

_Whether self-shadowing appears grainy at 120 Hz, with the secondary ray count overridden to 7._
