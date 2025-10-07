struct TransactionArgs {
  var removedCount: UInt32 = .zero
  var movedCount: UInt32 = .zero
  var addedCount: UInt32 = .zero
  
  static var shaderDeclaration: String {
    """
    struct TransactionArgs {
      uint removedCount;
      uint movedCount;
      uint addedCount;
    };
    """
  }
}
