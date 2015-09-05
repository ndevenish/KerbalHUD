//
//  SVGExtensions.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 05/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit
import GLKit


extension SVGImage
{
  func renderToTexture(size: Size2D<Float>, flip: Bool = true) -> Texture {
    let size = CGSize(width: CGFloat(size.w), height: CGFloat(size.h))
    // Scale the SVG size to the full area
    let svgSize = Size2D(w: self.svg.width.value, h: self.svg.height.value)
    let svgScale = Size2D(w: Float(size.width) / svgSize.w, h: Float(size.height) / svgSize.h)
    
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
    let context = UIGraphicsGetCurrentContext()
    if flip {
      CGContextTranslateCTM (context, 0, size.height);
      CGContextScaleCTM(context, CGFloat(svgScale.w), CGFloat(-svgScale.h))
    } else {
      CGContextScaleCTM(context, CGFloat(svgScale.w), CGFloat(svgScale.h))
    }
    
    drawToContext(context!)
    
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    
    processGLErrors()
    let texture = try! GLKTextureLoader.textureWithCGImage(image, options: nil)
    let entry = Texture(glk:texture)
    return entry
  }
}