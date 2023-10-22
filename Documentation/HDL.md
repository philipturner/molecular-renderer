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
Contour(Float) { [SIMD4<Float>] }
```

Creates a contour with the provided spacing between the entered atoms. This is typically used to auto-generate complementary vdW interfaces, an otherwise time-consuming task. The entered atoms must be in nanometers.

> WARNING: The spacing is in number of lattice cells, not nanometers. To create a spacing based on hydrogen vdW radius, first fetch the value of the lattice constant. Divide the spacing in nanometers by the lattice constant.

```swift
Cut()
```

Replaces the selected volume with nothing. This must be called inside a `Volume`.

```swift
Replace { Bond }
Replace { Element }
Replace { [Element] }
```

Replace the highlighted "zero" volume with an element, connector, or polyatomic crystal lattice.

```swift
Origin { Vector }
```

Translates the origin by a vector relative to the current origin. The origin will reset when you exit the current scope.

```swift
Plane { Vector }
```

Adds a plane to the stack. The plane will be combined with other planes, and used for selecting/deleting atoms. This must be called inside a `Volume`.

A `Plane` divides the `Bounds` into two sections. The "zero" volume is the side the normal vector points toward. The "one" volume is the side the normal points away from. The "zero" volume contains the atoms deleted during a `Cut()`. When planes combine into a `Concave`, only the crystal unit cells common to every plane's "zero" volume are deleted.

```swift
Ridge(Vector) { Vector }
Valley(Vector) { Vector }
```

Creates two planes by reflecting the first argument `(Vector)` across the second argument `{ Vector }`. `Ridge` takes the intersection of the planes' "one" volumes, while `Valley` takes the union. This must be called inside a `Volume`.

### Objects

```swift
Amorphous: Basis
Cubic: Basis
Hexagonal: Basis
```

Coordinate spaces for defining vectors in.

```swift
Bounds { Vector }
```

Sets the working set of crystal unit cells. The box spans from the current origin (set by `Origin`) to the origin plus the specified vector. This must be called in the top-level scope, and may not be called after an `Affine` or `Copy`.

| Basis | Use | Units |
| ----- | --- | ----- |
| Amorphous[^1] | defining positions of solids | nanometers |
| Cubic | editing cubic lattices | multiples of crystal unit cell width |
| Hexagonal | editing hexagonal lattices | multiples of crystal unit cell width |

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

Create a lattice of crystal unit cells to carve. Coordinates are represented in numbers of crystal unit cells.

```swift
Material { Element }
Material { [Element] }
```

Specifiies the atom types to fill the lattice with, and the lattice constant. This must be called in the top-level scope, and may not be called after an `Affine` or `Copy`.

```swift
RigidBody
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
Convex { 

}
```

Scope where every plane's "zero" volume merges through OR in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Concave {

}
```

Scope where every plane's "zero" volume merges through AND in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Volume {

}
```

Encapsulates a set of planes, so that everything inside the scope is removed from the stack upon exiting. This may not be called inside `Affine`, but may be called inside another `Volume`.

### Solid Editing

```swift
Copy { Lattice<Basis> }
Copy { Solid }
Copy { [SIMD4<Float>] }
```

Instantiates a previously designed object. If called inside an `Affine`, the instance's atoms may be rotated or translated. This may be called either inside an `Affine`, or at the top-level scope of a `Lattice` or `Solid`.

The array initializer accepts raw atom positions in the existing coordinate space (distance in crystal unit cells for `Lattice`, nanometers for `Solid`). Atoms do not need to perfectly align with the lattice, but must fall within a tight margin of floating-point error (`<0.1%`).

```swift
Reflect { Vector }
```

Reflects the object across the current origin, along the specified axis. This must be called inside an `Affine`.

```swift
Rotate { Vector }
```

Rotates counterclockwise around the vector by `length(vector)` revolutions. For example, scale the vector by 0.25 to rotate 90 degrees. This must be called inside an `Affine`.

Rotation occurs around a ray starting at the current origin, and pointing toward the specified vector. When in a lattice, the rotation angle must be a multiple of 1/4 or 1/6 revolutions. 0.166, 0.167, 0.333, etc. are automatically recognized as 1/6, 1/3, etc.

```swift
Translate { Vector }
```

Translate the object by the specified vector, relative to its current position. This must be called inside an `Affine`.

### Vectors

```swift
// Lattice vectors originate from the smallest repeatable unit of crystal. For
// cubic crystals, they are edges of a cube. For hexagonal crystals, they are
// sides of a hexagonal prism. The vectors aren't always orthogonal, so they are
// internally translated to nanometers before applying affine transforms.
//
// Hexagonal crystals are sometimes described with four unit vectors: h, k, i,
// and l. The 'i' vector is redundant and equals -h - k, creating a set of 3
// vectors symmetric around the perimeter of a hexagon. In the HDL, you
// must use (-h - k) to represent the 'i' vector.

Hexagonal.h: Vector<Hexagonal> = [1, 0, 0] * hexagon side length
Hexagonal.k: Vector<Hexagonal> = [-0.5, 0.866, 0] * hexagon side length
Hexagonal.l: Vector<Hexagonal> = [0, 0, 1] * hexagonal prism depth
Cubic.h: Vector<Cubic> = [1, 0, 0] * lattice spacing
Cubic.k: Vector<Cubic> = [0, 1, 0] * lattice spacing
Cubic.l: Vector<Cubic> = [0, 0, 1] * lattice spacing
Amorphous.x: Vector<Amorphous> = [1, 0, 0] * nanometer
Amorphous.y: Vector<Amorphous> = [0, 1, 0] * nanometer
Amorphous.z: Vector<Amorphous> = [0, 0, 1] * nanometer
```

Unit vectors representing the crystal's basis.

```swift
Cubic.squareSideLength(material:)
Hexagonal.hexagonSideLength(material:)
Hexagonal.prismHeight(material:)
```

Values of the lattice constants, for use in `Solid`. Currently, the `material` argument only accepts a single element. Future versions may accept multiple elements, for materials like moissanite.

```swift
prefix operator + (Vector<Basis>) -> Vector<Basis>
prefix operator - (Vector<Basis>) -> Vector<Basis>

// Examples
-h, +k, +l // cubic
+a, -b, +c // hexagonal
```

`-` makes a `Vector` point in the opposite direction (reflects across the origin). `+` explicitly denotes that an axis vector is positive.

```swift
infix operator * (Float, Vector<Basis>) -> Vector<Basis>
infix operator * (Vector<Basis>, Float) -> Vector<Basis>

// Examples
6 * h, -7 * k, -9.75 * l
a * -2.25, -8.5 * b, c * 1.0
```

Scales a `Vector` by a constant.

```swift
infix operator + (Vector<Basis>, Vector<Basis>) -> Vector<Basis>
infix operator - (Vector<Basis>, Vector<Basis>) -> Vector<Basis>

// Examples
6 * h - 7 * k - 9.75 * l
a * -2.25 + -8.5 * b + c * 1.0
```

Adds or subtracts two vectors.

[^1]: Right now, cubic lattices and solids require vectors in the `Cubic` basis (`h`, `k`, `l`). The carbon centers can be extracted using `_centers`, in units of diamond cell width. You must multiply them by `0.357` to get nanometers. This API will be fixed in the future, so don't count on code written now being source-stable.

## Tips

List:
- Compile the Swift code in release mode with incremental compilation.
- Split into multiple files, decreasing the chance the compiler will take a long time compiling any one file.
