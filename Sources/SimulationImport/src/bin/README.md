# Benchmark utility

The utility code can be used as an implementation reference.

## Usage

```
mrsim_txt_benchmark(.exe) <file_path> [--frames=frame1,frame2,...] [--atoms=atom1,atom2,...]
```

- <file_path>: The path to the file that should be loaded and parsed.
- --frames: An optional argument where you can specify comma-separated frame indices. If not provided, the utility will randomly select 10 frames.
- --atoms: An optional argument where you can specify comma-separated atom indices. If not provided, the utility will randomly select 5 atoms.