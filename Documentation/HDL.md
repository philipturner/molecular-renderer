# (Prototype) Hardware Description Language

This is a precursor to the eventual hardware description language that atomCAD will build. The purpose is to allow reasonably efficient workflows for designing crystolecules here and now. Potentially, it can utilize primitive editing capabilities from the atomCAD codebase, to complement the lack of a UI in MolecularRenderer.
- This will enable the creation of a mechanical parts catalog covering several different categories. Each part will have Markdown documentation (when possible) and Swift APIs for instantiating parts/machines in larger assemblies. Heavy emphasis on making the parts <b>parametric</b>, so they can be used with a different material or dimension than originally conceived.
- Emphasis on <b>a first-generation technology base</b>. The language lacks support for strained shell structures, as they require second-generation technology (but it will facilitate testing of machines for building them). The forcefield will avoid exotic O or S atoms, sticking to elements manufacturable with an AFM.
- Tutorials and well-maintained documentation will be provided, to onboard new engineers and provide the skills for making crystolecules. This will cover common pitfalls in design, such as actions that expose triply-unbonded carbon atoms, and good practices like reconstructing (100) surfaces.
- The API will be geared toward those with <b>little to no Swift experience</b>. It will make minimal use of Swift's many examples of syntactic sugar. When possible, subsets of the HDL or hardware catalog's functionality will have bindings to alternative programming languages.
- The codebase will only depend on <b>cross-platform</b> Swift packages, even if Apple-specific libraries have higher performance.

Table of Contents
- [How it Works](#how-it-works)
- [Syntax](#syntax)
    - [Hierarchy of Design](#hierarchy-of-design)
    - [Operators](#operators)

## How it Works

At the atomic scale, constructive solid geometry is much easier than at the macroscale; there is no need to implicitly store shapes as equations. Instead, add or remove atoms from a grid held in computer memory. As the number of atoms can grow quite large, and many transformations can be applied, this approach can be computationally heavy. To achieve low latency, the compiler for translating the HDL (or UI actions) into geometry must be optimized for speed. Part of the compiler is boolean masks over a grid on single-core CPU. Another part in energy minimizations on the GPU.

The forcefield is based on MM4, using an algorithm $O(n)$ in van der Waals attractions and $O(n^2)$[^1] in electrostatic interactions. Avoid mixed-element materials like moissanite in bulk, although they are okay in small quantities. Crystolecules should have the bulk of atoms as elemental carbon or silicon, and surfaces terminated/passivated with polar covalent bonds. MM4 will be extended to the following elements:

| MM4 Atom Type | 6-ring | 5-ring | 4-ring | 3-ring |
| - | - | - | - | - |
| H     | 5  |     |    |    |
| C     | 1  | 123 | 56 | 22 |
| sp2 C | 2  | 122 | 57 | 38 |
| N     | 8  | 8   | 8  | 8  |
| Si    | 19 | 19  | 19 | 19 |
| Cl    | 12 |     |    |    |
| Ge    | 31 | 31  | 31 | 31 |

Key:
- X = nonpolar covalent bond (low compute cost)
- O = polar covalent bond (high compute cost)
- blank means not supported

| Element | H | C | sp2 C | N | Si | Cl | Ge |
| ----- | - | - | - | - | - | - | - |
| H     |   | X | X | X | X |   | X |
| C     | X | X | O | O | O | O | O |
| sp2 C | X | O | X | O | O | O | O |
| N     | X | O | O | X |   |   |   |
| Si    | X | O | O |   | X |   |   |
| Cl    |   | O | O |   |   |   |   |
| Ge    | X | O | O |   |   |   | X |

## Syntax

TODO (points to cover):
- Denotative (no hidden state)
- Disjunctive normal form
- Decreased functionality after decoupling from the crystal lattice

TODO: Host DocC documentation on GitHub pages

### Design Hierarchy

- `Assembly`
  - `RigidBody`
    - `Solid`
      - `Lattice<Basis>`
      - Slicing with planes
      - Automatically removing duplicated atoms from bounding volume intersections
      - Surface reconstruction
    - Connecting two different materials
    - Connecting two lattices through sp2 bonds
      - Two bodies connected by a joint must be marked as such, and have their momenta conserved separately
    - Connecting with Kaehler brackets
  - Surface passivation
  - Surface energy minimization
  - Conservation of momentum
  - (Angular) position/velocity tracking during simulation
- Multiple discontinuous bodies interlocked in a productive nanosystem
- Avoid geometries that require welding

### Operators

> Note: The operators will be simplified, so that direction and position are the same data type. Planes will accept (210), (211), (221) vectors instead of just (100), (110), (111). This is an implementation detail to support lonsdaleite.

```swift
prefix operator + (Axis) -> Direction
prefix operator - (Axis) -> Direction

// Examples
-x, +y, +z // cubic
+a, -b, +c // hexagonal
```

Transforms an `Axis` into a `Direction`.

```swift
infix operator * (Float, Axis) -> Position
infix operator * (Axis, Float) -> Position

// Examples
6 * x, -7 * y, -9.75 * z
a * -2.25, -8.5 * b, c * 1.0
```

Transforms an `Axis` into a `Position`.

```swift
infix operator + (Position, Position) -> Position
infix operator - (Position, Position) -> Position

// Examples
6 * x - 7 * y - 9.75 * z
a * -2.25 + -8.5 * b + c * 1.0
```

Concatenates two positions.

```swift
infix operator ^ (Direction, Direction) -> Direction

// Examples
-x ^ +y ^ +z
+a ^ -b
```

Concatenates two directions.

[^1]: If simulating large moissanite structures becomes necessary, we can invest time into an O(nlog(n)) electrostatics algorithm. It will have unacceptably high overhead for other materials though.
