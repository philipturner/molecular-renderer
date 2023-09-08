# MRSimulation Codec

High-performance codec for recording and replaying molecular simulations.

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

Here is a Swift script for decoding the plain-text MRSimulation format. It runs on single-core CPU and is therefore very slow. You can execute it at the command-line by adding the Swift toolchain to the PATH, then typing `swift script.swift`.

<details>
<summary>Code</summary>

```swift
import Foundation

// MARK: - Utilities

func startError(
  _ start: any StringProtocol,
  _ sequence: any StringProtocol,
  line: UInt = #line,
  function: StaticString = #function
) -> Never {
  fatalError(
    "'\(start)' is not the start of '\(sequence)'.",
    file: (function), line: line)
}

func assertExpectedPrefix<T: StringProtocol>(
  _ prefix: String,
  from text: T
) where T == T.SubSequence {
  guard text.starts(with: prefix) else {
    startError(prefix, text)
  }
}

func removeExpectedPrefix<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  assertExpectedPrefix(prefix, from: text)
  text.removeFirst(prefix.count)
}

func removeIncluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  while text.starts(with: prefix) {
    text.removeFirst(prefix.count)
  }
}

func removeExcluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) where T == T.SubSequence {
  while !text.starts(with: prefix) {
    text.removeFirst(prefix.count)
  }
}

func extractExcluding<T: StringProtocol>(
  _ prefix: String,
  from text: inout T
) -> String where T == T.SubSequence {
  var output: String = ""
  while !text.starts(with: prefix) {
    output += text.prefix(prefix.count)
    text = text.dropFirst(prefix.count)
  }
  return output
}

func largeIntegerRepr(_ number: Int) -> String {
  if number < 1_000 {
    return String(number)
  } else if number < 1_000_000 {
    let radix = 1_000
    return "\(number / radix).\(number % radix / 100) thousand"
  } else if number < 1_000_000_000 {
    let radix = 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) million"
  } else if number < 1_000_000_000_000 {
    let radix = 1_000_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) billion"
  } else {
    let radix = 1_000_000_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) trillion"
  }
}

func latencyRepr<T: BinaryFloatingPoint>(_ number: T) -> String {
  let number = Int(rint(Double(number) * 1e6)) // microseconds
  if number < 1_000 {
    return "\(number) µs"
  } else if number < 1_000_000 {
    let radix = 1_000
    return "\(number / radix).\(number % radix / (radix / 10)) ms"
  } else if number < 60 * 1_000_000 {
    let radix = 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) s"
  } else if number < 3_600 * 1_000_000 {
    let radix = 60 * 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) min"
  } else {
    let radix = 3_600 * 1_000_000
    return "\(number / radix).\(number % radix / (radix / 10)) hr"
  }
}

func logCheckpoint(message: String, _ start: Date, _ end: Date) {
  let seconds = end.timeIntervalSince(start)
  print("\(message): \u{1b}[0;33m\(latencyRepr(seconds))\u{1b}[0m")
}

// MARK: - Header

let checkpoint0 = Date()
let filePath = CommandLine.arguments[1]
guard let data = FileManager.default.contents(atPath: filePath) else {
  let currentDir = FileManager.default.currentDirectoryPath
  fatalError("File not found at path: \(currentDir)/\(filePath)")
}

let checkpoint1 = Date()
logCheckpoint(message: "Loaded file in", checkpoint0, checkpoint1)

let contents = String(data: data, encoding: .utf8)!
var lines: [String.SubSequence]
if contents.prefix(100).contains(Character("\r")) {
  lines = contents.split(separator: "\r\n", omittingEmptySubsequences: false)
} else {
  lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
}

// Assumes there are no comments in the bulk of the text.
let rangeSeparator = min(100, lines.count)
lines = lines[0..<min(100, lines.count)].compactMap {
  if $0.first(where: { $0 != Character(" ") }) == "#" {
    return nil
  } else {
    return $0
  }
} + Array(lines[rangeSeparator...])

func assertNewLine<T: StringProtocol>(_ string: T) {
  guard string == "" else { startError("", string) }
}

let checkpoint2 = Date()
logCheckpoint(message: "Preprocessed text in", checkpoint1, checkpoint2)

assertExpectedPrefix("specification:", from: lines[0])
assertExpectedPrefix("  - https://github.com", from: lines[1])
assertNewLine(lines[2])

assertExpectedPrefix("header:", from: lines[3])
removeExpectedPrefix("  frame time in femtoseconds: ", from: &lines[4])
let frameTimeInFs = Double(lines[4])!
removeExpectedPrefix("  spatial resolution in approximate picometers: ", from: &lines[5])
let resolutionInApproxPm = Double(lines[5])!

removeExpectedPrefix("  uses checkpoints: ", from: &lines[6])
switch lines[6] {
case "false":
  break
case "true":
  fatalError("Checkpoints not recognized yet.")
default:
  fatalError("Error parsing \(lines[6]).")
}

removeExpectedPrefix("  frame count: ", from: &lines[7])
let frameCount = Int(lines[7])!
removeExpectedPrefix("  frame cluster size: ", from: &lines[8])
let clusterSize = Int(lines[8])!
assertNewLine(lines[9])

assertExpectedPrefix("metadata:", from: lines[10])
assertNewLine(lines[11])

var clusterRanges: [Range<Int>] = []
var clusterStart: Int?
for i in 12..<lines.count {
  if clusterStart == nil {
    if lines[i].count == 0 {
      // Allow multiple newlines, especially at the end of the file.
      continue
    }
    
    removeIncluding("frame cluster ", from: &lines[i])
    let clusterID = Int(extractExcluding(":", from: &lines[i]))!
    let expected = clusterRanges.count
    guard clusterID == clusterRanges.count else {
      fatalError("Cluster ID \(clusterID) does not match expected \(expected).")
    }
    clusterStart = i
  } else {
    if lines[i].count == 0 {
      do {
        guard let clusterStart else {
          fatalError("Cluster start was nil. This should never happen.")
        }
        clusterRanges.append(clusterStart..<i)
      }
      clusterStart = nil
    }
  }
}

let checkpoint3 = Date()
logCheckpoint(message: "Parsed header in", checkpoint2, checkpoint3)

// MARK: - Frames

struct Atom {
  var x: Float
  var y: Float
  var z: Float
  var element: UInt8
  var flags: UInt8
  
  var origin: SIMD3<Float> { SIMD3(x, y, z) }
}
var clusters: [[[Atom]]] = Array(repeating: [], count: clusterRanges.count)

// Data for multithreading.
var numCores = ProcessInfo.processInfo.processorCount
numCores = min(numCores, clusterRanges.count)
let queue = DispatchQueue(
  label: "com.philipturner.molecular-renderer.decode")
var finishedClusterCount: Int = numCores

DispatchQueue.concurrentPerform(iterations: numCores) { z in
  var i = z
  while true {
    let (range, clusterID) = queue.sync { () -> (Range<Int>?, Int?) in
      if i > numCores {
        if finishedClusterCount >= clusterRanges.count {
          return (nil, nil)
        }
        let range = clusterRanges[finishedClusterCount]
        let clusterID = finishedClusterCount
        finishedClusterCount += 1
        return (range, clusterID)
      } else {
        return (clusterRanges[i], i)
      }
    }
    defer {
      i = numCores + 1
    }
    guard let range, let clusterID else {
      break
    }

    queue.sync {
      clusters[clusterID] = []
    }
  }
}

let checkpoint4 = Date()
logCheckpoint(message: "Parsed clusters in", checkpoint3, checkpoint4)

// TODO: Include time to combine all the clusters into a single array (ckpt 5)
logCheckpoint(message: "Total decoding time", checkpoint0, checkpoint4)
print("Warning: This script is not complete. No frame clusters have been parsed yet.")

// TODO: Choose a random (sorted) subset of the frames, then display a few
// random atoms. Show "timestamp, atom ID: element, coordinates"

```

</details>

Next, the Swift script is translated to Python. This code can be copied into your existing Python codebase, and used to supply atoms to an external renderer.

<details>
<summary>Code</summary>

```python
# TODO
```

</details>

| Time to Parse | Unzipped Text Size | Time to Decode (Swift) | Time to Decode (Python) |
| ------------- | ------------------ | -------- | ------- |
| Strained Shell Bearing | 19 MB |
| Rhombic Dodecahedra (6400 m/s) | 300 MB |

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
