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
| H        | varies |        | | |
| B (sp3)  | 27     | 27     | | |
| C (sp3)  | 1      | 123    | not supported | not supported |
| N (sp3)  | 8, 198 | 8, 198 | | |
| O (sp3)  | 6  | 6   | | |
| F        | 11 |     | | |
| Si (sp3) | 19 | 19  | | |
| P (sp3)  | 25 | 25  | | |
| S (sp3)  | 15 | 15  | | |
| Cl       | 12 |     | | |
| Ge (sp3) | 31 | 31  | | |

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

Replaces selected atoms with the specified element, or deletes them and makes a bond bridging the neighbors. Does not affect vacant crystal unit cells.

```swift
Passivate { Element }
```

Adds hydrogens or halogens to complete the valence shells of selected atoms. Does not affect vacant crystal unit cells.

```swift
Plane { Vector }
```

Adds a plane to the stack. The plane will be combined with other planes, and used for selecting/deleting atoms.

### Objects

```swift
Cubic: Basis
Hexagonal: Basis
```

Coordinate spaces for defining vectors in. `Cubic` is used for editing cubic lattices and defining the positions of objects. `Hexagonal` is used for editing hexagonal lattices.

When editing lattices, vectors are measured in unit cell width. When defining the positions of objects, vectors are measured in nanometers.

```swift
Lattice<Basis> { 
  Material { ... }
  Bounds { ... }
}
```

Create a lattice of crystal unit cells to carve.

```swift
Solid { }
```

Create a solid object composed of multiple lattices or other solids.

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

Starts a section where every plane is combined through OR in disjunctive normal form. Upon exiting this scope, the added planes remain.

```swift
Concave {

}
```

Starts a section where every plane is combined through AND in disjunctive normal form. Upon exiting this scope, the added planes remain.

```swift
Volume {

}
```

Encapsulates a set of planes, so that everything inside the scope is removed from the stack upon exiting.

### Vectors

```swift
public let a: Vector<Hexagonal>
public let b: Vector<Hexagonal>
public let c: Vector<Hexagonal>
public let x: Vector<Cubic>
public let y: Vector<Cubic>
public let z: Vector<Cubic>
```

Unit vectors representing the crystal's basis.

```swift
prefix operator + (Vector<Basis>) -> Vector<Basis>
prefix operator - (Vector<Basis>) -> Vector<Basis>

// Examples
-x, +y, +z // cubic
+a, -b, +c // hexagonal
```

`-` makes a `Vector` point in the opposite direction (reflects across the origin). `+` explicitly denotes that an axis vector is positive.

```swift
infix operator * (Float, Vector<Basis>) -> Vector<Basis>
infix operator * (Vector<Basis>, Float) -> Vector<Basis>

// Examples
6 * x, -7 * y, -9.75 * z
a * -2.25, -8.5 * b, c * 1.0
```

Scales a `Vector` by a constant.

```swift
infix operator + (Vector<Basis>, Vector<Basis>) -> Vector<Basis>
infix operator - (Vector<Basis>, Vector<Basis>) -> Vector<Basis>

// Examples
6 * x - 7 * y - 9.75 * z
a * -2.25 + -8.5 * b + c * 1.0
```

Adds or subtracts two vectors.

```swift
Origin { Vector }
```

Translates the origin by a vector relative to the current origin. The origin will reset when you exit the current scope.
