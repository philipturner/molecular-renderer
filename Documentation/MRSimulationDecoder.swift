import Foundation

// WARNING: Do not compile this in debug mode or run 'swift file.swift' the
// usual way. It is very slow this way, often slower than without SIMD
// optimizations. Do one of the following:
//
// swiftc -Ounchecked <this-script's-location>.swift && ./script "<mrsim-to-decode>.mrsim-txt"
//
// swift -D NO_SIMD <this-script's-location>.swift "<mrsim-to-decode>.mrsim-txt"

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
    if text.count == 0 {
      break
    }
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
    if text.count == 0 {
      break
    }
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

var log: String = ""
func logCheckpoint(message: String, _ start: Date, _ end: Date) {
  let seconds = end.timeIntervalSince(start)
  let str = "\(message): \u{1b}[0;33m\(latencyRepr(seconds))\u{1b}[0m"
  log += str + "\n"
  print(str)
}

// Data for multithreading.
var numCores: Int
let queue = DispatchQueue(
  label: "com.philipturner.molecular-renderer.decode")

// MARK: - Header

let checkpoint0 = Date()
let filePath = CommandLine.arguments[1]
guard let data = FileManager.default.contents(atPath: filePath) else {
  let currentDir = FileManager.default.currentDirectoryPath
  fatalError("File not found at path: \(currentDir)/\(filePath)")
}
let contents = String(data: data, encoding: .utf8)!
let contentsBuffer = malloc(contents.utf8.count).assumingMemoryBound(to: UInt8.self)
memcpy(contentsBuffer, contents, contents.utf8.count)

let checkpoint1 = Date()
logCheckpoint(message: "Loaded file in", checkpoint0, checkpoint1)

#if NO_SIMD
var lines: [String.SubSequence]
if contents.prefix(100).contains(Character("\r")) {
  // Remove \r on Windows.
  lines = contents.split(separator: "\r\n", omittingEmptySubsequences: false)
} else {
  lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
}

#else
// TODO: Check whether using multithreading helps for supermassive files.
numCores = 1 // ProcessInfo.processInfo.processorCount
var _newLinePositions: [[Int]] = Array(repeating: [], count: numCores)
DispatchQueue.concurrentPerform(iterations: numCores) { z in
  let z = 0
  let numCharacters = contents.count
  let charactersStart = z * numCharacters / numCores
  let charactersEnd = (z + 1) * numCharacters / numCores
  
  var positions: [Int] = []
  for characterID in charactersStart..<charactersEnd {
    if contentsBuffer[characterID] == 10 {
      positions.append(characterID)
    }
  }
  queue.sync {
    _newLinePositions[z] = positions
  }
}

// Add an extra position for the last (non-omitted) subsequence.
var newLinePositions: [Int] = _newLinePositions.flatMap { $0 }
newLinePositions.append(contents.count)

var _lines: [String] = []
var lines: [String.SubSequence] = []

do {
  let isWindows = contents.prefix(100).contains(Character("\r"))
  var currentPosition = 0
  var scratch = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 2)
  defer { scratch.deallocate() }
  
  for position in newLinePositions {
    defer { currentPosition = position + 1 }
    
    var positionAdjusted = position
    if isWindows {
      guard contentsBuffer[position - 1] == 13 else {
        fatalError("Detected Windows-style line endings, but one of the lines didn't have a carriage return.")
      }
      positionAdjusted -= 1
    }
    
    let numCharacters = positionAdjusted - currentPosition
    let numZeroPaddedCharacters = numCharacters + 1
    if scratch.count < numZeroPaddedCharacters {
      func roundUpToPowerOf2(_ input: Int) -> Int {
        1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
      }
      let capacity = roundUpToPowerOf2(numZeroPaddedCharacters)
      scratch = .allocate(capacity: capacity)
    }
    
    memcpy(scratch.baseAddress, contentsBuffer + currentPosition, numCharacters)
    scratch[numCharacters] = 0
    let line = String(cString: scratch.baseAddress!)
    _lines.append(line)
    lines.append(line[...])
  }
}
#endif

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
numCores = ProcessInfo.processInfo.processorCount
numCores = min(numCores, clusterRanges.count)
var finishedClusterCount: Int = numCores

// NOTE: When translating this to Python, replace the call to
// DispatchQueue.concurrentPerform with a simple loop over 0..<numCores. Python
// is incapable of multithreading.
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
    
    var clusterLines = Array(lines[range])
    let frameStart = clusterID * clusterSize
    removeExpectedPrefix("  frame start: ", from: &clusterLines[1])
    removeExpectedPrefix("\(frameStart)", from: &clusterLines[1])
    removeExpectedPrefix("  frame end: ", from: &clusterLines[2])
    let frameEnd = Int(extractExcluding(" ", from: &clusterLines[2]))!
    removeExpectedPrefix("  metadata:", from: &clusterLines[3])
    
    // Assume there is no per-frame metadata.
    removeExpectedPrefix("  atoms:", from: &clusterLines[4])
    
    let numAtomsLines = clusterLines.count - 5 - 3 - 2
    precondition(numAtomsLines % 3 == 0, "Unexpected number of lines.")
    let numAtoms = numAtomsLines / 3
    
    var tempPointers: [UnsafeMutableBufferPointer<UInt8>] = []
    for _ in 0..<8 {
      tempPointers.append(.allocate(capacity: 2))
    }
    defer {
      for i in 0..<8 {
        tempPointers[i].deallocate()
      }
    }
    
    var lineID = 5
    var allAxesCoords: [[[Float]]] = []
    for coordinate in ["x", "y", "z"] {
      removeExpectedPrefix("    \(coordinate)", from: &clusterLines[lineID])
      removeExpectedPrefix(" coordinates:", from: &clusterLines[lineID])
      lineID += 1
      
      var atomCount: Int = 0
      var allAtomsCoords: [[Float]] = []
      
      // MARK: - Beginning of section to omit when translating to Python
      
      #if NO_SIMD
      let numVectors = 0
      #else
      let numVectors = numAtoms / 8
      #endif
      for vectorID in 0..<numVectors {
        // Copy the strings' raw data to a custom memory region.
        var stringMaxIndices: SIMD8<Int32> = .zero
        for lane in 0..<8 {
          func roundUpToPowerOf2(_ input: Int) -> Int {
            1 << (Int.bitWidth - max(0, input - 1).leadingZeroBitCount)
          }
          let rawCount = clusterLines[lineID + lane].count
          stringMaxIndices[lane] = Int32(rawCount - 1)
          
          let roundedCount = roundUpToPowerOf2(rawCount)
          if roundedCount > tempPointers[lane].count {
            tempPointers[lane].deallocate()
            tempPointers[lane] = .allocate(capacity: roundedCount)
          }
          clusterLines[lineID + lane].withUTF8 {
            memcpy(tempPointers[lane].baseAddress, $0.baseAddress, $0.count)
          }
        }
        defer { lineID += 8 }
        
        var cursors: SIMD8<Int32> = .init(repeating: Int32("      - ".count))
        let laneIDs = SIMD8<Int32>(0, 1, 2, 3, 4, 5, 6, 7)
        var atomIDs = SIMD8<Int32>(repeating: Int32(vectorID * 8)) &+ laneIDs
        @inline(__always)
        func fetch() -> SIMD8<Int32> {
          var output: SIMD8<Int32> = .zero
          var boundedCursors = cursors
          boundedCursors.replace(
            with: stringMaxIndices, where: cursors .> stringMaxIndices)
          for lane in 0..<8 {
            output[lane] = Int32(tempPointers[lane][Int(boundedCursors[lane])])
          }
          output.replace(
            with: .init(repeating: 32), where: cursors .> stringMaxIndices)
          return output
        }
        
        var remainders = atomIDs
        while any(remainders .> 0) {
          var activeMask = SIMD8<Int32>.zero
          activeMask.replace(with: .one, where: remainders .> 0)
          cursors &+= activeMask
          remainders /= 10
        }
        do {
          let zeroMask = atomIDs .== 0
          cursors.replace(with: cursors &+ 1, where: zeroMask)
        }
        cursors &+= Int32(":".count)
        
        var arrays: [[Float]] = []
        for lane in 0..<8 {
          arrays.append([])
          arrays[lane].reserveCapacity(frameEnd - frameStart + 1)
        }
        for frameID in 0..<(frameEnd - frameStart + 1) {
          let characters = fetch()
          guard all(characters .== 32) else {
            fatalError("One of the numbers did not begin with a space.")
          }
          cursors &+= 1
          
          var activeMask = SIMD8<Int32>.one
          var signs = SIMD8<Int32>.one
          var cumulativeSums = SIMD8<Int32>.zero
          while any(activeMask .> 0) {
            let characters = fetch()
            
            var spaceMask = characters .== 32
            spaceMask = spaceMask .& (activeMask .> 0)
            activeMask.replace(with: SIMD8<Int32>.zero, where: spaceMask)
            
            var cursorMask = characters .!= 32
            cursorMask = cursorMask .& (activeMask .> 0)
            cursors.replace(with: cursors &+ 1, where: cursorMask)
            
            var minusMask = characters .== 0o55
            minusMask = minusMask .& (activeMask .> 0)
            signs.replace(with: 0 &- .one, where: minusMask)
            
            let digits = characters &- 48
            var digitMask = (digits .>= 0) .& (digits .<= 9)
            digitMask = digitMask .& (activeMask .> 0)
            cumulativeSums.replace(
              with: cumulativeSums &* 10 &+ digits, where: digitMask)
          }
          
          var floats = SIMD8<Float>(cumulativeSums)
          let multiplier = Float(resolutionInApproxPm / 1024)
          floats *= multiplier
          for lane in 0..<8 {
            arrays[lane].append(floats[lane])
          }
        }
        
        for lane in 0..<8 {
          allAtomsCoords.append(arrays[lane])
        }
      }
      
      // MARK: - End of section to omit when translating to Python
      
      while true {
        assertExpectedPrefix("    ", from: clusterLines[lineID])
        guard clusterLines[lineID].prefix(5) == "     " else {
          break
        }
        defer { lineID += 1 }
        removeExpectedPrefix(
          "      - \(atomCount):", from: &clusterLines[lineID])
        defer { atomCount += 1 }
        
        var cumulativeSum: Int32 = 0
        let multiplier = Float(resolutionInApproxPm / 1024)
        var coords: [Float] = []
        var numberSign: Int32 = 1
        var numberAccumulated: Int32 = 0
        @inline(__always)
        func appendLatestNumber() {
          numberAccumulated *= numberSign
          let integer = numberAccumulated
          numberSign = 1
          numberAccumulated = 0
          
          cumulativeSum += integer
          let float = Float(integer) * multiplier
          coords.append(float)
        }
        
        // Now, we need to vectorize the code across the number of atoms.
        removeExpectedPrefix(" ", from: &clusterLines[lineID])
        clusterLines[lineID].withUTF8 { buffer in
          for charID in 0..<buffer.count {
            let char: UInt8 = buffer[charID]
            switch char {
            case 32: appendLatestNumber()
            case 0o55: numberSign = -1
            default:
              let digit = Int32(char) - 48
              numberAccumulated = numberAccumulated * 10 + digit
            }
          }
          appendLatestNumber()
        }
        
        allAtomsCoords.append(coords)
      }
      allAxesCoords.append(allAtomsCoords)
    }
    
    // (x y z)(atomID)(frameID) -> (frameID)(atomID)(x y z)
    // var allAxesCoords: [[[Float]]] = []
    var cluster: [[Atom]] = []
    for frameID in 0...(frameEnd - frameStart) {
      var array: [Atom] = []
      array.reserveCapacity(numAtoms)
      
      for atomID in 0..<numAtoms {
        let x = allAxesCoords[0][atomID][frameID]
        let y = allAxesCoords[1][atomID][frameID]
        let z = allAxesCoords[2][atomID][frameID]
        
        // TODO: Extract the element and flags, after debugging the coordinates.
        // Then, profile execution speed.
        let atom = Atom(x: x, y: y, z: z, element: 0, flags: 0)
        array.append(atom)
      }
      cluster.append(array)
    }
    
    queue.sync {
      clusters[clusterID] = cluster
    }
  }
}
let frames: [[Atom]] = clusters.flatMap { $0 }

let checkpoint4 = Date()
logCheckpoint(message: "Parsed clusters in", checkpoint3, checkpoint4)
logCheckpoint(message: "Total decoding time", checkpoint0, checkpoint4)

let randomFrameIDs = (0..<10).map { _ in
  Int.random(in: frames.indices)
}.sorted()

// Track the same few atoms across all frames.
let randomAtomIDs = (0..<4).map { _ in
  Int.random(in: 0..<frames[0].count)
}.sorted()

for frameID in randomFrameIDs {
  precondition(frames[frameID].count == frames[0].count)
  let timeStampInPs = Double(frameID) * frameTimeInFs / 1e3
  print()
  print("Frame \(frameID)")
  print("- timestamp: \(String(format: "%.3f", timeStampInPs)) ps")
  
  for atomID in randomAtomIDs {
    let atom = frames[frameID][atomID]
    print(" - atom \(atomID): \(String(format: "%.3f", atom.x)) \(String(format: "%.3f", atom.y)) \(String(format: "%.3f", atom.z)) \(atom.element) \(atom.flags)")
  }
}

print()
print(log)
