# Serialization

The code in this folder is about serializing molecular dynamics trajectories to the disk. The pipeline went from an Apple-specific binary MRSimulation codec, to generating a pre-scripted camera trajectory, to exporting a massive GIF. The GIF was at 50 FPS, the largest framerate supported by the codec. It could be converted to 60 FPS in Shotcut.

Much of the original APIs were archived because they grew unwieldy. The code was outdated, often project-specific, and needs to be redone in a fresh way. There is a new MRSimulation text codec. In addition, a version 2 of the binary codec can be created. It would be cross-platform from the start, using vectorized CPU code instead of GPU code. This design approach will make it easier to port to non-Apple platforms. It was also questionable whether GPU was needed in the first place, other than Metal being easier than vectorized Swift code at the time.

Table of Contents
- [Base64](./Base64/README.md)
- [GIF](./GIF/README.md)
- [MRSimulation](./MRSimulation/README.md)
- [SimulationImport](./SimulationImport/README.md)
