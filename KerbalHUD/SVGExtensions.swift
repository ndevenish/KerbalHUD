//
//  SVGExtensions.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 05/09/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import UIKit
import GLKit


class ImageLibrary {
  private var images : [String : Texture] = [:]
  private var loaders : [String: () -> Texture] = [:]
  private var tools : DrawingTools? = nil
  
  init(tools : DrawingTools) {
    self.tools = tools
  }
  
  deinit {
    loaders.removeAll()
    for tex in images.values {
      tools?.deleteTexture(tex)
    }
  }
  
  subscript(index: String) -> Texture? {
    if let img = images[index] {
      return img
    } else if let imgLoader = loaders[index] {
      // We need to load the image
      let tex = imgLoader()
      images[index] = tex
      return tex
    }
    return nil
  }

  func addImage(name: String, texture: Texture) {
    images[name] = texture
  }
  func addImage(name: String, loader: () -> Texture) {
    loaders[name] = loader
  }
}

extension SVGImage
{
  func renderToTexture(size: Size2D<Float>, id : String = "", flip: Bool = true) -> Texture {
    let size = CGSize(width: CGFloat(size.w), height: CGFloat(size.h))
    
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
    let context = UIGraphicsGetCurrentContext()
    if flip {
      CGContextTranslateCTM (context, 0, size.height);
      CGContextScaleCTM(context, 1, -1)
    }
    
    try! drawToContextRect(context!, rect: CGRectMake(0, 0, size.width, size.height), subId: id)
    
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    
    processGLErrors()
    let texture = try! GLKTextureLoader.textureWithCGImage(image, options: nil)
    let entry = Texture(glk:texture)
    return entry
  }
  
  func addElementsToImageLibrary(library: ImageLibrary, size: Size2D<Float>) {
    for element in namedElements {
      let loader = { self.renderToTexture(size, id: element) }
      library.addImage(element, loader: loader)
    }
  }
  
  convenience init(fromBundleFile: String) {
    let url = NSBundle.mainBundle().URLForResource(fromBundleFile, withExtension: nil)
    self.init(withContentsOfFile: url!)
  }
}