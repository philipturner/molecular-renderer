struct ConstantArgs {
  var atomCount: UInt32 = .zero
  var frameSeed: UInt32 = .zero
  
  static var shaderDeclaration: String {
    """
    struct ConstantArgs {
      uint atomCount;
      uint frameSeed;
    };
    """
  }
}
