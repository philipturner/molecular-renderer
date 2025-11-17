func XCTAssertEqual(
  _ lhs: Int,
  _ rhs: Int
) {
  print("checking \(lhs) == \(rhs)")
  guard lhs == rhs else {
    fatalError("Assertion failed.")
  }
}

func XCTAssertEqual(
  _ lhs: Double,
  _ rhs: Double,
  accuracy: Double
) {
  print("checking \(lhs) == \(rhs), accuracy: \(accuracy)")
  
  let difference = lhs - rhs
  guard difference.magnitude <= accuracy else {
    fatalError("Assertion failed.")
  }
}
