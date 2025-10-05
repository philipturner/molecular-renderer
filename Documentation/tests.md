# Tests

To run each test, copy the source code from the relevant file in [Tests](./Tests). Paste the code into `main.swift`, overwriting the Hello World template. Then follow the program startup instructions for your operating system.

## Upscaling

Animation where both the molecule and camera are rotating. Alternates between isopropanol and silane every 3 seconds. Checks that the upscaler can correctly keep track of motion vectors, while upscaling the resolution by 3x.

Reference video for users to compare their upscaling quality: [YouTube](https://www.youtube.com/shorts/4LudSkOQRgs)

## OpenMM Plugin Test

Import the OpenMM module and validate that the OpenCL plugin can be loaded.

Should report that two platforms exist: Reference, OpenCL

## MM4

Simulate the time evolution of a compiled structure with ~80 zJ of strain energy. Capture 200 very short frames (2 fs each) and render the trajectory after 2 seconds of delay.

Temperature, calculated from $\frac{3}{2}$ kT of kinetic energy per atom, should not exceed ~150 K. With 1 fs time steps, energy stays between -42 zJ and -43 zJ.

With 2 fs time steps and 10 fs frames, the energy rises to -29 zJ after only 3 frames. It randomly fluctuates between -29 zJ and -41 zJ for the rest of the simulation. The MM4 default of 2.5 fs changes this envelope to -19 zJ and -36 zJ.

Reference video: [YouTube](https://www.youtube.com/shorts/JQeyLJWGyVU)

## xTB

Test the potential energy curve of an N2 molecule. Start by running singlepoint energy calculations at 8 discrete points of the 1D potential energy surface. Then take efficient analytical gradients available with the GFN2-xTB method.

The potential energy minimum is at 0.110 nm. At 0.090 and 0.150 nm, the energy rises ~820 zJ above the minimum. Although the energies are the same at these points, the forces are very different. Force should be about -66000 pN at 0.090 nm and about 24000 pN at 0.150 nm.

At ~0.145 nm, the magnitude of the attractive force reaches its highest point. At longer bond distances, such as 0.155 nm, the magnitude starts falling. This inflection point is a region of "negative stiffness", where the bond stops behaving like a spring, and instead like deformable plastic. To break covalent bonds with mechanosynthesis, the mechanical force must be large enough to enter this region.

## Propargyl Alcohol Tripod

Copy the three Swift files from this [GitHub Gist]() into the Workspace folder.

TODO: Explain the results a little more.

TODO: Hyperlink a YouTube video after pushing the PR to the main branch.
