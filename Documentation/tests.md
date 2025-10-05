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

The Swift bindings do not alter xTB's default settings for verbosity. After each singlepoint energy calculation, several lines of text appear in the console. Try suppressing this output by adding the following to the top of `main.swift`:

```swift
TODO
```

TODO List: After this test is implemented:
- Remove public API access to the internal C function, `xtb_getAPIVersion`
- Push the 2025-cleanups branch of xTB and build DocC documentation
