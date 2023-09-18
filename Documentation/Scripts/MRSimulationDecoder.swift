import Foundation

// WARNING: Do not compile this in debug mode or run 'swift file.swift' with
// SIMD instructions. That combination makes it 10x slower, not 10x faster. Do
// one of the following:
//
// Release Mode:
//   Unix:
//     swiftc -D RELEASE -Ounchecked <script-file-path>/NAME.swift && ./NAME "<mrsim-to-decode>.mrsim-txt" && rm ./NAME
//   Windows:
//     swiftc -D RELEASE -Ounchecked <script-file-path>/NAME.swift
//     NAME.exe "<mrsim-to-decode>.mrsim-txt"
//
// Debug Mode:
//   Unix:
//     swift <script-file-path>/NAME.swift "<mrsim-to-decode>.mrsim-txt"
//   Windows:
//     swiftc <script-file-path>/NAME.swift
//     NAME.exe "<mrsim-to-decode>.mrsim-txt"
//
// Replace NAME.swift with the script's file name.

// MARK: - Utilities

typealias ByteArray = [UInt8]
typealias ByteArraySubSequence = ByteArray.SubSequence

func checkStarts(
  _ prefix: StaticString,
  from text: ByteArraySubSequence
) -> Bool {
  guard text.count >= prefix.utf8CodeUnitCount else {
    return false
  }
  
  let count = prefix.utf8CodeUnitCount
  return withUnsafeTemporaryAllocation(
    of: UInt8.self, capacity: count
  ) { buffer in
    var startIndex = text.startIndex
    for i in 0..<count {
      buffer[i] = text[startIndex]
      startIndex = text.index(after: startIndex)
    }
    return memcmp(prefix.utf8Start, buffer.baseAddress, count) == 0
  }
}

func checkStarts(
  _ prefix: String,
  from text: ByteArraySubSequence
) -> Bool {
  guard text.count >= prefix.count else {
    return false
  }
  
  let count = prefix.count
  return withUnsafeTemporaryAllocation(
    of: UInt8.self, capacity: count
  ) { buffer in
    var startIndexPrefix = prefix.startIndex
    var startIndexText = text.startIndex
    var matched = true
    for i in 0..<count {
      guard prefix[startIndexPrefix].asciiValue! == text[startIndexText] else {
        matched = false
        break
      }
      startIndexPrefix = prefix.index(after: startIndexPrefix)
      startIndexText = text.index(after: startIndexText)
    }
    return matched
  }
}

func assertExpectedPrefix(
  _ prefix: StaticString,
  from text: ByteArraySubSequence
) {
  guard text.count >= prefix.utf8CodeUnitCount,
        checkStarts(prefix, from: text) else {
    fatalError("'\(prefix)' is not the start of '\(text)'.")
  }
}

func removeExpectedPrefix(
  _ prefix: String,
  from text: inout ByteArraySubSequence
) {
  guard checkStarts(prefix, from: text) else {
    fatalError("'\(prefix)' is not the start of '\(text)'.")
  }
  text.removeFirst(prefix.count)
}

func removeExpectedPrefix(
  _ prefix: [UInt8],
  from text: inout ByteArraySubSequence
) {
  guard text.starts(with: prefix) else {
    fatalError("'\(prefix)' is not the start of '\(text)'.")
  }
  text.removeFirst(prefix.count)
}

func removeExpectedPrefix(
  _ prefix: StaticString,
  from text: inout ByteArraySubSequence
) {
  assertExpectedPrefix(prefix, from: text)
  text.removeFirst(prefix.utf8CodeUnitCount)
}

func removeIncluding(
  _ prefix: StaticString,
  from text: inout ByteArraySubSequence
) {
  while checkStarts(prefix, from: text) {
    text.removeFirst(prefix.utf8CodeUnitCount)
  }
}

func removeExcluding(
  _ prefix: StaticString,
  from text: inout ByteArraySubSequence
) {
  while !checkStarts(prefix, from: text) {
    text.removeFirst(prefix.utf8CodeUnitCount)
    if text.count == 0 {
      break
    }
  }
}

func extractExcluding(
  _ prefix: StaticString,
  from text: inout ByteArraySubSequence
) -> String {
  var output: String = ""
  while !checkStarts(prefix, from: text) {
    output.append(Character(Unicode.Scalar(text.first!)))
    text = text.dropFirst(1)
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
let contents = [UInt8](
  unsafeUninitializedCapacity: data.count,
  initializingWith: { buffer, count in
    count = data.count
    data.copyBytes(to: buffer.baseAddress!, count: data.count)
  }
)
let contentsBuffer = malloc(contents.count).assumingMemoryBound(to: UInt8.self)
memcpy(contentsBuffer, contents, contents.count)


let checkpoint1 = Date()
logCheckpoint(message: "Loaded file in", checkpoint0, checkpoint1)

var _lines: [[UInt8]] = []
var lines: [ByteArraySubSequence]
do {
#if RELEASE
  var pendingStart = 0
  for index in 0..<contents.count {
    if contents[index] == 10 {
      _lines.append([UInt8](contents[pendingStart..<index]))
      pendingStart = index + 1
    } else if index == contents.count - 1 {
      _lines.append([UInt8](contents[pendingStart...]))
      pendingStart = -1000
    }
  }
  
  // Check for carriage returns on Windows.
  if contents.prefix(100).contains(13) {
    for lineID in _lines.indices {
      if _lines[lineID].last == 13 {
        _lines[lineID].removeLast()
      }
    }
  }
#else
  
  let strContents = String(data: data, encoding: .utf8)!
  var strLines: [String]
  if strContents.prefix(100).contains(Character("\r")) {
    // Remove \r on Windows.
    strLines = strContents.components(separatedBy: "\r\n")
  } else {
    strLines = strContents.components(separatedBy: "\n")
  }
  for var strLine in strLines {
    strLine.withUTF8 { utf8 in
      _lines.append([UInt8](unsafeUninitializedCapacity: utf8.count) {
        $1 = utf8.count
        memcpy($0.baseAddress, utf8.baseAddress, utf8.count)
      })
    }
  }
#endif
  
  lines = _lines.map { $0[...] }
}

// Assumes there are no comments in the bulk of the text.
let rangeSeparator = min(100, lines.count)
lines = lines[0..<min(100, lines.count)].compactMap {
  if $0.first(where: { $0 != 32 }) == 35 {
    return nil
  } else {
    return $0
  }
} + Array(lines[rangeSeparator...])

func assertNewLine<T: Collection>(_ string: T) {
  guard string.isEmpty else {
    fatalError("'\(string)' is not empty.")
  }
}

func makeUTF8String(_ characters: ByteArraySubSequence) -> String {
  withUnsafeTemporaryAllocation(
    of: UInt8.self, capacity: characters.count + 1
  ) { cString in
    for i in 0..<characters.count {
      cString[i] = characters[characters.startIndex + i]
    }
    cString[characters.count] = 0
    return String(cString: cString.baseAddress!)
  }
}

let checkpoint2 = Date()
logCheckpoint(message: "Preprocessed text in", checkpoint1, checkpoint2)

assertExpectedPrefix("specification:", from: lines[0])
assertExpectedPrefix("  - https://github.com", from: lines[1])
assertNewLine(lines[2])

assertExpectedPrefix("header:", from: lines[3])
removeExpectedPrefix("  frame time in femtoseconds: ", from: &lines[4])
let frameTimeInFs = Double(makeUTF8String(lines[4]))!
removeExpectedPrefix("  spatial resolution in approximate picometers: ", from: &lines[5])
let resolutionInApproxPm = Double(makeUTF8String(lines[5]))!

removeExpectedPrefix("  uses checkpoints: ", from: &lines[6])
switch lines[6] {
case [102, 97, 108, 115, 101]: // false
  break
case [116, 114, 117, 101]: // true
  fatalError("Checkpoints not recognized yet.")
default:
  fatalError("Error parsing \(lines[6]).")
}

removeExpectedPrefix("  frame count: ", from: &lines[7])
let frameCount = Int(makeUTF8String(lines[7]))!
removeExpectedPrefix("  frame cluster size: ", from: &lines[8])
let clusterSize = Int(makeUTF8String(lines[8]))!
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
    
    let executionWidth: Int = 4
    typealias VInt = SIMD4<Int32>
    typealias VFloat = SIMD4<Float>
    let laneIDs = VInt(0, 1, 2, 3)
    
    var tempPointers: [UnsafeMutableBufferPointer<UInt8>] = []
    for _ in 0..<executionWidth {
      tempPointers.append(.allocate(capacity: 2))
    }
    defer {
      for i in 0..<executionWidth {
        tempPointers[i].deallocate()
      }
    }
    
    var lineID = 5
    var allAxesCoords: [[[Float]]] = []
    for coordinate in ["x", "y", "z"] {
      removeExpectedPrefix("    \(coordinate)", from: &clusterLines[lineID])
      removeExpectedPrefix(" coordinates:", from: &clusterLines[lineID])
      lineID += 1
      
      var allAtomsCoords: [[Float]] = []
      
      // MARK: - Beginning of section to omit when translating to Python
      
      #if RELEASE
      let numVectors = numAtoms / executionWidth
      #else
      let numVectors = 0
      #endif
      for vectorID in 0..<numVectors {
        // Copy the strings' raw data to a custom memory region.
        var stringMaxIndices: VInt = .zero
        for lane in 0..<executionWidth {
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
          clusterLines[lineID + lane].withUnsafeBufferPointer {
            memcpy(tempPointers[lane].baseAddress, $0.baseAddress, $0.count)
          }
        }
        defer { lineID += executionWidth }
        
        var cursors: VInt = .init(repeating: Int32("      - ".count))
        var atomIDs = VInt(repeating: Int32(
          vectorID * executionWidth)) &+ laneIDs
        @inline(__always)
        func fetch() -> VInt {
          var output: VInt = .zero
          var boundedCursors = cursors
          boundedCursors.replace(
            with: stringMaxIndices, where: cursors .> stringMaxIndices)
          for lane in 0..<executionWidth {
            output[lane] = Int32(tempPointers[lane][Int(boundedCursors[lane])])
          }
          output.replace(
            with: .init(repeating: 32), where: cursors .> stringMaxIndices)
          return output
        }
        
        var remainders = atomIDs
        while any(remainders .> 0) {
          var activeMask = VInt.zero
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
        for lane in 0..<executionWidth {
          arrays.append([])
          arrays[lane].reserveCapacity(frameEnd - frameStart + 1)
        }
        for frameID in 0..<(frameEnd - frameStart + 1) {
          let characters = fetch()
          guard all(characters .== 32) else {
            fatalError("One of the numbers did not begin with a space.")
          }
          cursors &+= 1
          
          var activeMask = VInt.one
          var signs = VInt.one
          var cumulativeSums = VInt.zero
          while any(activeMask .> 0) {
            let characters = fetch()
            
            var spaceMask = characters .== 32
            spaceMask = spaceMask .& (activeMask .> 0)
            activeMask.replace(with: VInt.zero, where: spaceMask)
            
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
          
          var floats = VFloat(cumulativeSums &* signs)
          let multiplier = Float(resolutionInApproxPm / 1024)
          floats *= multiplier
          for lane in 0..<executionWidth {
            arrays[lane].append(floats[lane])
          }
        }
        
        for lane in 0..<executionWidth {
          allAtomsCoords.append(arrays[lane])
        }
      }
      
      // MARK: - End of section to omit when translating to Python
      
      #if RELEASE
      let doLoop = numVectors * executionWidth < numAtoms
      var currentAtomID = numVectors * executionWidth
      #else
      let doLoop = true
      var currentAtomID = 0
      #endif
      while doLoop {
        assertExpectedPrefix("    ", from: clusterLines[lineID])
        guard clusterLines[lineID].prefix(5) == [32, 32, 32, 32, 32] else {
          break
        }
        defer { lineID += 1 }
        removeExpectedPrefix(
          "      - \(currentAtomID):", from: &clusterLines[lineID])
        defer { currentAtomID += 1 }
        
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
        clusterLines[lineID].withUnsafeBufferPointer { buffer in
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
    
    var tail: [[UInt8]] = []
    for label in ["elements", "flags"] {
      removeExpectedPrefix("    \(label):", from: &clusterLines[lineID])
      defer { lineID += 1 }
      
      var array: [UInt8] = []
      defer { tail.append(array) }
      
      var cursor: Int = 0
      let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(
        capacity: clusterLines[lineID].count + 1)
      defer { buffer.deallocate() }
      
      clusterLines[lineID].withUnsafeBufferPointer { copyBuffer in
        memcpy(buffer.baseAddress, copyBuffer.baseAddress!, copyBuffer.count)
        buffer[copyBuffer.count] = 0
      }
      
      for atomID in 0..<numAtoms {
        precondition(buffer[cursor] == 32, "No space.")
        cursor += 1
        
        var value: Int32 = 0
        while buffer[cursor] != 0 && buffer[cursor] != 32 {
          let digit = Int32(buffer[cursor]) - 48
          cursor += 1
          precondition(digit >= 0 && digit <= 9, "Invalid digit.")
          value = value * 10 + digit
        }
        array.append(UInt8(value))
      }
    }
    
    var cluster: [[Atom]] = []
    for frameID in 0...(frameEnd - frameStart) {
      var array: [Atom] = []
      array.reserveCapacity(numAtoms)
      
      for atomID in 0..<numAtoms {
        let x = allAxesCoords[0][atomID][frameID]
        let y = allAxesCoords[1][atomID][frameID]
        let z = allAxesCoords[2][atomID][frameID]
        let element = tail[0][atomID]
        let flags = tail[1][atomID]
        
        let atom = Atom(x: x, y: y, z: z, element: element, flags: flags)
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
