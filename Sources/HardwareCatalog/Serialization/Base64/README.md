# Base-64 Format

A base64-encoded format wrapping a 16-byte representation of an atom.
It is a `SIMD4<Float>` vector storing the position and the atomic number,
casted from UInt8 to Float. Next, it is converted into base64 to make the
raw data easily portable.

It can even be stored as a string literal in source code. For this
reason, newlines are inserted after every 76 bytes of output. Around 4
atoms fit into each line of code. Most base64 encoders ignore whitespace,
as it's a common method to organize large base64 strings. The overall
storage overhead is ~200 bits/atom, which may be comparable to mrsim-txt.

Hashes and asterisks can be used to comment sections of the encoded output.
They may signify frame numbers or keys to identify specific objects. This
structure is compatible with most base64 encoders. It also locally encodes
whether a hash begins or ends a comment, allowing initial parsing/scanning to
be parallelized.

```
#* comment *#
```

Comments are not baked into this file due to the potential for feature creep.
Comments and parallelization of large encoding/decoding jobs should be
comparatively easy to implement client-side. All that might be needed is a
faster single-core CPU kernel in this file, for both encoding and decoding
individual arrays of atoms.
