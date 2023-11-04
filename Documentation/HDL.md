# Hardware Description Language

> This is not a brand name or trademarked word. There is no economic force with strings attached to it. It is simply a hardware description language for bootstrapping molecular nanotechnology.
>
> It is being incubated in the Molecular Renderer repository, but will eventually become a standalone library. It will remain as simple, general-purpose, and flexible as possible, while avoiding sources of technical debt.

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
    - [Volume Editing](#volume-editing)
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

At the moment, the JIT compiler has been deprecated, in favor of compiling in Swift release mode with incremental compilation.

## Syntax

### Lattice Editing

```swift
protocol Basis
Cubic: Basis
Hexagonal: Basis
```

Coordinate spaces for defining vectors in.

```swift
Bounds { SIMD3<Float> }
Bounds { 10 * h + 10 * k + 10 * l } // cubic
Bounds { 10 * h + 10 * (h + 2 * k) + 10 * l } // hexagonal
```

Sets the working set of crystal unit cells. The box spans from the world origin `[0, 0, 0]` the specified vector. This must be called in the top-level scope, before any `Volume` keywords.

For hexagonal crystals, the bounds are a cuboid defined by transforming the input vector. It is mapped from h/k/l space to h/h2k/l space. This allows the base lattice to be cartesian, similar to cubic. The quantity in each axis direction must be an integer.

```swift
Constant<Basis>(Basis.ConstantType) { MaterialType }
let latticeConstant = Constant<Cubic>(.square) { .elemental(.carbon) }

Cubic.ConstantType.square // square side length
Hexagonal.ConstantType.hexagon // hexagon side length
Hexagonal.ConstantType.prism // prism height
```

Values of the lattice constants, for use in `Solid`. This is a function that returns a `Float`.

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
  ...
  
  Volume {
    Plane { -h }
    Plane { -h2k }
    Plane { -l }
    
    Origin { 3 * h + 2 * (h2k + l) }
    Plane { +h }
    Plane { +h2k }
    Plane { +l }
    ...
  }
}
```

Unit vectors representing the crystal's basis.

```swift
Material { MaterialType }
```

Specifies the atom types to fill the lattice with, and the lattice constant. This must be called in the top-level scope, and may not be called after an `Affine` or `Copy`.

```swift
Reconstruct { SIMD3<Float> }
```

Within the selected volume, reconstruct any surfaces that need reconstruction. This usually affects flat, open surfaces and avoids placing bonds in corners (which occurs at a later step of compilation). Bonds more parallel to the specified vector are prioritized, and the parity of alternating patterns is defined by `Origin`. This must be called inside `Volume`.

An exemplar surface that may be reconstructed is diamond (100).

### Objects

```swift
Entity
EntityType
```

A wrapper type encapsulating atoms and bond connectors. The `Entity` includes position (12 bytes) and entity type (4 bytes). `EntityType` can extract information about the type, such as atomic number or bond order. Zero for the entity type indicates `.empty`.

Internally, empty entities are often used to pad vector lengths to multiples of 8. This enables greater CPU vector parallelism without the overhead of bounds checking. Replacing atoms with empty entities also deletes existing atoms.

```swift
Lattice<Basis> { h, k, l in
  Material { ... }
  Bounds { ... }
}
```

Create a lattice of crystal unit cells to edit. Coordinates are represented in numbers of crystal unit cells. The coordinate system may be mapped to a non-orthonormal coordinate system internally. Keep this in mind when processing `SIMD3<Float>` vectors. For example, avoid normalizing any vectors.

```swift
RigidBody { Lattice<Basis> }
RigidBody { Solid }
RigidBody { [Entity] }
```

Exposes the functionality from [Diamondoid](../Sources/MolecularRendererApp/Scenes/Procedural Geometry/Diamondoid.swift), such as topology generation. Documentation for this API is in progress.

```swift
Solid { x, y, z in
  Affine {
    Copy { Lattice<Basis> }
  }
}
Solid { x, y, z in
  Affine {
    Copy { Solid }
  }
}
```

Create a solid object composed of multiple lattices or other solids. Converts coordinates inside a crystal unit cell to nanometers.

### Scopes

```swift
Affine {
  // Perform any number of affine transforms (optional).
  // Finally, call 'Copy' to add atoms that undergo the specified order of
  // transforms.
}
```

Starts a section that instantiates a previously designed object, then rotates or translates it. This may not be called inside a `Volume` or another `Affine`.

> TODO: Accumulate the affine transforms into a 3x3 matrix, then apply to the copied positions. Simply pass all 3 cardinal axes through the transformation sequence, then create a matrix from the results. The transformations can be applied eagerly, instead of buffering them up for lazy evaluation.

```swift
Concave { }
```

Scope where every plane's "one" volume merges through AND in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Convex { }
```

Scope where every plane's "one" volume merges through OR in [DNF](https://en.wikipedia.org/wiki/Disjunctive_normal_form). Upon exiting this scope, the added planes remain. This must be called inside a `Volume`.

```swift
Volume { }
```

Encapsulates a set of planes, so that everything inside the scope is removed from the stack upon exiting. This is permitted inside both `Lattice` and `Solid`. This may not be called inside `Affine`, but may be called inside another `Volume`.

### Solid Editing

The following keywords may only be called inside an `Affine`.

```swift
Copy { Lattice<Basis> }
Copy { Solid }
Copy { [Entity] }
```

Instantiates a previously designed object. The array initializer accepts raw atom positions in nanometers. This may not be called in the top-level scope.

When two entities in the new structure are extremely close, one will be overwritten. The entity that survives is decided by the following priority list:
1. Highest valence.
2. Highest bond order.
3. Otherwise, the original atom wins. This rule prevents the atoms from drifting when several small modifications are performed.

```swift
Reflect { SIMD3<Float> }
```

Reflects the object across the current origin, along the specified axis.

```swift
Rotate { SIMD4<Float>(direction, rotation) }
Rotate { Quaternion<Float> }
```

Rotates counterclockwise around the direction, by the specified number of revolutions. The first 3 vector components are the direction; the fourth is the rotation. For example, enter `SIMD4(x + y + z, 0.25)` for 0.25 revolutions (90 degrees). The rotation occurs around the world origin `.zero`.

All direction vectors are `SIMD3` and must be converted to `SIMD4`. 4-wide SIMD vectors may be instantiated using the first three components (xyz, a `SIMD3<Float>`) and a fourth component (w, a `Float`). The initializer has the signature `SIMD4(SIMD3, Float)`. 

`SIMD4` is a more convenient API than `Quaternion`. However, the input is internally mapped to a quaternion before proceeding.

```swift
Translate { SIMD3<Float> }
```

Translate the object by the specified vector, relative to its current position.

### Volume Editing

The following keywords may only be called inside a `Volume`.

```swift
Origin { SIMD3<Float> }
```

Translates the origin by a vector relative to the current origin. Modifications to the origin are undone when leaving the current scope. This may not be called in the top-level scope.

```swift
Plane { SIMD3<Float> }
```

Adds a plane to the stack. The plane will be combined with other planes, and used for selecting/deleting atoms.

A `Plane` divides the `Bounds` into two sections. The "one" volume is the side the normal vector points toward. The "zero" volume is the side the normal points away from. The "one" volume contains the atoms deleted during a `Cut()`. When planes combine into a `Concave`, only the crystal unit cells common to every plane's "one" volume are deleted.

```swift
Ridge(SIMD3<Float>) { SIMD3<Float> }
Valley(SIMD3<Float>) { SIMD3<Float> }
```

Creates two planes by reflecting the first argument across the second argument. `Ridge` takes the union of the planes' "one" volumes, while `Valley` takes the intersection.

```swift
Replace { EntityType }
```

Replace all entities in the selected volume with a new entity. In the future, there may be an option to specify which atoms to preserve. The default is all non-empty atoms and bond connectors.

Instead of a dedicated keyword for cutting empty volumes, specify `Replace { .empty }`. Atoms deleted with a `Replace` cannot be restored by a subsequent `Replace`. The only method for filling in this geometry is creating a `Solid`, copying a separate piece of geometry that fills the void.

## Tips

List:
- Compile the Swift code in release mode with incremental compilation.
- Split into multiple files, decreasing the chance the compiler will take a long time compiling any one file.
