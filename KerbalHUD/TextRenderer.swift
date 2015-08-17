//
//  TextRenderer.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 17/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit
import UIKit


class TextRenderer {
  private var tool : DrawingTools
  private(set) var fontName : String
  private struct TextEntry {
    let texture : GLKTextureInfo
    let uvPosition : Point2D
    let areaSize : Point2D
    let fontSize : Int
    let text : String
  }
  private var textures : [TextEntry] = []
  /// A list of all textures accessed since the last flush
  private var foundTextures : Set<Int> = []
  private var monospaced : Bool = false
  
  private struct TextAtlas {
    let texture : GLKTextureInfo
    // What font size was this generated at?
    let fontSize : Int
    // How many characters do we hold horizontally
    let widthInCharacters : Int
    // How big is a single character in UV
    let uvSize : (width: GLfloat, height: GLfloat)
    // Physical size of a single character
    let texelSize : (width: GLfloat, height: GLfloat)
    // The collection of characters in this atlas
    let text : String
  }
  private var textAtlasses : [TextAtlas] = []
  
  /// Cleans out textures not used recently
  func flush() {
    let to_remove = Set(0..<textures.count).subtract(foundTextures)
    for i in to_remove.sort().reverse() {
      let oldTex = textures.removeAtIndex(i)
      var name = oldTex.texture.name
      glDeleteTextures(1, &name)
    }
    foundTextures.removeAll()
  }
  
  init(tool : DrawingTools, font : String) {
    fontName = font
    self.tool = tool
    
    // Determine if this is a monospace font by rendering two test strings
    let uiFont = UIFont(name: fontName, size: UIFont.systemFontSize())!
    let attr = [NSFontAttributeName: uiFont]
    let wSize = ("W" as NSString).sizeWithAttributes(attr)
    let iSize = ("W." as NSString).sizeWithAttributes(attr)
    if abs(iSize.width - 2*wSize.width) < 1e-2 {
      monospaced = true
    }
    getAtlas(10)
  }
  
  /// See if we have rendered this entry before
  private func find_existing(text: String, size : Int) -> TextEntry? {
    for (i, entry) in textures.enumerate() {
      if entry.text == text && entry.fontSize == size {
        foundTextures.insert(i)
        return entry
      }
    }
    return nil
  }
  
  func draw(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment = .Left,
    rotation: GLfloat = 0, transform : GLKMatrix4 = GLKMatrix4Identity) {
      // Calculate a point size for this screen projection size
      let fontSize = Int(ceil(size / tool.pointsToScreenScale))
      let entry = getTextEntry(text, size: fontSize)
      
      let texture = entry.texture
      tool.bindArray(tool.vertexArrayTextured)
      glBindTexture(texture.target, texture.name)
      
      // Work out how wide we want to draw
      let squareWidth = size * GLfloat(texture.width)/GLfloat(texture.height)
      
      var baseMatrix = transform
      switch(align) {
      case .Left:
        baseMatrix = GLKMatrix4Translate(baseMatrix, position.x, position.y, 0)
      case .Right:
        baseMatrix = GLKMatrix4Translate(baseMatrix, position.x-squareWidth, position.y, 0)
      case .Center:
        baseMatrix = GLKMatrix4Translate(baseMatrix, position.x-squareWidth/2, position.y, 0)
      default:
        break
      }
      baseMatrix = GLKMatrix4Rotate(baseMatrix, rotation, 0, 0, 1)
      baseMatrix = GLKMatrix4Scale(baseMatrix, squareWidth, size, 1)
      baseMatrix = GLKMatrix4Translate(baseMatrix, 0, -0.5, 0)
      tool.program.setModelView(baseMatrix)
      tool.program.setUseTexture(true)
      glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
      tool.program.setUseTexture(false)
  }
  
  private func getTextEntry(text: String, size : Int) -> TextEntry {
    // First see if we already built this texture
    if let existing = find_existing(text, size: size) {
      // We found that we drew this before!
      return existing
    }
    
    // Let's work out the font size we want, approximately
    let font = UIFont(name: fontName, size: CGFloat(size))!
    let attrs = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor()]
    
    // Render the text to a CGContext
    let text = text as NSString
    let renderedSize: CGSize = text.sizeWithAttributes(attrs)
    UIGraphicsBeginImageContextWithOptions(renderedSize, false, UIScreen.mainScreen().scale)
    let context = UIGraphicsGetCurrentContext()
    text.drawAtPoint(CGPoint(x: 0, y: 0), withAttributes: attrs)
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    
    let texture = try! GLKTextureLoader.textureWithCGImage(image, options: nil)
    let entry = TextEntry(texture: texture, uvPosition: (0,0), areaSize: (1,1), fontSize: size, text: (text as String))
    foundTextures.insert(textures.count)
    textures.append(entry)
    return entry
  }
  
  private func getAtlas(size: Int) -> TextAtlas? {
    // Try to find an atlas matching this
    for atlas in textAtlasses {
      if atlas.fontSize == size {
        return atlas
      }
    }
    
    let atlasText = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~Δ☊¡¢£¤¥¦§¨©ª«¬☋®¯°±²³´µ¶·¸¹º»¼½¾¿˚π"
    let font = UIFont(name: fontName, size: CGFloat(size))
    let attrs : [String : AnyObject] = [NSFontAttributeName: font!]
    
    // How large is a single character?
    let singleCharacterSizePts = ("W" as NSString).sizeWithAttributes(attrs)
    
    let singleCharacterSize : (width : Float, height: Float) = (
      Float(singleCharacterSizePts.width*UIScreen.mainScreen().scale),
      Float(singleCharacterSizePts.height*UIScreen.mainScreen().scale)
    )
    // Work out the size of texture required
    func _required_texture_size(count: Int, size : (width: Float, height: Float)) -> CGSize {
      // Bump up any fractional sizes
      let size = (width: ceil(size.width), height: ceil(size.height))
      // Work out the power of two length required for the maximum dimension
      let pwrMaxRequired = Int(ceil(log2(max(size.height, size.width)*sqrt(Float(count)))))
      // Check the power below this, as it MIGHT work with uneven character counts
      let charCount2 = (x: Int(floor(pow(2, Float(pwrMaxRequired-1))/size.width)),
                       y: Int(floor(pow(2, Float(pwrMaxRequired-1))/size.height)))
      let txSize : Int
      if charCount2.x*charCount2.y > count {
        txSize = Int(pow(2, Float(pwrMaxRequired-1)))
      } else {
        txSize = Int(pow(2, Float(pwrMaxRequired)))
      }
      return CGSize(width: txSize, height: txSize)
    }
    let textureSize = _required_texture_size(atlasText.characters.count, size: singleCharacterSize)
    let characterCount = (x: Int(floor(textureSize.width/CGFloat(singleCharacterSize.width))),
                          y: Int(floor(textureSize.width/CGFloat(singleCharacterSize.width))))
    // Render the texture
    UIGraphicsBeginImageContextWithOptions(textureSize, false, 1)
    let context = UIGraphicsGetCurrentContext()
    for line in 0...characterCount.y {
      // Don't go it we are over the end of the texture atlas
      if line*characterCount.x > atlasText.characters.count {
        break
      }
      // Get the subset of the text texture
      let unboundEndIndex = (line+1)*characterCount.x
      let endIndex = unboundEndIndex > atlasText.characters.count ?
        atlasText.endIndex : advance(atlasText.startIndex, unboundEndIndex)
      let range = Range(start: advance(atlasText.startIndex, line*characterCount.x),
                        end: endIndex)
      let renderText = atlasText.substringWithRange(range)
      print("Rendering \(renderText) to line \(line)")
      let point = CGPoint(x: 0, y: Int(ceil(singleCharacterSize.height*Float(line))))
      (renderText as NSString).drawAtPoint(point, withAttributes: attrs)
    }

    // Now, grab this as a texture
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    let texture = try! GLKTextureLoader.textureWithCGImage(image, options: nil)
    
    let atlas = TextAtlas(texture: texture, fontSize: size, widthInCharacters: characterCount.x,
      uvSize: (GLfloat(0.0),GLfloat(0.0)),
      texelSize: (GLfloat(ceil(singleCharacterSize.height)), GLfloat(ceil(singleCharacterSize.width))),
      text: atlasText)
    textAtlasses.append(atlas)
    return atlas
  }
}

