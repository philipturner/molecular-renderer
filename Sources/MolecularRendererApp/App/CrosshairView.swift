//
//  CrosshairView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/16/23.
//

import SwiftUI
import SceneKit

struct CrosshairView: View {
  @ObservedObject var coordinator: Coordinator
  
  // A constant for the size of the crosshair
  private let _rawCrosshairSize: CGFloat = 80
  
  var crosshairSize: CGFloat {
    self._rawCrosshairSize / coordinator.view.backingScaleFactor
  }
  
  var body: some View {
    // A crosshair shape with a blend mode that inverts the background color
    CrosshairShape(crosshairSize: crosshairSize)
      .frame(
        width: crosshairSize,
        height: crosshairSize)
      .blendMode(.difference)
  }
}

extension CGPoint: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: CGFloat...) {
    precondition(elements.count == 2, "Unexpected element count.")
    self.init(x: elements[0], y: elements[1])
  }
}

// A Shape to draw a crosshair
struct CrosshairShape: Shape {
  // A constant for the size of the crosshair
  let crosshairSize: CGFloat
  
  // A method to draw a crosshair path in a given rect
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    // Get the center point of the rect
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let halfWidth = self.crosshairSize / 2
    let thickness: CGFloat = 2
    let offset: CGFloat = thickness / 2
    
    // Botton of + sign
    path.move(to: [center.x - offset, center.y - offset])
    path.addLine(to: [center.x - offset, center.y - halfWidth])
    path.addLine(to: [center.x + offset, center.y - halfWidth])
    path.addLine(to: [center.x + offset, center.y - offset])
    
    // Right of + sign
    path.addLine(to: [center.x + halfWidth, center.y - offset])
    path.addLine(to: [center.x + halfWidth, center.y + offset])
    path.addLine(to: [center.x + offset, center.y + offset])
    
    // Top of + sign
    path.addLine(to: [center.x + offset, center.y + halfWidth])
    path.addLine(to: [center.x - offset, center.y + halfWidth])
    path.addLine(to: [center.x - offset, center.y + offset])
    
    // Left of + sign
    path.addLine(to: [center.x - halfWidth, center.y + offset])
    path.addLine(to: [center.x - halfWidth, center.y - offset])
    path.addLine(to: [center.x - offset, center.y - offset])
    
    return path
  }
}
