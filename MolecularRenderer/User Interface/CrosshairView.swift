//
//  CrosshairView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/16/23.
//

import SwiftUI
import SceneKit

struct CrosshairView: View {
  // A constant for the size of the crosshair
  static let crosshairSize: CGFloat = 40
  
  var body: some View {
    // A crosshair shape with a blend mode that inverts the background color
    CrosshairShape()
//      .fill(.red)
      
      .frame(
        width: CrosshairView.crosshairSize,
        height: CrosshairView.crosshairSize)
      .blendMode(.difference)
//
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
  
  // A method to draw a crosshair path in a given rect
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    // Get the center point of the rect
    let center = CGPoint(x: rect.midX, y: rect.midY)
    print(rect)
    
    // Does not work
//    // Get the half width and height of the rect
//    let halfWidth = rect.width / 2
//    let halfHeight = rect.height / 2
    
    let halfWidth = CrosshairView.crosshairSize / 2
    let halfHeight = CrosshairView.crosshairSize / 2
    
    //    path.move(to: CGPoint(x: center.x - halfWidth, y: center.y - 50))
    //    path.addLine(to: CGPoint(x: center.x + 50, y: center.y - 50))
    //    path.addLine(to: CGPoint(x: center.x + 50, y: center.y + 50))
    //    path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y + 50))
    //    path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y - 50))
    
//    // Define a constant for the gap between the lines
//    let gap: CGFloat = 2
//
//    // Draw four lines from the center point to the edges of the rect with a gap in between
//    path.move(to: CGPoint(x: center.x - halfWidth, y: center.y))
//    path.addLine(to: CGPoint(x: center.x - gap, y: center.y))
//    path.move(to: CGPoint(x: center.x + gap, y: center.y))
//    path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
//    path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
//    path.addLine(to: CGPoint(x: center.x, y: center.y - gap))
//    path.move(to: CGPoint(x: center.x, y: center.y + gap))
//    path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
    
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
