# Hardware Description Language

> This is not a prototype to something atomCAD will build. This is the final product, one component of a new full stack CAD workflow. It is not the only component, but an experiment that proved successful and generally useful.

Domain-specific language for accelerating nanomachine design workflows.
- This will enable the creation of a mechanical parts catalog covering several different categories. Each part will have Markdown documentation (when possible) and Swift APIs for instantiating parts/machines in larger assemblies. Heavy emphasis on making the parts <b>parametric</b>, so they can be used with a different material or dimension than originally conceived.
- The API will be geared toward those with <b>little to no Swift experience</b>. It will make minimal use of Swift's many examples of syntactic sugar. When possible, subsets of the HDL or hardware catalog's functionality will have bindings to alternative programming languages.
- The codebase will only depend on <b>cross-platform</b> Swift packages, even if Apple-specific libraries have higher performance.

Table of Contents
- [How it Works](#how-it-works)
    - [Atoms](#atoms)
    - [Simulation](#simulation)
    - [JIT Compiler](#jit-compiler)
- [Syntax](#syntax)
    - [Lattice Editing](#lattice-editing)
    - [Objects](#objects)
    - [Scopes](#scopes)
    - [Solid Editing](#solid-editing)
    - [Vectors](#vectors)
- [Tips](#tips)

## How it Works

At the atomic scale, constructive solid geometry is much easier than at the macroscale; there is no need to implicitly store shapes as equations. Instead, add or remove atoms from a grid held in computer memory. As the number of atoms can grow quite large, and many transformations can be applied, this approach can be computationally intensive. To achieve low latency, the compiler for translating the HDL (or UI actions) into geometry must be optimized for speed.

### Atoms

To enter raw atoms into the geometry at any point, the API accepts arrays of `SIMD4<Float>`. The first three vector components specify position. The fourth specifies atomic number (if positive) or bond order of a connector (if negative). 

### Simulation

The compiler supports all atom types in the MM4 simulator (H, C, N, O, F, Si, P, S, and Ge). Generated structures are intended to be used with MM4.

MM4 repository: [philipturner/MM4](https://github.com/philipturner/MM4)

MM4 documentation: [philipturner.github.io/MM4](https://philipturner.github.io/MM4)

### JIT Compiler

There is also a JIT compiler for the language, accepting a strict subset of Swift that contains DSL keywords. This was created out of necessity to bypass long compile times in Swift release mode. The API is still experimental and gated under an underscore (`_Parse`). Documentation can be found in triple-slashed comments at [Parse.swift](../Sources/HDL/Compiler/Parse.swift).

At the moment, the JIT compiler has been deprecated, in favor of compiling in Swift release mode with incremental compilation. It may be brought back for a future Python API.

## Syntax

### Lattice Editing

```swift
Basis
Cubic: Basis
Hexagonal: Basis
```

Coordinate spaces for defining vectors in.

```swift
Bounds { SIMD3<Float> }
```

Sets the working set of crystal unit cells. The box spans from the current origin (set by `Origin`) to the origin plus the specified vector. This must be called in the top-level scope, before any `Volume` keywords.

```swift
// Lattice vectors originate from the smallest repeatable unit of crystal. For
// cubic crystals, they are edges of a cube. For hexagonal crystals, they are
// sides of a hexagonal prism. The vectors aren't always orthogonal, so they are
// internally translated to nanometers before applying affine transforms.

// Hexagonal crystals are sometimes described with four unit vectors: h, k, i,
// and l. The 'i' vector is redundant and equals -h - k, creating a set of 3
// vectors symmetric around the perimeter of a hexagon. However, for the HDL, it
// can make representation more concise.
Lattice<Hexagonal> { h, k, l in
  // h + k + i == 0
  let i = -h - k
}

// Another helpful technique, which makes Hexagonal more similar to Cubic, is to
// replace 'k' with something orthogonal to 'h'. The coordinate basis has
// changed from h/k/l to h/h + 2k/l.
Lattice<Hexagonal> { h, k, l in
  // [3 * h, 2 * h2k, 2 * l] forms something close to a cube.
  let h2k = h + 2 * k
  Plane { -h }
  Plane { -h2k }
  Plane { -l }
  
  Origin { 3 * h + 2 * (h2k + l) }
  Plane { +h }
  Plane { +h2k }
  Plane { +l }
}
```

Unit vectors representing the crystal's basis.

```swift
Material { MaterialType }
```

Specifiies the atom types to fill the lattice with, and the lattice constant. This must be called in the top-level scope, and may not be called after an `Affine` or `Copy`.

```swift
Constant<Basis>(Basis.ConstantType) { MaterialType }
let latticeConstant = Constant<Cubic>(.square) { .elemental(.carbon) }

Cubic.ConstantType.square // square side length
Hexagonal.ConstantType.hexagon // hexagon side length
Hexagonal.ConstantType.prism // prism height
```

Values of the lattice constants, for use in `Solid`. This is a function that returns a `Float`.

```swift
Reconstruct { SIMD3<Float> }
```

Within the selected volume, reconstruct any surfaces that need reconstruction. This usually affects flat, open surfaces and avoids placing bonds in corners (which occurs at a later step of compilation). Bonds more parallel to the specified vector are prioritized, and the parity of alternating patterns is defined by `Origin`.

An exemplar surface that may be reconstructed is diamond (100).

### Volume Editing


```swift
Replace { EntityType }
Replace([EntityType]) { EntityType }
```

Replace instances of the first argument with the second argument. If the value in parentheses is unspecified, it defaults to all valid atoms and bond connectors. The replacement occurs in the "zero" volume of the current union of planes.

Instead of a dedicated keyword for cutting empty volumes, specify `Replace { .empty }`.

```swift
Origin { SIMD3<Float> }
```

Translates the origin by a vector relative to the current origin. The origin will reset when you exit the current scope.

```swift
Plane { SIMD3<Float> }
```

Adds a plane to the stack. The plane will be combined with other planes, and used for selecting/deleting atoms. This must be called inside a `Volume`.

A `Plane` divides the `Bounds` into two sections. The "zero" volume is the side the normal vector points toward. The "one" volume is the side the normal points away from. The "zero" volume contains the atoms deleted during a `Cut()`. When planes combine into a `Concave`, only the crystal unit cells common to every plane's "zero" volume are deleted.

> TODO: Change several parts of the code and documentation to reflect the "one" volume being used as the old "zero" volume.

```swift
Ridge(SIMD3<Float>) { SIMD3<Float> }
Valley(SIMD3<Float>) { SIMD3<Float> }
```

Creates two planes by reflecting the first argument across the second argument. `Ridge` takes the union of the planes' "one" volumes, while `Valley` takes the intersection. This must be called inside a `Volume`.

> This part of the documentation was already changed to match the swapped meanings of "one" and "zero" volumes.

### Objects

```swift
Lattice<Basis> { h, k, l in
  Material { ... }
  Bounds { ... }
}
Lattice<Basis> { h, k, l in
  Copy { Lattice<Basis> }
}
Lattice<Basis> { h, k, l in
  Affine {
    Copy { Lattice<Basis> }
  }
}
```

Create a lattice of crystal unit cells to edit. Coordinates are represented in numbers of crystal unit cells.

```swift
RigidBody { Lattice<Basis> }
RigidBody { Solid }
RigidBody { [Entity] }
```

Exposes the functionality from [Diamondoid](../Sources/MolecularRendererApp/Scenes/Procedural Geometry/Diamondoid.swift). Documentation for this API is in progress.

```swift
Solid { x, y, z in
  Copy { Lattice<Basis> }
}
Solid { x, y, z in
  Copy { Solid }
}
```

Create a solid object composed of multiple lattices or other solids. Converts coordinates inside a crystal unit cell to nanometers.

### Scopes

```swift
Affine {
  Copy { ... }
}
```

Starts a section that instantiates a previously designed object, then rotates or translates it. This may not be called inside a `Volume` or another `Affine`.

```swift
Convex { }
```

Scope where every plane's "zero" volume merges through OR in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Concave { }
```

Scope where every plane's "zero" volume merges through AND in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Volume { }
```

Encapsulates a set of planes, so that everything inside the scope is removed from the stack upon exiting. This may not be called inside `Affine`, but may be called inside another `Volume`.

This is permitted inside both a `Lattice` and a `Solid`.

### Solid Editing

```swift
Copy { Lattice<Basis> }
Copy { Solid }
Copy { [Entity] }
```

Instantiates a previously designed object. If called inside an `Affine`, the instance's atoms may be rotated or translated. This may be called either inside an `Affine`, or at the top-level scope of a `Lattice` or `Solid`.

The array initializer accepts raw atom positions in the existing coordinate space (distance in crystal unit cells for `Lattice`, nanometers for `Solid`). Atoms do not need to perfectly align with the lattice, but must fall within a tight margin of floating-point error (`<0.1%`).

```swift
Reflect { SIMD3<Float> }
```

Reflects the object across the current origin, along the specified axis. This must be called inside an `Affine`.

```swift
Rotate { SIMD3<Float> }
```

Rotates counterclockwise around the vector by `length(vector)` revolutions. For example, scale the vector by 0.25 to rotate 90 degrees. This must be called inside an `Affine`.

Rotation occurs around a ray starting at the current origin, and pointing toward the specified vector. When in a lattice, the rotation angle must be a multiple of 1/4 or 1/6 revolutions. 0.166, 0.167, 0.333, etc. are automatically recognized as 1/6, 1/3, etc.

```swift
Translate { SIMD3<Float> }
```

Translate the object by the specified vector, relative to its current position. This must be called inside an `Affine`.

## Tips

List:
- Compile the Swift code in release mode with incremental compilation.
- Split into multiple files, decreasing the chance the compiler will take a long time compiling any one file.
