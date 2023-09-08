# MRSimulation Codec

High-performance codec for recording and replaying molecular simulations.

## Binary Format

File extension: `mrsimulation`

## Plain-Text Format

File extension: `mrsimulation-txt`

The plain-text format is designed to be easy to parse from a Python script. It is slower and consumes more memory than the binary format. You may also face performance issues, as Python is not a fast language[^1]. Nonetheless, this greatly reduces the barrier to usability.

The plain-text format is based on YAML, and arranges characters in a way that maximizes compression ratio during ZIP compression. After serializing the MD trajectory to a text file, run an external archiver application to transform it into a `.zip`. This is reduces file size when sharing over the internet or storing on disk. More efficient techniques can serialize chunks of the text one-by-one using the Python `zlib` library.

In the binary format, each atom's element ID and flags are stored per-frame. 99% of the time, these will never change, and the compressor ignores them. The plain-text format doesn't allow flags to change per frame. Technically they can change per frame cluster, although that is ill-advised.

```yml
specification:
  - https://github.com/philipturner/molecular-renderer 

header:
  # Time span between consecutive frames.
  frame time in femtoseconds: 100.0
  # Spatial resolution in 1/1024 nanometers.
  spatial resolution in approximate picometers: 0.25
  # Forward compatibility for an unimplemented optimization.
  uses checkpoints: false
  # Simulation time is 'frame time in femtoseconds' * 'frame count'.
  frame count: 1200
  # Number of delta-compressed atom coordinates is 'frame cluster size' - 1.
  frame cluster size: 128

metadata:
  # There may or may not be any text in this section. You may need to detect
  # bond topology or electron probability density yourself.
  - sp3 bonds:
    index 0: 0, 2, 4, 6, 8, 10
    index 1: 1, 3, 5, 7, 9, 11

cluster 0:
  # Number of frames is 'frame end' - 'frame start' + 1.
  frame start: 0
  frame end: 127
  metadata:
    # There may or may not be any text in this section.
    - energy in zeptojoules: 100 101 102 103 102 101 101 ...
  atoms:
    # Atom coordinates are signed integers, to be multiplied by 'spatial
    # resolution in approximate picometers' / 1024. After the first frame,
    # coordinates are stored as deltas from the previous frame. Take the
    # cumulative sum to find coordinates at a particular frame.
    #
    # In this case, there are 12 atoms, zero-indexed 0 through 11. The first
    # number after the colon stores the absolute position. The next 128 - 1
    # numbers store relative positions.
    x coordinates:
      - 0: 1023 1 0 0 2 1 0 2 -2 -20 ...
      - 1: -899 1 0 0 2 1 0 2 -3 -15 ...
      - 2: 500 1 0 0 2 1 0 2 -1 -19 ...
      ...
      - 11: -2111 1 0 0 2 1 0 1 -2 -21 ...
    y coordinates:
      - 0: 1023 1 0 0 2 1 0 2 -2 -20 ...
      - 1: -899 1 0 0 2 1 0 2 -3 -15 ...
      - 2: 500 1 0 0 2 1 0 2 -1 -19 ...
      ...
      - 11: -2111 1 0 0 2 1 0 1 -2 -21 ...
    z coordinates:
      - 0: 1023 1 0 0 2 1 0 2 -2 -20 ...
      - 1: -899 1 0 0 2 1 0 2 -3 -15 ...
      - 2: 500 1 0 0 2 1 0 2 -1 -19 ...
      ...
      - 11: -2111 1 0 0 2 1 0 1 -2 -21 ...
    # Atomic number and flags for each atom, in the order atom 0 -> atom 11.
    elements: 1 6 6 1 6 6 1 6 6 1 6 6
    flags: 0 0 0 0 0 0 0 0 0 0 0 0

cluster 1:
  frame start: 128
  frame end: 255
  ...

...

cluster 9:
  # The last cluster is typically smaller than 'frame cluster size'.
  frame start: 1152
  frame end: 1279
  ...
```

## Decoding Script

Here is a Swift script for decoding the plain-text MRSimulation format. It runs on single-core CPU and is therefore very slow. You can execute it at the command-line by adding the Swift toolchain to the PATH, then typing `swift script.swift`.

```swift
// TODO
```

Next, the Swift script is translated to Python. This code can be copied into your existing Python codebase, and used to supply atoms to an external renderer.

```python
# TODO
```

## Future Directions

Metadata sub-specifications:
- Standardize a format for storing bond topology, which permits different bond orders and fractional bonds in graphene. The bond order may change between frames. To be efficient, only store the bonds that have changed.

Bounded continuum finite element method:
- Group the atoms into coarse-grained crystal unit cells. Store the centers and deformations of crystal grains instead of full atom positions.

Quantum chemistry:
- Add an alternative serialization scheme for storing electron probabilities in ab initio molecular simulations.
  - Store the densities for each "important" electron at the mechanosynthesis site.
  - The remaining valence electrons are grouped into a collective density distribution.
  - Core electrons are stored in another collective density distribution.

[^1]: If this become a bottleneck, try scripting in Swift, a language you must get slightly acquainted with to use Molecular Renderer. Ensure you compile in release mode or execute from the Swift REPL. Molecular Renderer's built-in deserializer applies further optimizations, including multithreading and GPU acceleration.