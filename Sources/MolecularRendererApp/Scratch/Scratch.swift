// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  let Z: Int = 86
  let histogram = Histogram(Z: Z)
  print()
  print("Z = \(Z)")
  print("upper bounds:")
  print(histogram.fragments.map { $0[1] })
  print("histogram:")
  print(histogram.radialDensity)
  print("atomic radius:")
  print(histogram.atomicRadius)
  print()
  
  var csv: String = ""
  csv.append("Radius, Radial Density, Atomic Radius, Z\n")
  for i in histogram.fragments.indices {
    let range = histogram.fragments[i]
    let r = (range[0] + range[1]) / 2
    let Dr = histogram.radialDensity[i]
    
    if i == 0 {
      csv += "\(r), \(Dr), \(histogram.atomicRadius), \(Z)\n"
    } else {
      csv += "\(r), \(Dr)\n"
    }
  }
  
  print()
  print(csv)
  
  exit(0)
}

// MARK: - Hydrogen Wave Function

func laguerrePolynomial(
  alpha: Float, n: Int
) -> (_ x: Float) -> Float {
  if n == 0 {
    return { _ in 1 }
  } else if n > 0 {
    return { x in
      var secondLast: Float = 1
      var last: Float = 1 + alpha - x
      
      for k in 1..<n {
        let coeffLeft = Float(2 * k + 1) + alpha - x
        let coeffRight = -(Float(k) + alpha)
        let numerator = coeffLeft * last + coeffRight * secondLast
        let denominator = Float(k + 1)
        secondLast = last
        last = numerator / denominator
      }
      return last
    }
  }
  
  fatalError("Unsupported value for n.")
}

func cubicHarmonic(
  l: Int, m: Int
) -> (_ x: Float, _ y: Float, _ z: Float, _ r: Float) -> Float {
  var factorial: Int = 1
  for i in 0...l {
    factorial *= (i * 2 + 1)
  }
  let Nc = (Float(factorial) / (4 * Float.pi)).squareRoot()
  
  if l == 0 {
    return { _, _, _, _ in
      var output = Nc
      switch m {
      case 0: output *= 1
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 1 {
    return { x, y, z, r in
      var output = Nc / r
      switch m {
      case 0: output *= z
      case -1: output *= x
      case 1: output *= y
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 2 {
    return { x, y, z, r in
      var output = Nc / (r * r)
      switch m {
      case 0: output *= (3 * z * z - r * r) / (2 * Float(3).squareRoot())
      case -1: output *= x * z
      case 1: output *= y * z
      case -2: output *= x * y
      case 2: output *= (x * x - y * y) / 2
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 3 {
    return { x, y, z, r in
      var output = Nc / (r * r * r)
      switch m {
      case 0:
        output *= z * (2 * z * z - 3 * x * x - 3 * y * y)
        output /= 2 * Float(15).squareRoot()
      case -1:
        output *= x * (4 * z * z - x * x - y * y)
        output /= 2 * Float(10).squareRoot()
      case 1:
        output *= y * (4 * z * z - x * x - y * y)
        output /= 2 * Float(10).squareRoot()
      case -2:
        output *= x * y * z
      case 2:
        output *= z * (x * x - y * y) / 2
      case -3:
        output *= x * (x * x - 3 * y * y)
        output /= 2 * Float(6).squareRoot()
      case 3:
        output *= y * (3 * x * x - y * y)
        output /= 2 * Float(6).squareRoot()
      default:
        fatalError("Invalid value for m.")
      }
      return output
    }
  }
  
  fatalError("Unsupported value for l.")
}

func factorial(_ x: Int) -> Int {
  guard x >= 0 else {
    fatalError("Cannot take factorial of negative number.")
  }
  if x == 0 {
    return 1
  } else {
    var output = x
    var counter = x - 1
    while counter > 0 {
      output *= counter
      counter -= 1
    }
    return output
  }
}

struct QuantumNumbers {
  var n: Int
  var l: Int
  var m: Int
}

func hydrogenWaveFunction(
  Z: Float,
  numbers: QuantumNumbers,
  position: SIMD3<Float>
) -> Float {
  let R = { (r: Float) -> Float in
    let numerator = factorial(numbers.n - numbers.l - 1)
    let denominator = 2 * numbers.n * factorial(numbers.n + numbers.l)
    var normalizationFactor = Float(numerator) / Float(denominator)
    
    let shellPart = Float(2 * Z) / Float(numbers.n)
    normalizationFactor *= shellPart * shellPart * shellPart
    normalizationFactor.formSquareRoot()
    
    let shellRadiusPart = shellPart * r
    let L = laguerrePolynomial(
      alpha: Float(2 * numbers.l + 1),
      n: numbers.n - numbers.l - 1)
    
    return normalizationFactor
    * exp(-shellRadiusPart / 2)
    * pow(shellRadiusPart, Float(numbers.l))
    * L(shellRadiusPart)
  }
  
  let r = (position * position).sum().squareRoot()
  let Y = cubicHarmonic(l: numbers.l, m: numbers.m)
  let magnitude = R(r) * Y(position.x, position.y, position.z, r)
  let parity = pow(-1, Float(numbers.l))
  return parity * magnitude
}

// MARK: - Ansatz

func createShellOccupations(Z: Int) -> [Int] {
  // Output is zero-indexed, starting with the nonexistent zero shell. It spans
  // from n=0 to n=7.
  var shellOccupations = [Int](repeating: 0, count: 1 + 7)
  
  var cursorZ: Int = 0
  func subShell(n: Int, occupancy: Int) {
    if Z > cursorZ {
      shellOccupations[n] += min(Z - cursorZ, occupancy)
    }
    cursorZ += occupancy
  }
  
  // First period.
  subShell(n: 1, occupancy: 2)
  
  // Second period.
  subShell(n: 2, occupancy: 2)
  subShell(n: 2, occupancy: 6)
  
  // Third period.
  subShell(n: 3, occupancy: 2)
  subShell(n: 3, occupancy: 6)
  
  // Fourth period.
  subShell(n: 4, occupancy: 2)
  subShell(n: 3, occupancy: 10)
  subShell(n: 4, occupancy: 6)
  
  // Fifth period.
  subShell(n: 5, occupancy: 2)
  subShell(n: 4, occupancy: 10)
  subShell(n: 5, occupancy: 6)
  
  // Sixth period.
  subShell(n: 6, occupancy: 2)
  subShell(n: 4, occupancy: 14)
  subShell(n: 5, occupancy: 10)
  subShell(n: 6, occupancy: 6)
  
  // Seventh period.
  subShell(n: 7, occupancy: 2)
  subShell(n: 5, occupancy: 14)
  subShell(n: 6, occupancy: 10)
  subShell(n: 7, occupancy: 6)
  
  // Eighth period.
  if Z > 118 {
    fatalError("Eighth period elements are not supported.")
  }
  
  return shellOccupations
}

// Returns the effective charge for each electron shell.
func createEffectiveCharges(Z: Int, occupations: [Int]) -> [Float] {
// var correction = Float(n) * Float(n) / Float(Zeff)
// correction = correction.squareRoot()
// var normalization = correction * correction * correction
// normalization = normalization.squareRoot()
   
  var coreCharge = Z
  var effectiveCharges: [Float] = []
  for occupation in occupations {
    effectiveCharges.append(Float(coreCharge))
    coreCharge -= occupation
  }
  
  // Algorithm:
  // - break up the effective charge into different components
  // - fully shielded (0)
  // - partially shielded (sqrt(Z))
  // - not shielded (Z)
  for i in effectiveCharges.indices {
    var valenceCharge = Float(occupations[i])
    var coreCharge = effectiveCharges[i] - valenceCharge
    valenceCharge.formSquareRoot()
    print("\(effectiveCharges[i]) -> \(valenceCharge + coreCharge)")
    effectiveCharges[i] = valenceCharge + coreCharge
  }
  
  return effectiveCharges
}

struct Histogram {
  var fragments: [SIMD2<Float>] = []
  var radialDensity: [Float] = []
  var atomicRadius: Float = .zero
  
  init(Z: Int) {
    let occupations = createShellOccupations(Z: Z)
    let effectiveCharges = createEffectiveCharges(
      Z: Z, occupations: occupations)
    
    var overallHistogramRanges: [Range<Float>]?
    var overallHistogramSum: [Float]?
    
    for n in occupations.indices where occupations[n] > 0 {
      let quantumNumbers = QuantumNumbers(n: n, l: 0, m: 0)
      var correction = Float(n)
      var normalization = correction * correction * correction
      normalization = normalization.squareRoot()
      
      func probability(range: Range<Float>) -> Float {
        let r = (range.lowerBound + range.upperBound) / 2
        let waveFunction = hydrogenWaveFunction(
          Z: effectiveCharges[n],
          numbers: quantumNumbers,
          position: SIMD3(r * correction, 0, 0)) * normalization
        
        let D = { (r: Float) -> Float in
          4 * Float.pi * r * r * (waveFunction * waveFunction)
        }
        let dr = range.upperBound - range.lowerBound
        return D(r) * dr
      }
      
      struct OrbitalFragment {
        var range: Range<Float>
        var probability: Float
      }
      func createFragment(range: Range<Float>) -> OrbitalFragment {
        let probability = probability(range: range)
        let fragment = OrbitalFragment(range: range, probability: probability)
        return fragment
      }
      
      var fragments: [OrbitalFragment] = []
      for power10 in -4..<2 { // 1e-4 to 1e2
        var ranges: [Range<Float>] = []
        for i in 0..<20 {
          let lowerBound = Float.pow(10, Float(i) / 20)
          let upperBound = Float.pow(10, Float(i + 1) / 20)
          ranges.append(lowerBound..<upperBound)
        }
        
        let scaleFactor = Float.pow(10, Float(power10))
        for range in ranges {
          let lowerBound = range.lowerBound * scaleFactor
          let upperBound = range.upperBound * scaleFactor
          fragments.append(createFragment(range: lowerBound..<upperBound))
        }
      }
      let histogramRanges = fragments.map(\.range)
      
      func normalize(_ fragments: [OrbitalFragment]) -> [OrbitalFragment] {
        var sum: Double = .zero
        for fragment in fragments {
          sum += Double(fragment.probability)
        }
        let normalizationFactor = 1 / Float(sum)
        return fragments.map {
          OrbitalFragment(
            range: $0.range,
            probability: $0.probability * normalizationFactor)
        }
      }
      var firstFragment = fragments.removeFirst()
      while fragments.count > 0 {
        let secondFragment = fragments.first!
        if firstFragment.probability + secondFragment.probability > 1e-6 {
          break
        } else {
          let lowerBound = firstFragment.range.lowerBound
          let upperBound = secondFragment.range.upperBound
          firstFragment = OrbitalFragment(
            range: lowerBound..<upperBound,
            probability: firstFragment.probability + secondFragment.probability)
          fragments.removeFirst()
        }
      }
      fragments = [firstFragment] + fragments
      fragments = normalize(fragments)
      
      var converged = false
      for _ in 0..<20 {
        var newFragments: [OrbitalFragment] = []
        for fragment in fragments {
          if fragment.probability > 1e-3 {
            let lowerBound = fragment.range.lowerBound
            let upperBound = fragment.range.upperBound
            let midPoint = (lowerBound + upperBound) / 2
            newFragments.append(createFragment(range: lowerBound..<midPoint))
            newFragments.append(createFragment(range: midPoint..<upperBound))
          } else {
            newFragments.append(createFragment(range: fragment.range))
          }
        }
        newFragments = normalize(newFragments)
        let addedCount = newFragments.count - fragments.count
        fragments = newFragments
        
        if addedCount == 0 {
          converged = true
          break
        }
      }
      guard converged else {
        fatalError("Orbital fragmentation failed to converge.")
      }
      
      print()
      print("n = \(n)")
      print("upper bounds:")
      print(histogramRanges.map { $0.upperBound })
      print("histogram:")
      var histogram = [Float](repeating: 0, count: histogramRanges.count)
      for fragment in fragments {
        var center = fragment.range.lowerBound + fragment.range.upperBound
        center /= 2
        
        for (i, range) in histogramRanges.enumerated() {
          if range.contains(center) {
            histogram[i] += fragment.probability
          }
        }
      }
      atomicRadius = .zero
      for i in histogram.indices {
        // convert one-electron absolute probability to
        // one-electron probability density
        let range = histogramRanges[i]
        let dr = range.upperBound - range.lowerBound
        let probability = histogram[i]
        let Dr = probability / dr
        histogram[i] = Dr
        
        let r = (range.lowerBound + range.upperBound) / 2
        atomicRadius += probability * r
      }
      print(histogram)
      
      // convert from one-electron probability density to
      // multi-electron probability density
      if overallHistogramRanges == nil {
        overallHistogramRanges = histogramRanges
        overallHistogramSum = histogram.map { $0 * 0 }
      }
      let multiplier = Float(occupations[n])
      for i in histogram.indices {
        overallHistogramSum![i] += multiplier * histogram[i]
      }
    }
    
    guard let overallHistogramRanges,
          let overallHistogramSum else {
      fatalError("This should never happen.")
    }
    for range in overallHistogramRanges {
      fragments.append(SIMD2(range.lowerBound, range.upperBound))
    }
    for sum in overallHistogramSum {
      radialDensity.append(sum)
    }
  }
}
