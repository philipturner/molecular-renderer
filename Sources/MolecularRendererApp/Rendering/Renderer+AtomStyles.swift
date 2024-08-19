//
//  Renderer+AtomStyles.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/18/24.
//

import MolecularRenderer

extension Renderer {
  static func createColors() -> [SIMD3<Float>] {
    // Neutronium to argon: copied verbatim from NanoEngineer.
    //
    // The noble gases (Z=2, Z=10, Z=18, Z=36) and transition metals (Z=21-30)
    // are not properly parameterized by NanoEngineer. Use the commented-out
    // colors from QuteMol for these:
    // https://github.com/zulman/qutemol/blob/master/src/AtomColor.cpp#L54
    var colors: [SIMD3<Float>] = [
      SIMD3(204,   0,   0), // 0
      SIMD3(199, 199, 199), // 1
      SIMD3(217, 255, 255), // 2
      
      SIMD3(  0, 128, 128), // 3
      SIMD3(250, 171, 255), // 4
      SIMD3( 51,  51, 150), // 5
      SIMD3( 99,  99,  99), // 6
      SIMD3( 31,  31,  99), // 7
      SIMD3(128,   0,   0), // 8
      SIMD3(  0,  99,  51), // 9
      SIMD3(179, 227, 245), // 10
      
      SIMD3(  0, 102, 102), // 11
      SIMD3(224, 153, 230), // 12
      SIMD3(128, 128, 255), // 13
      SIMD3( 41,  41,  41), // 14
      SIMD3( 84,  20, 128), // 15
      SIMD3(219, 150,   0), // 16
      SIMD3( 74,  99,   0), // 17
      SIMD3(128, 209, 227), // 18
      
      SIMD3(  0,  77,  77), // 19
      SIMD3(201, 140, 204), // 20
      SIMD3(230, 230, 230), // 21
      SIMD3(191, 194, 199), // 22
      SIMD3(166, 166, 171), // 23
      SIMD3(138, 153, 199), // 24
      SIMD3(156, 122, 199), // 25
      SIMD3(224, 102,  51), // 26
      SIMD3(240, 144, 160), // 27
      SIMD3( 80, 208,  80), // 28
      SIMD3(200, 128,  51), // 29
      SIMD3(106, 106, 130), // 30
      SIMD3(153, 153, 204), // 31
      SIMD3(102, 115,  26), // 32
      SIMD3(153,  66, 179), // 33
      SIMD3(199,  79,   0), // 34
      SIMD3(  0, 102,  77), // 35
      SIMD3( 92, 184, 209), // 36
    ]
    
    // Rubidium to indium: not parameterized.
    colors += Array(repeating: .zero, count: 50 - 36 - 1)
    
    // Tin: dull blue color.
    colors.append(SIMD3(102, 128, 128))
    
    // Antimony to platnium: not parameterized.
    colors += Array(repeating: .zero, count: 79 - 50 - 1)
    
    // Gold: yellow color.
    //
    // Use the exact definition for the color "metallic gold". This is a
    // physically correct simulation of the pure metal's color.
    // https://en.wikipedia.org/wiki/Gold_(color)
    colors.append(SIMD3(212, 175, 55))
    
    // Mercury to thallium: not parameterized.
    colors += Array(repeating: .zero, count: 82 - 79 - 1)
    
    // Lead: gray color.
    colors.append(SIMD3(87, 89, 97))
    
    // Convert from 8-bit integers to floating point numbers.
    colors = colors.map { $0 / 255 }
    
    return colors
  }
  
  static func createRadii() -> [Float] {
    // Neutronium to argon: copied verbatim from NanoEngineer.
    var radii: [Float] = [
      0.853, // 0
      0.930, // 1
      1.085, // 2
      
      3.100, // 3
      2.325, // 4
      1.550, // 5
      1.426, // 6
      1.201, // 7
      1.349, // 8
      1.279, // 9
      1.411, // 10
      
      3.100, // 11
      2.325, // 12
      1.938, // 13
      1.744, // 14
      1.635, // 15
      1.635, // 16
      1.573, // 17
      1.457, // 18
      
      3.875, // 19
      3.100, // 20
      2.868, // 21
      2.712, // 22
      2.558, // 23
      2.403, // 24
      2.325, // 25
      2.325, // 26
      2.325, // 27
      2.325, // 28
      2.325, // 29
      2.248, // 30
      2.093, // 31
      1.938, // 32
      1.705, // 33
      1.705, // 34
      1.662, // 35
      1.565, // 36
    ]
    
    // Rubidium to indium: not parameterized.
    radii += Array(repeating: 0, count: 50 - 36 - 1)
    
    // Tin: 2.2 Å radius.
    //
    // Extrapolating from the lattice constant ratio with germanium:
    // https://7id.xray.aps.anl.gov/calculators/crystal_lattice_parameters.html
    // 5.64613 (Ge) -> 6.48920 (Sn)
    // 1.938 (Ge) * 6.48920/5.64613 = 2.227 (Sn)
    radii.append(2.227)
    
    // Antimony to platinum: not parameterized.
    radii += Array(repeating: 0, count: 79 - 50 - 1)
    
    // Gold: 2.4 Å radius.
    //
    // ## Original Parameter
    //
    // Extrapolating from the lattice constant ratio with copper:
    // https://periodictable.com/Properties/A/LatticeConstants.html
    // 3.6149 (Cu) -> 4.0782 (Au)
    // 2.325 (Cu) * 4.0782/3.6149 = 2.623 (Au)
    //
    // ## Revised Parameter
    //
    // Changing to 2.371, to match the ratio of C-C (1.545 Å) and Au-C
    // (~2.057 Å) bond lengths. Makes the render look much more workable.
    radii.append(2.371)
    
    // Mercury to thallium: not parameterized.
    radii += Array(repeating: 0, count: 82 - 79 - 1)
    
    // Lead: 2.3 Å radius.
    //
    // Extrapolating from the covalent radius ratio with tin:
    // https://en.wikipedia.org/wiki/Covalent_radius#Average_radii
    // 1.39 (Sn) -> 1.46 (Pb)
    // 2.227 (Sn) * 1.46/1.39 = 2.339 (Pb)
    radii.append(2.339)
    
    // Convert from angstroms to meters.
    radii = radii.map { $0 * 1e-10 }
    
    // Convert from meters to nanometers.
    radii = radii.map { $0 * 1e9 }
    
    return radii
  }
  
  static func createAtomStyles() -> [MRAtomStyle] {
    let colors = Self.createColors()
    let radii = Self.createRadii()
    
    var output: [MRAtomStyle] = []
    for atomID in 0...82 {
      let color = colors[atomID]
      let radius = radii[atomID]
      let style = MRAtomStyle(
        color: SIMD3<Float16>(color), radius: Float16(radius))
      output.append(style)
    }
    return output
  }
}

#if false
private struct RendererStyle: MRAtomStyleProvider {
  var styles: [MRAtomStyle]
  
  var available: [Bool]
  
  init() {
    
    
    // The noble gases (Z=2, Z=10, Z=18, Z=36) and transition metals (Z=21-30)
    // are not properly parameterized by NanoEngineer. Use the commented-out
    // colors from QuteMol for these:
    // https://github.com/zulman/qutemol/blob/master/src/AtomColor.cpp#L54
    var colors: [SIMD3<Float>] = [
      SIMD3(204,   0,   0), // 0
      SIMD3(199, 199, 199), // 1
      SIMD3(217, 255, 255), // 2
      
      SIMD3(  0, 128, 128), // 3
      SIMD3(250, 171, 255), // 4
      SIMD3( 51,  51, 150), // 5
      SIMD3( 99,  99,  99), // 6
      SIMD3( 31,  31,  99), // 7
      SIMD3(128,   0,   0), // 8
      SIMD3(  0,  99,  51), // 9
      SIMD3(179, 227, 245), // 10
      
      SIMD3(  0, 102, 102), // 11
      SIMD3(224, 153, 230), // 12
      SIMD3(128, 128, 255), // 13
      SIMD3( 41,  41,  41), // 14
      SIMD3( 84,  20, 128), // 15
      SIMD3(219, 150,   0), // 16
      SIMD3( 74,  99,   0), // 17
      SIMD3(128, 209, 227), // 18
      
      SIMD3(  0,  77,  77), // 19
      SIMD3(201, 140, 204), // 20
      SIMD3(230, 230, 230), // 21
      SIMD3(191, 194, 199), // 22
      SIMD3(166, 166, 171), // 23
      SIMD3(138, 153, 199), // 24
      SIMD3(156, 122, 199), // 25
      SIMD3(224, 102,  51), // 26
      SIMD3(240, 144, 160), // 27
      SIMD3( 80, 208,  80), // 28
      SIMD3(200, 128,  51), // 29
      SIMD3(106, 106, 130), // 30
      SIMD3(153, 153, 204), // 31
      SIMD3(102, 115,  26), // 32
      SIMD3(153,  66, 179), // 33
      SIMD3(199,  79,   0), // 34
      SIMD3(  0, 102,  77), // 35
      SIMD3( 92, 184, 209), // 36
    ]
    
    colors += Array(repeating: .zero, count: 50 - 36 - 1)
    colors.append(SIMD3(102, 128, 128))
    
    // Use the exact definition for the color "metallic gold". This is a
    // physically correct simulation of the pure metal's color.
    // https://en.wikipedia.org/wiki/Gold_(color)
    colors += Array(repeating: .zero, count: 79 - 50 - 1)
    colors.append(SIMD3(212, 175, 55))
    
    colors += Array(repeating: .zero, count: 82 - 79 - 1)
    colors.append(SIMD3(87, 89, 97))
    
    radii = radii.map { $0 * 1e-10 }
    colors = colors.map { $0 / 255 }
    
    self.available = .init(repeating: false, count: 127)
    for i in 1...36 {
      self.available[i] = true
    }
    self.available[50] = true
    self.available[79] = true
    self.available[82] = true
    self.styles = []
    
  #if arch(x86_64)
    let atomColors: [SIMD3<Float16>] = []
  #else
    let atomColors = colors.map(SIMD3<Float16>.init)
  #endif
    let atomRadii = radii.map { $0 * 1e9 }.map(Float16.init)
    
    // colors:
    //   RGB color for each atom, ranging from 0 to 1 for each component.
    // radii:
    //   Enter all data in meters and Float32. They will be range-reduced to
    //   nanometers and converted to Float16.
    // available:
    //   Whether each element has a style. Anything without a style uses
    //   `radii[0]` and a black/magenta checkerboard pattern.
    self.styles = available.indices.map { i in
      let index = available[i] ? i : 0
      return MRAtomStyle(color: atomColors[index], radius: atomRadii[index])
    }
  }
}
#endif
