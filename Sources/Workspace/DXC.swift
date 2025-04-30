// Utility file that will eventually go inside the molecular-renderer module.

@_silgen_name("dxcompiler_compile")
internal func dxcompiler_compile(
  _ shaderSource: UnsafePointer<CChar>,
  _ shaderSourceLength: UInt32
) -> Int8
