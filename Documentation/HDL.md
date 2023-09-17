# (Prototype) Hardware Description Language

This is a precursor to the eventual hardware description language that atomCAD will build. The purpose is to allow reasonably efficient workflows for designing crystolecules here and now. Potentially, it can utilize primitive editing capabilities from the atomCAD codebase, to complement the lack of a UI in MolecularRenderer.
- This will enable the creation of a mechanical parts catalog covering several different categories. Each part will have Markdown documentation (when possible) and Swift APIs for instantiating parts/machines in larger assemblies. Heavy emphasis on making the parts <b>parametric</b>, so they can be used with a different material or dimension than originally conceived.
- Emphasis on <b>a first-generation technology base</b>. The language lacks support for strained shell structures, as they require second-generation technology (but it will facilitate testing of machines for building them).
- Tutorials and well-maintained documentation will be provided, to onboard new engineers and provide the skills for making crystolecules. This will cover common pitfalls in design, such as actions that expose triply-unbonded carbon atoms, and good practices like reconstructing (100) surfaces.
- The API will be geared toward those with <b>little to no Swift experience</b>. It will make minimal use of Swift's many examples of syntactic sugar. When possible, subsets of the HDL or hardware catalog's functionality will have bindings to alternative programming languages.
- The codebase will only depend on <b>cross-platform</b> Swift packages, even if Apple-specific libraries have higher performance.

Table of Contents
- [How it Works](#how-it-works)
- [Design Hierarchy](#design-hierarchy)
- [Syntax](#syntax)
    - [Lattice Editing](#lattice-editing)
    - [Objects](#objects)
    - [Object Transforms](#object-transforms)
    - [Scopes](#scopes)
    - [Vectors](#vectors)

## How it Works

At the atomic scale, constructive solid geometry is much easier than at the macroscale; there is no need to implicitly store shapes as equations. Instead, add or remove atoms from a grid held in computer memory. As the number of atoms can grow quite large, and many transformations can be applied, this approach can be computationally heavy. To achieve low latency, the compiler for translating the HDL (or UI actions) into geometry must be optimized for speed. Part of the compiler is boolean masks over a grid on single-core CPU. Another part is surface energy minimizations on the GPU.

The forcefield is based on MM4, using an algorithm $O(n)$ in van der Waals attractions and $O(n^2)$ in electrostatic interactions. Avoid mixed-element materials like moissanite in bulk, although they are okay in small quantities. Crystolecules should have the bulk of atoms as elemental carbon, and surfaces terminated/passivated with polar covalent bonds. MM4 will be extended to the following elements:

| MM4 Atom Type | 6-ring | 5-ring | 4-ring | 3-ring |
| - | - | - | - | - |
| H        | 5  | n/a | n/a | n/a |
| B (sp3)  | 27 | 27  | not supported | not supported |
| C (sp3)  | 1  | 123 | not supported | not supported |
| N (sp3)  | 8  | 8   | not supported | not supported |
| O (sp3)  | 6  | 6   | not supported | not supported |
| F        | 11 | n/a | n/a | n/a |
| Si (sp3) | 19 | 19  | not supported | not supported |
| P (sp3)  | 25 | 25  | not supported | not supported |
| S (sp3)  | 15 | 15  | not supported | not supported |
| Cl       | 12 | n/a | n/a | n/a |
| Ge (sp3) | 31 | 31  | not supported | not supported |

Key:
- X = nonpolar covalent bond (low compute cost)
- O = polar covalent bond (high compute cost)
- blank means not supported

| Element | H | B | C | N | O | F | Si | P | S | Cl | Ge |
| ------- | - | - | - | - | - | - | - | - | - | - | - |
| H       |   | X | X | O | O |   | X | O | O |   | X |
| B       | X |   | O | O |   |   |   |   |   |   |   |
| C       | X | O | X | O | O | O | O | O | O | O | O |
| N       | O | O | O | X |   |   |   |   |   |   |   |
| O       | O |   | O |   |   |   |   |   |   |   |   |
| F       |   |   | O |   |   |   |   |   |   |   |   |
| Si      | X |   | O |   |   |   | X |   |   |   |   |
| P       | O |   | O |   |   |   |   |   |   |   |   |
| S       | O |   | O |   |   |   |   |   |   |   |   |
| Cl      |   |   | O |   |   |   |   |   |   |   |   |
| Ge      | X |   | O |   |   |   |   |   |   |   | X |

## Design Hierarchy

- `Assembly` (API not yet finalized)
  - `RigidBody` (API not yet finalized)
    - `Solid`
      - `Lattice<Basis>`
      - Slicing with planes
      - Automatically removing duplicated atoms from bounding volume intersections
      - Surface reconstruction
    - Connecting two different lattice types
    - Connecting with Kaehler brackets
  - Surface passivation
  - Surface energy minimization
  - Conservation of momentum
  - (Angular) position/velocity tracking during simulation
- Multiple discontinuous bodies interlocked in a productive nanosystem
- Avoid geometries that require welding

## Syntax

### Lattice Editing

```swift
Cut()
```

Replaces the selected volume with nothing.

```swift
Fill()
```

Replaces the selected volume with the crystal's base material.

```swift
Replace { Bond }
Replace { Element }
```

`Replace { Element }` replaces the selected atoms with the specified element. `Replace { Bond }` deletes the selected atoms and creates covalent bonds bridging their neighbors. Does not affect vacant crystal unit cells.

```swift
Passivate { Element }
```

Adds hydrogens or halogens to complete the valence shells of selected atoms. Does not affect vacant crystal unit cells.

```swift
Plane { Vector }
```

Adds a plane to the stack. The plane will be combined with other planes, and used for selecting/deleting atoms.

A `Plane` divides the `Bounds` into two sections. The "zero" volume is the side the normal vector points toward. The "one" volume is the side the normal points away from. The "zero" volume contains the atoms deleted during a `Cut()`. When planes combine into a `Concave`, only the crystal unit cells common to every plane's "zero" volume are deleted.

```swift
Ridge(Vector) { Vector }
Valley(Vector) { Vector }
```

Creates two planes by reflecting the first argument `(Vector)` across the second argument `{ Vector }`. `Ridge` takes the intersection of the planes' "one" volumes, while `Valley` takes the union.

### Objects

```swift
Amorphous: Basis
Cubic: Basis
Hexagonal: Basis
```

Coordinate spaces for defining vectors in.

| Basis | Use | Units |
| ----- | --- | ----- |
| Amorphous[^1] | defining positions of solids | nanometers |
| Cubic | editing cubic lattices | multiples of crystal unit cell width |
| Hexagonal | editing hexagonal lattices | multiples of crystal unit cell width |

```swift
Lattice<Basis> { 
  Material { ... }
  Bounds { ... }
}
Lattice<Basis> {
  Copy { Lattice<Basis> }
}
Lattice<Basis> {
  Affine {
    Copy { Lattice<Basis> }
  }
}
```

Create a lattice of crystal unit cells to carve. Coordinates are stored in numbers of crystal unit cells.

```swift
Solid { 
  Copy { Lattice<Basis> }
}
Solid {
  Copy { Solid }
}
```

Create a solid object composed of multiple lattices or other solids. Converts coordinates inside a crystal unit cell to nanometers.

```swift
Material { Element }
Material { [Element] }
```

Accepts `.carbon` for diamond and lonsdaleite, `[.carbon, .silicon]` for cubic moissanite. More materials may be added in the future, such as elemental silicon and compounds with titanium.

```swift
Bounds { Vector }
```

Sets the working set of crystal unit cells. The box spans `min(current origin, specified vector)` to `max(current origin, specified vector)` where `min` and `max` operate lane-wise on vectors.

### Object Transforms

```swift
Copy { Lattice<Basis> }
Copy { Solid }
```

Instantiates a previously designed object. If called inside an `Affine`, the instance's atoms may be rotated or translated.

```swift
Reflect { Vector }
```

Reflects the object across the current origin, along the specified axis.

```swift
Rotate { Vector }
```

Rotates counterclockwise around the vector by `length(vector)` revolutions. For example, scale the vector by 0.25 to rotate 90 degrees. When in a lattice, the rotation angle must be a multiple of 1/4 or 1/6 revolutions. 0.166, 0.167, 0.333, etc. are automatically recognized as 1/6, 1/3, etc.

Rotation occurs around a ray starting at the current origin, and pointing toward the specified vector.

```swift
Translate { Vector }
```

Translate the object by the specified vector, relative to its current position.

### Scopes

```swift
Affine {
  Copy { ... }
}
```

Starts a section that instantiates a previously designed object, then rotates or translates it.

```swift
Convex { 

}
```

Scope where every plane's "zero" volume merges through OR in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain.

```swift
Concave {

}
```

Scope where every plane's "zero" volume merges through AND in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain.

```swift
Volume {

}
```

Encapsulates a set of planes, so that everything inside the scope is removed from the stack upon exiting.

### Vectors

```swift
// Rhombic constants refer to a 3D rhombohedron spanning the smallest
// repeatable unit of hexagonal diamond, which can tile like a cuboid.
public let a: Vector<Hexagonal> = [0, 0, 1] * rhombic ab constant
public let b: Vector<Hexagonal> = [0.866, 0, -0.5] * rhombic ab constant
public let c: Vector<Hexagonal> = [0, 1, 0] * rhombic c constant
public let h: Vector<Cubic> = [1, 0, 0] * lattice constant
public let k: Vector<Cubic> = [0, 1, 0] * lattice constant
public let l: Vector<Cubic> = [0, 0, 1] * lattice constant
public let x: Vector<Amorphous> = [1, 0, 0] * nanometer
public let y: Vector<Amorphous> = [0, 1, 0] * nanometer
public let z: Vector<Amorphous> = [0, 0, 1] * nanometer
```

Unit vectors representing the crystal's basis.

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

```swift
Origin { Vector }
```

Translates the origin by a vector relative to the current origin. The origin will reset when you exit the current scope.

[^1]: Right now, cubic lattices and solids require vectors in the `Cubic` basis (`h`, `k`, `l`). The carbon centers can be extracted using `_centers`, in units of diamond cell width. You must multiply them by `0.357` to get nanometers. This API will be fixed in the future, so don't count on code written now being source-stable.
