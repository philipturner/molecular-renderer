# Tests

## Upscaling

TODO: Link reference video for users to compare their upscaling quality, and check for regressions.

## OpenMM Plugin Test

Import the OpenMM module into the Swift file and validate that the OpenCL plugin can be loaded.

TODO: Describe the expected results.

## MM4

TODO: Describe the expected properties of the energy through time evolution.

TODO: Link reference video for what the animation should look like.

## xTB

Test the potential energy curve of an N2 molecule.

> Personal note: keep the diamond systems tests in the xTB repo, create Swift test suite where the xTB library must be loaded. Both GFN2-xTB and GFN-FF must produce expected atomization energies for the tests to pass.

TODO: Attempt to make the MSYS2 binary work on Windows, through runtime linking like from PythonKit. Start with a basic test in a fresh test package. Access LoadLibraryA of a DLL from a different library that's known to work well.
