# Known Issues

## MolecularRenderer Module

Acceleration structures:

| Type | Atom Reference Size | Passing Tests |
| ---- | ------------------- | ------------- |
| Dense Uniform Grid | 16-bit | ❌ |
| Dense Uniform Grid | 32-bit | ✅ |
| Sparse Uniform Grid | 16-bit | n/a |
| Sparse Uniform Grid | 32-bit | n/a |

State of MetalFX bugs:

| macOS Version | Motion Vector X | Motion Vector Y |
| ------------- | --------------- | --------------- |
| Ventura (13)  | Not Flipped     | Flipped         |
| Sonoma (14)   | Flipped         | Flipped         |
