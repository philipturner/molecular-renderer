# Tests

To run each test, copy the source code from the relevant file in [Tests](./Tests). Paste the code into `main.swift`, overwriting the Hello World template. Then follow the program startup instructions for your operating system.

## Upscaling

Animation where both the molecule and camera are rotating. Alternates between isopropanol and silane every 3 seconds. Checks that the upscaler can correctly keep track of motion vectors, while upscaling the resolution by 3x.

Reference video for users to compare their upscaling quality: [YouTube](https://www.youtube.com/shorts/4LudSkOQRgs)

## OpenMM Plugin Test

Import the OpenMM module and validate that the OpenCL plugin can be loaded.

Should report that 2 platforms exist: Reference, OpenCL

## MM4

Simulate the time evolution of a compiled structure with ~80 zJ of strain energy. Captures 200 very short frames (2 fs each) and renders the trajectory after 2 seconds of delay.

Temperature, calculated from $\frac{3}{2}$ kT of kinetic energy per atom, should not exceed ~150 K. With 1 fs time steps, energy stays between -42 zJ and -43 zJ.

With 2 fs time steps and 10 fs frames, the energy rises to -29 zJ after only 3 frames. It randomly fluctuates between -29 zJ and -41 zJ for the rest of the simulation. The MM4 default of 2.5 fs changes this envelope to -19 zJ and -36 zJ.

Reference video: [YouTube](https://www.youtube.com/shorts/JQeyLJWGyVU)

## xTB

Test the potential energy curve of an N2 molecule.

> Personal note: keep the diamond systems tests in the xTB repo, create Swift test suite where the xTB library must be loaded. Both GFN2-xTB and GFN-FF must produce expected atomization energies for the tests to pass.

TODO: Attempt to make the MSYS2 binary work on Windows, through runtime linking like from PythonKit. Start with a basic test in a fresh test package. Access LoadLibraryA of a DLL from a different library that's known to work well.
