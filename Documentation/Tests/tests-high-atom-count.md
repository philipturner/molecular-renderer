# Tests: High Atom Count

## Rotating Beam

Objective is to reach as many atoms as possible, until the Metal Performance HUD shows the FPS dropping below the display's native refresh rate. Windows users can detect the drop by observing stuttering in the animation.

| Maximum Atom Count | macOS System | Windows System |
| ------------------ | -----------: | -------------: |
| Theoretical        | 1,546,000    | 954,000        |
| Actual             | 934,000      | TBD            |

_For more detailed explanation of the benchmarked hardware, study the source code in "Sources/MolecularRenderer/Atoms.swift"._

In the source code, look for the declaration of `beamDepth`. The default value is 10. Increase this number as much as possible.

<details>
<summary>Guide to figuring out what beam depths to try</summary>

| Beam Depth | Atom Count |
| :--------: | ---------: |
| 1   | 27,830    |
| 2   | 44,007    |
| 3   | 60,184    |
| 4   | 76,361    |
| 6   | 108,715   |
| 8   | 141,069   |
| 12  | 204,777   |
| 16  | 270,485   |
| 24  | 399,901   |
| 32  | 529,317   |
| 40  | 658,733   |
| 48  | 788,149   |
| 56  | 917,565   |
| 64  | 1,046,981 |
| 80  | 1,305,813 |
| 96  | 1,564,645 |
| 112 | 1,823,477 |

</details>

## Long Distances

Run a test that hits the pain points of ray tracing. Long primary ray traversal times in the DDA, high divergence for AO rays. Not exactly stressing the BVH update process. Rather, a single unchanging BVH and a rotating camera to detect stuttering. Make the test scaleable to different distances and window sizes.

![Long Distances Benchmark](../LongDistancesBenchmark.png)

TODO: Include screenshot of raw data for the AO investigation.

## Chunk Loader

> TODO: Implement in a future PR.

Objective is to reach as many atoms as possible, until your GPU runs out of memory. After that, build the BVH as quickly as possible without dropping the FPS.

The scene will take some time to design correctly. Expect it to hit challenging pain points for performance. It is a rigorous proof that I have achieved the ultimate goal of computer graphics.

| Chip            | RAM    | Theoretical Max Atoms |
| --------------- | -----: | --------------------: |
| GTX 970         | 3.5 GB | 33M   |
| M1 @ 60 Hz      |   8 GB | 75M   |
| M1 Pro @ 120 Hz |  16 GB | 150M  |
| 7900 XTX        |  24 GB | 225M  |
| RTX 4090        |  24 GB | 225M  |
| M1 Max          |  32 GB | 300M  |
| RTX 5090        |  32 GB | 300M  |
| M3 Max          | 128 GB | 1200M |
| M3 Ultra        | 512 GB | 4800M |

A large number of 100k atom cubes, each with a random orientation. All packed in a grid, with a spacing to ensure they don't overlap. This hits the pain points of partial filling that waste memory, therefore being a realistic example of achievable atom count.
