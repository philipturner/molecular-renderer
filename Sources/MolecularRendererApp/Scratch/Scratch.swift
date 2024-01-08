// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Unit tests:
// - Get MM4ForceField to the point it can selectively generate parameters. ✅
//   - Disable torsions, hydrogen reductions, and bend-bend forces in the Swift
//     file for 'NCFPart'. ✅
//   - Verify that parameter generation time decreases and the parameters for
//     certain forces are removed. ✅
// - Get MM4ForceField to the point it can produce single-point energies.
//   - Don't worry about optimizing the 'MM4Force' objects to skip
//     initialization or GPU computation; just make them have zero effect.
// - Check the correctness of nonbonded forces w/ hydrogen reductions, making
//   vdW the first correctly functioning force reported on the README.
//   - Compare the instantaneous forces computed from TopologyMinimizer and
//     MM4ForceField without hydrogen reductions.
//   - Evaluate the equilibrium distance with TopologyMinimizer, predict how
//     much hydrogen reductions will shift it.
//   - Run the nonbonded force from MM4ForceField and verify the shift
//     matches TopologyMinimizer.
// - Create the first unit test: a single force evaluation on 'NCFMechanism'.
//   - Only embed vector literals for the 1st part, even in the 2-part system.
//   - Hard-code the expected values of 1 part vs. 2 parts. Create an assertion
//     that in the latter case, values are much greater.
//   - Hard-code the expected values for the 2-part system before and after
//     enabling hydrogen reductions.
// - Test how much the structure shifts when energy-minimized, just simulating
//   a single 'NCFPart'.
//   - The shift ought to be small, but nonzero, resulting in a quick test.
//   - Start with single-point forces, comparing to TopologyMinimizer.
//   - Get MM4ForceField to the point it can do energy minimizations.
//   - Analyze the difference between compiled and minimized structures. Also,
//     the difference between TopologyMinimizer (harmonic angle, no hydrogen
//     reduction) and MM4ForceField (sextic angle, hydrogen reduction).
//   - Measure execution time of the energy minimization, then add a unit test.

func createNCFMechanism() -> [[Entity]] {
//  let mechanism = NCFMechanism(partCount: 2)
//  return NCFMechanism.createEntities(
//    mechanism.parts.map(\.rigidBody))
  
  var output: [[Entity]] = []
  for _ in 0..<10 {
    output += NCFMechanism.simulationExperiment5()
  }
  return output
}

extension NCFMechanism {
  // Solve a cubic equation and debug the results.
  static func simulationExperiment6() {
    // Record the expected cube roots, so you can unit test them later.
    
    // MARK: - Unit Test 0
    
     let coefficients: SIMD4<Double> = [1, -6, 11, -6]
//  roots: SIMD2<Double>(1.0, -1.1102230246251565e-16) SIMD2<Double>(3.0, -1.1102230246251565e-16) SIMD2<Double>(2.0, 7.401487051415874e-17)
//  1.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^3 + -6.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^2 + 11.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^1 + -6.0 = SIMD2<Double>(0.0, -2.220446049250313e-16)
//  1.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^3 + -6.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^2 + 11.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^1 + -6.0 = SIMD2<Double>(0.0, -2.220446049250313e-16)
//  1.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^3 + -6.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^2 + 11.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^1 + -6.0 = SIMD2<Double>(0.0, -7.40148683083439e-17)
    
    // MARK: - Unit Test 1
    
//    let coefficients: SIMD4<Double> = [1, 1, 7, 2]
//  roots: SIMD2<Double>(-0.2944532632827759, -0.0) SIMD2<Double>(-0.35277336835861206, -2.5822083950042725) SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)
//  1.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^3 + 1.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^2 + 7.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^1 + 2.0 = SIMD2<Double>(9.818534874028728e-16, 0.0)
//  1.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^3 + 1.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^2 + 7.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^1 + 2.0 = SIMD2<Double>(2.6645352591003757e-15, 0.0)
//  1.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^3 + 1.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^2 + 7.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^1 + 2.0 = SIMD2<Double>(5.329070518200751e-15, 7.105427357601002e-15)
    
    // MARK: - Unit Test 2
    
//     let coefficients: SIMD4<Double> = [-1.0, 220458.03662109375, -12580728532.801353, 47331747116183.29]
//  roots: SIMD2<Double>(109983.7421875, 9.701277108031814e-12) SIMD2<Double>(4043.4931640625, 0.0) SIMD2<Double>(106430.8046875, -4.850638554015907e-12)
//  -1.0 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^3 + 220458.03662109375 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^2 + -12580728532.801353 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^1 + 47331747116183.29 = SIMD2<Double>(-0.25, -0.003651555197887457)
//  -1.0 * SIMD2<Double>(4043.4931640625, 0.0)^3 + 220458.03662109375 * SIMD2<Double>(4043.4931640625, 0.0)^2 + -12580728532.801353 * SIMD2<Double>(4043.4931640625, 0.0)^1 + 47331747116183.29 = SIMD2<Double>(0.0529022216796875, 0.0)
//  -1.0 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^3 + 220458.03662109375 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^2 + -12580728532.801353 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^1 + 47331747116183.29 = SIMD2<Double>(-0.25, -0.0017645461032371745)
    
    // MARK: - Experiment 6
    
    let roots = NCFMechanism.solveCubicEquation(coefficients: coefficients, debugResults: true)
    print()
    print("roots: \(SIMD2<Double>(SIMD2<Float>(roots.0))) \(SIMD2<Double>(SIMD2<Float>(roots.1))) \(SIMD2<Double>(SIMD2<Float>(roots.2)))")
    
    for root in [roots.0, roots.1, roots.2] {
      let rootRounded = SIMD2<Double>(SIMD2<Float>(root))
      var output = ""
      output += "\(coefficients[0]) * \(rootRounded)^3 + "
      output += "\(coefficients[1]) * \(rootRounded)^2 + "
      output += "\(coefficients[2]) * \(rootRounded)^1 + "
      output += "\(coefficients[3]) = "
      
      let root0 = SIMD2<Double>(1, 0)
      let root1 = root
      let root2 = NCFMechanism.complexMultiply(root1, root1)
      let root3 = NCFMechanism.complexMultiply(root2, root1)
      
      var rhs: SIMD2<Double> = .zero
      rhs += coefficients[3] * root0
      rhs += coefficients[2] * root1
      rhs += coefficients[1] * root2
      rhs += coefficients[0] * root3
      print(output + "\(rhs)")
    }
  }
  
  @_transparent
  static func complexMultiply(
    _ lhs: SIMD2<Double>, _ rhs: SIMD2<Double>
  ) -> SIMD2<Double> {
    // (a + bi)(c + di) = (ac - bd) + (bc + ad)i
    let (a, b, c, d) = (lhs[0], lhs[1], rhs[0], rhs[1])
    return SIMD2(a * c - b * d, b * c + a * d)
  }
  
  // Source: https://en.wikipedia.org/wiki/Cubic_equation#General_cubic_formula
  static func solveCubicEquation(
    coefficients: SIMD4<Double>, debugResults: Bool = false
  ) -> (SIMD2<Double>, SIMD2<Double>, SIMD2<Double>) {
    let a = coefficients[0]
    let b = coefficients[1]
    let c = coefficients[2]
    let d = coefficients[3]
    
    let Δ0 = b * b - 3 * a * c
    let Δ1 = 2 * b * b * b - 9 * a * b * c + 27 * a * a * d
    if debugResults {
      print("Δ0: \(Δ0)")
      print("Δ1: \(Δ1)")
    }
    
    // The square root term may be negative, producing an imaginary number.
    let squareRootTerm = Δ1 * Δ1 - 4 * Δ0 * Δ0 * Δ0
    let squareRootMagnitude = squareRootTerm.magnitude.squareRoot()
    var cubeRootTerm = SIMD2<Double>(Δ1, 0)
    if squareRootTerm < 0 {
      cubeRootTerm[1] = squareRootMagnitude
    } else {
      cubeRootTerm[0] += squareRootMagnitude
    }
    cubeRootTerm /= 2
    if debugResults {
      print("cube root term: \(cubeRootTerm[0]) \(cubeRootTerm[1])")
    }
    
    // The cube root term is a complex number. We need to separate it into
    // magnitude and phase on the complex plane.
    var cubeRootMagnitude = (cubeRootTerm * cubeRootTerm).sum().squareRoot()
    let cubeRootDirection = cubeRootTerm / cubeRootMagnitude
    var cubeRootPhase = atan2(cubeRootDirection.y, cubeRootDirection.x)
    if debugResults {
      print("cube root: \(Double(Float(cubeRootMagnitude))) \(Double(Float(cubeRootPhase)))")
      print("cube root direction: \(Double(Float(cubeRootDirection.x))) \(Double(Float(cubeRootDirection.y)))")
    }
    
    // Form the first of three cube roots.
    cubeRootMagnitude = cbrt(cubeRootMagnitude)
    cubeRootPhase /= 3
    func createCubeRootDirection(phase: Double) -> SIMD2<Double> {
      let cubeRootDirection = SIMD2(cos(phase), sin(phase))
      let cubeRoot = cubeRootDirection * cubeRootMagnitude
      if debugResults {
        print("cube root:")
        print("- magnitude=\(Double(Float(cubeRootMagnitude))) phase=\(Double(Float(phase)))")
        print("- direction \(Double(Float(cubeRootDirection.x))) \(Double(Float(cubeRootDirection.y)))")
        print("- value: \(SIMD2<Double>(SIMD2<Float>(cubeRoot)))")
      }
      return cubeRoot
    }
    let cubeRoot0 = createCubeRootDirection(phase: cubeRootPhase)
    let cubeRoot1 = createCubeRootDirection(phase: cubeRootPhase + 2 * .pi / 3)
    let cubeRoot2 = createCubeRootDirection(phase: cubeRootPhase + 4 * .pi / 3)
    
    // Primitive roots of unity are complex numbers.
//    let root0 = SIMD2<Double>(2, 0) / 2
//    let root1 = SIMD2<Double>(-1, 1.73205080757) / 2
//    let root2 = SIMD2<Double>(-1, -1.73205080757) / 2
    
    func x(k: Int) -> SIMD2<Double> {
      let cubeRoot: SIMD2<Double> = (k == 0) ? cubeRoot0 : (k == 1 ? cubeRoot1 : cubeRoot2)
      var output: SIMD2<Double> = .zero
      output += SIMD2(b, 0)
      output += cubeRoot
      
      let conjugate = SIMD2(cubeRoot[0], -cubeRoot[1])
      let denominator = NCFMechanism.complexMultiply(cubeRoot, conjugate)
      let reciprocal = conjugate / denominator[0]
      output += Double(Δ0) * reciprocal
      
      output /= Double(-3 * a)
      return output
    }
    
//    @_transparent
//    func x(k: Int) -> SIMD2<Double> {
////      let unityRoot = (k == 0) ? root0 : (k == 1 ? root1 : root2)
////      let εC = NCFMechanism.complexMultiply(unityRoot, cubeRootDirection)
//      let εC = (k == 0) ? cubeRootDirection0 : (k == 1 ? cubeRootDirection1 : cubeRootDirection2)
//      let εC_conj = SIMD2(εC[0], -εC[1])
//      let fracDenom = NCFMechanism.complexMultiply(εC, εC_conj)
//      
//      var x = b + εC + Δ0 * εC_conj / fracDenom.x
//      x /= -3 * a
//      
//      if debugResults {
//        print("root: \(Double(Float(x[0]))) + \(Double(Float(x[1])))i")
//      }
////      // Throw away the imaginary part of the root.
////      return x[0]
//      return x
//    }
    
    return (x(k: 0), x(k: 1), x(k: 2))
  }
  
  // This is still buggy, even after multiple attempts to understand what is
  // going on. I give up.
  static func gaussianElimination(
    matrix: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>),
    eigenValues: [Double]
  ) -> [SIMD3<Double>] {
    var output: [SIMD3<Double>] = []
    withUnsafeTemporaryAllocation(of: SIMD3<Double>.self, capacity: 3) { B in
      for k in 0..<3 {
        let eigenValue = eigenValues[k]
        B[0] = matrix.0
        B[1] = matrix.1
        B[2] = matrix.2
        B[0].x -= eigenValue
        B[1].y -= eigenValue
        B[2].z -= eigenValue
        
        print("B original: \(B[0][0]) \(B[1][0]) \(B[2][0])")
        print("            \(B[0][1]) \(B[1][1]) \(B[2][1])")
        print("            \(B[0][2]) \(B[1][2]) \(B[2][2])")
        
        /*
        for i in 0..<3 {
          for j in (i &+ 1)..<3 {
//            if B[j][i].magnitude > B[i][i].magnitude {
            if B[i][j].magnitude > B[i][i].magnitude {
              for l in 0..<3 {
//                swap(&B[i][l], &B[j][l])
                let temp = B[l][i]
                B[l][i] = B[l][j]
                B[l][j] = temp
              }
            }
          }
          for j in (i &+ 1)..<3 {
//            let multiplier = B[j][i] / B[i][i]
            let multiplier = B[i][j] / B[i][i]
            for l in 0..<3 {
//              B[j][l] -= multiplier * B[i][l]
              B[l][j] -= multiplier * B[l][i]
            }
          }
        }
         */
        
        // Something better than GPT-4, sourced from:
        // https://www.geeksforgeeks.org/gaussian-elimination/
        for k in 0..<3 {
          var i_max = k
          var v_max = B[k][i_max]
          
          for i in (k + 1)..<3 {
            if B[k][i] > v_max {
              v_max = B[k][i]
              i_max = i
            }
          }
          if B[i_max][k].magnitude < .leastNormalMagnitude {
            fatalError("Matrix is singular.")
          }
          
          if i_max != k {
            for columnID in 0..<3 {
              var temp1 = B[columnID][i_max]
              var temp2 = B[columnID][k]
              swap(&temp1, &temp2)
              B[columnID][i_max] = temp1
              B[columnID][k] = temp2
            }
          }
          for i in (k + 1)..<3 {
            let f = B[k][i] / B[k][k]
            
            // We end the loop at <3, not <=3 as shown in the source. We aren't
            // using an augmented matrix.
            for j in (k + 1)..<3 {
              B[j][i] -= B[j][k] * f
            }
            B[k][i] = 0
          }
        }
        
        print("B eliminated: \(B[0][0]) \(B[1][0]) \(B[2][0])")
        print("              \(B[0][1]) \(B[1][1]) \(B[2][1])")
        print("              \(B[0][2]) \(B[1][2]) \(B[2][2])")
        
        var eigenVector: SIMD3<Double> = .zero
        var i = 2
        while i >= 0 {
//          eigenVector[i] = B[i][2] / B[i][i]
          eigenVector[i] = B[2][i]
//          for j in 0..<i {
//            B[j][2] -= B[j][i] * eigenVector[i]
//            B[2][j] -= B[i][j] * eigenVector[i]
          for j in (i + 1)..<3 {
            eigenVector[i] -= B[j][i] * eigenVector[j]
          }
          eigenVector[i] /= B[i][i]
          i &-= 1
        }
        
        let eigenVectorLength = (eigenVector * eigenVector).sum().squareRoot()
        output.append(eigenVector / eigenVectorLength)
      }
    }
    return output
  }
}
