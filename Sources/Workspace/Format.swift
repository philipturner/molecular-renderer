// Utility for logging quantities to the console.
struct Format {
  static func pad(_ x: String, to size: Int) -> String {
    var output = x
    while output.count < size {
      output = " " + output
    }
    return output
  }
  static func time<T: BinaryFloatingPoint>(_ x: T) -> String {
    let xInFs = Float(x) * 1e3
    var repr = String(format: "%.2f", xInFs) + " fs"
    repr = pad(repr, to: 9)
    return repr
  }
  static func energy(_ x: Double) -> String {
    var repr = String(format: "%.2f", x / 160.218) + " eV"
    repr = pad(repr, to: 13)
    return repr
  }
  static func force(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " pN"
    repr = pad(repr, to: 13)
    return repr
  }
  static func distance(_ x: Float) -> String {
    var repr = String(format: "%.2f", x) + " nm"
    repr = pad(repr, to: 9)
    return repr
  }
}
