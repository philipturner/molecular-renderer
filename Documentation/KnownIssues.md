# Known Issues

## HDL Module

### Bug 2

This bug was not successfully reproduced.

```swift
// Second reproducer: when disconnecting this from the parent's scope
// (duplicating the "Origin { 12 * h + 8 * h2k + 6 * l }" statement), the
// geometry started behaving predictably again.
Volume {
  Concave {
    for direction in [h, -h] {
      Convex {
        if direction.x > 0 {
          Origin { 4 * direction }
        } else {
          Origin { 3.5 * direction }
        }
        Plane { -direction }
      }
    }
    Concave {
      Origin { -1.2 * l }
      Plane { l }
      Origin { 2 * l }
      Plane { -l }
      
      Origin { -5.5 * h2k }
      Plane { -h2k }
    }
  }
  Replace { .empty }
}
```

### Bug 1

This bug was not successfully reproduced.

```swift
// NOTE: There is a bug. When a Volume is nested inside a Concave, it
// won't treat it like it's actually concave. Or, something is messed up
// with the origin. Reproducer:
Concave {
  Origin { 2.8 * l }
  Plane { l }
  Volume {
    Origin { -2.5 * h2k }
    Plane { -h2k }
    Replace { .empty }
  }
}
```

## MolecularRenderer Module

Motion vectors must be flipped for MetalFX upscaling. The direction to flip the vectors has changed in the past.

| macOS Version | Motion Vector X | Motion Vector Y |
| ------------- | --------------- | --------------- |
| Ventura (13)  | Not Flipped     | Flipped         |
| Sonoma (14)   | Flipped         | Flipped         |
