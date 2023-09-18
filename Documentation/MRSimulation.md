# MRSimulation Codec

High-performance codec for recording and replaying molecular simulations.

Table of Contents
- [Binary Format](#binary-format)
- [Plain-Text Format](#plain-text-format)
- [Decoding Script](#decoding-script)
- [Benchmarks](#benchmarks)
- [Future Directions](#future-directions)

## Binary Format

File extension: `mrsim, mrsimulation`

## Plain-Text Format

File extension: `mrsim-txt, mrsimulation-txt`

The plain-text format is designed to be easy to parse from a Python script. It is slower and consumes more memory than the binary format. You may also face performance issues, as Python is not a fast language[^1]. Nonetheless, this greatly reduces the barrier to usability.

The plain-text format is based on YAML, and arranges characters in a way that maximizes compression ratio during ZIP compression. After serializing the MD trajectory to a text file, run an external archiver application to transform it into a `.zip`. This reduces file size when sharing over the internet or storing on disk. More efficient techniques can serialize chunks of the text one-by-one using the Python `zlib` library. If Python had multithreading, you could serialize all the chunks in parallel.

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

frame cluster 0:
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

Implementations:
- Swift: [MRSimulationDecoder.swift](./Scripts/MRSimulationDecoder.swift)
- Python: [MRSimulationDecoder.py](./Scripts/MRSimulationDecoder.py)
- Rust: [MRSimulationDecoder.rs](./Scripts/MRSimulationDecoder.rs) (untested)

To test the decoder, open a terminal window. Set the path of the file to decode:

```bash
export FILE="<mrsim-to-decode>.mrsim-txt"
```

Here is a Swift script for decoding the plain-text MRSimulation format. Add the Swift toolchain to the PATH, then type the following.

```bash
# (Unix)
swiftc -D RELEASE -Ounchecked MRSimulationDecoder.swift && ./MRSimulationDecoder "$FILE" && rm ./MRSimulationDecoder

# (Windows)
swiftc -D RELEASE -Ounchecked MRSimulationDecoder.swift
MRSimulationDecoder.exe "$FILE.mrsim-txt"
```

Next, the Swift script is translated to Python. This code can be copied into your existing Python codebase, and used to supply atoms to an external renderer. If the latencies for Python not acceptable, refer to the footnote[^1].

```bash
python3 MRSimulationDecoder.py $FILE
```

## Benchmarks

| Time to Decode | Atoms | Unzipped Text Size      | Swift (Release) | Swift (Debug) | Python |
| ------------------------------ | ------ | ------ | ------ | ------ | ------- |
| Vdw Oscillator (Prototype 6)   | 10,000 | 58 MB  | 0.3 s  | 5.7 s  | 21.3 s  |
| Vdw Oscillator (Final)         | 37,000 | 820 MB | 3.6 s  | 55.7 s | 5.6 min |
| Strained Shell Bearing (15 ps) | 2,500  | 19 MB  | 0.1 s  | 1.5 s  | 6.3 s   |
| Strained Shell Bearing (5 ns)  | 2,500  | 67 MB  | 0.3 s  | 4.0 s  | 21.4 s  |
| Rhombic Dodecahedra (100 m/s)  | 34,000 | 285 MB | 1.4 s  | 21.2 s | 1.9 min |
| Rhombic Dodecahedra (6400 m/s) | 34,000 | 316 MB | 1.5 s  | 22.3 s | 2.1 min |

To access the MRSimulation files used for these benchmarks, check out https://github.com/philipturner/mrsimulation-benchmarks/releases.

## Future Directions

Metadata sub-specifications:
- Standardize a format for storing bond topology, which permits different bond orders and fractional bonds in graphene. The bond order may change between frames. To be efficient, only store the bonds that have changed.

Bounded continuum finite element method:
- Group the atoms into coarse-grained crystal unit cells. Store the centers and deformations of crystal grains instead of full atom positions.

Quantum chemistry:
- Add an alternative serialization scheme for storing electron probabilities from ab initio molecular simulations.
  - Store the densities for each "important" electron at the mechanosynthesis site.
  - The remaining valence electrons are grouped into a collective density distribution.
  - Core electrons are stored in another collective density distribution.

[^1]: If this become a bottleneck, try scripting in Swift, a language you must get slightly acquainted with to use Molecular Renderer. <b>Always compile in release mode; debug mode is as slow as Python.</b> [PythonKit](https://github.com/pvieito/PythonKit) should allow most of your scripting code to remain written in Python; only the top-level program must be invoked from the Swift compiler.
