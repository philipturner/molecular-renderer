# Tests and Tutorials

Game plan:
- Host the tutorial Swift files and images in this repo while developing them.
- Once completed, migrate them to GitHub gists

## Upscaling

Link reference video for users to compare their upscaling quality, and check for regressions.

## Basic OpenMM Test

Import the OpenMM module into the Swift file and validate that the OpenCL plugin can be loaded.

## MM4

Describe the expected properties of the energy through time evolution. Add a few more assertions to the code, such as that kinetic energy is nonzero after time evolution.

Link reference video for what the animation should look like.

## xTB

Attempt to make the MSYS2 binary work on Windows, through runtime linking like from PythonKit. Start with a basic test in a fresh test package. Access LoadLibraryA of a DLL from a different library that's known to work well.

## HDL Tutorial

TODO: Make accompanying Swift code to position the camera, and properly render this structure. The user can choose from a few different camera angles, which may be documented in a GitHub gist comment with images.
