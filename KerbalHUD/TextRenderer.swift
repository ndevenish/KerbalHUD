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

protocol TextRenderer {
  /// Returns the average aspect of a single character
  var aspect : Float { get }
  /// The font name being used by this texture renderer
  var fontName : String { get }
  
  func draw(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment,
  rotation: GLfloat, transform : GLKMatrix4)
}

extension TextRenderer {
  func draw(text: String, size : GLfloat, position : (x: Float, y: Float), align : NSTextAlignment = .Left, rotation: GLfloat = 0, transform : GLKMatrix4 = GLKMatrix4Identity) {
    return self.draw(text, size: size, position: Point2D(position.x,position.y), align: align, rotation: rotation, transform: transform)
  }
  func draw(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment = .Left,
    rotation: GLfloat = 0, transform : GLKMatrix4 = GLKMatrix4Identity) {
      return self.draw(text, size: size, position: position, align: align, rotation: rotation, transform: transform)
  }
}

class AtlasTextRenderer : TextRenderer {
  private var tool : DrawingTools
  private(set) var fontName : String
  private struct TextEntry {
    let texture : Texture
    let uvPosition : Point2D
    let areaSize : Point2D
    let fontSize : Int
    let text : String
  }
  private var textures : [TextEntry] = []
  /// A list of all textures accessed since the last flush
  private var foundTextures : Set<Int> = []
  private var monospaced : Bool = false
  private(set) var aspect : Float
  
  private struct TextAtlas {
//    let texture : GLKTextureInfo
    let texture : Texture
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
    // Location of characters
    let coords : [Character : (x: Int, y: Int)]
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
    aspect = Float(wSize.width / wSize.height)
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
      // If we are monospaced, try from atlas
      if monospaced {
        if drawFromAtlas(text, size: size, position: position, align: align, rotation: rotation, transform: transform) {
          return;
        }
      }
      // We are not monospace, or drawing from atlas failed. Fall back on the old system.
      
      // Calculate a point size for this screen projection size
      let fontSize = Int(ceil(size / tool.pointsToScreenScale))
      let entry = getTextEntry(text, size: fontSize)
      
      let texture = entry.texture
//      tool.bind(tool.texturedArray!)
//      tool.bindArray(tool.vertexArrayTextured)
      glBindTexture(texture.target, texture.name)
      
      // Work out how wide we want to draw
      let squareWidth = size * GLfloat(texture.glk!.width)/GLfloat(texture.glk!.height)
      
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
      tool.draw(tool.texturedSquare!)
  }
  
  
  func drawToTexture(text: String, size: Int) -> Texture {
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
    
    processGLErrors()
    let texture = try! GLKTextureLoader.textureWithCGImage(image, options: nil)
    let entry = Texture(glk:texture)
    return entry
  }
  
  private func getTextEntry(text: String, size : Int) -> TextEntry {
    // First see if we already built this texture
    if let existing = find_existing(text, size: size) {
      // We found that we drew this before!
      return existing
    }
    
    let txt = drawToTexture(text, size: size)
    let entry = TextEntry(texture: txt,
      uvPosition: Point2D(x: 0, y: 0), areaSize: Point2D(x: 1,y: 1), fontSize: size, text: (text as String))
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
    
    // Clear any errors before running this process
    processGLErrors()
    
    let atlasText = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~Δ☊¡¢£¤¥¦§¨©ª«¬☋®¯°±²³´µ¶·¸¹º»¼½¾¿˚π"
    let font = UIFont(name: fontName, size: CGFloat(size))
    let attrs : [String : AnyObject] = [NSFontAttributeName: font!, NSForegroundColorAttributeName: UIColor.whiteColor()]
    
    // How large is a single character?
    let singleCharacterSizePts = ("W" as NSString).sizeWithAttributes(attrs)
    
    let singleCharacterSize : (width : Float, height: Float) = (
      Float(singleCharacterSizePts.width),
      Float(singleCharacterSizePts.height)
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
                          y: Int(floor(textureSize.height/CGFloat(singleCharacterSize.height))))
    // Render the texture
    UIGraphicsBeginImageContextWithOptions(textureSize, false, UIScreen.mainScreen().scale)
    let context = UIGraphicsGetCurrentContext()
    var charLookup : [Character: (x: Int, y: Int)] = [:]
    for line in 0...characterCount.y {
      // Don't go it we are over the end of the texture atlas
      if line*characterCount.x > atlasText.characters.count {
        break
      }
      // Get the subset of the text texture
      let unboundEndIndex = (line+1)*characterCount.x
      let endIndex = unboundEndIndex > atlasText.characters.count ?
        atlasText.endIndex : atlasText.startIndex.advancedBy(unboundEndIndex)
//        advance(atlasText.startIndex, )
      let range = Range(start: atlasText.startIndex.advancedBy(line*characterCount.x),
                        end: endIndex)
      let renderText = atlasText.substringWithRange(range)
//      print("Rendering \(renderText) to line \(line)")
      for (x, char) in renderText.characters.enumerate() {
        charLookup[char] = (x, line)
      }
      let point = CGPoint(x: 0, y: Int(ceil(singleCharacterSize.height*Float(line))))
      (renderText as NSString).drawAtPoint(point, withAttributes: attrs)
    }

    // Now, grab this as a texture
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    do {
      let texture = Texture(glk: try GLKTextureLoader.textureWithCGImage(image, options: nil))
      // Bind this, and generate a mipmap
      tool.bind(texture)
      glGenerateMipmap(GLenum(GL_TEXTURE_2D));
      
      // Use initial calculated values - texture size could be anything, depending on scale
      let uvSize = (width: GLfloat(singleCharacterSize.width)/GLfloat(textureSize.width),
        height: GLfloat(singleCharacterSize.height)/GLfloat(textureSize.height))
      
      let atlas = TextAtlas(texture: texture, fontSize: size, widthInCharacters: characterCount.x,
        uvSize: uvSize,
        texelSize: (width: GLfloat(ceil(singleCharacterSize.width)), height: GLfloat(ceil(singleCharacterSize.height))),
        text: atlasText, coords: charLookup)
      textAtlasses.append(atlas)
      return atlas

    } catch let err as NSError {
      print("ERROR: " + err.localizedDescription)
      print (err)
      return nil
    }
  }
  
  private func drawFromAtlas(
    text: String, size : GLfloat, position : Point2D,
    align : NSTextAlignment = .Left,
    rotation: GLfloat = 0,
    transform : GLKMatrix4 = GLKMatrix4Identity) -> Bool {
      // Prevent internal calls if not monospaced
      if !monospaced {
        return false
      }
      // Apply the transformation to a vector to get the x scale, then convert to points
      let scaledX = (transform * GLKVector3.eX).length * tool.scaleToPoints.x //* Float(tool.screenSizePhysical.w)
      let scaledY = (transform * GLKVector3.eY).length * tool.scaleToPoints.y//*  Float(tool.screenSizePhysical.h)
      let scaledAspect = scaledX/scaledY
      
      
      let fontSize = Int(ceil(size*scaledY / tool.pointsToScreenScale))
      guard fontSize < 100 else {
//        fatalError()
        return false
      }
      if let atlas = getAtlas(fontSize) {
        tool.bind(atlas.texture)
//        tool.bind(tool.texturedArray!)

        // Calculate the total end size, for things like alignment
        let aspect = atlas.texelSize.width / atlas.texelSize.height
        let squareWidth = size * aspect * GLfloat(text.characters.count)
        var baseMatrix = transform
        // Handle left/right alignment
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
        // Scale to match the shape of a single character
        baseMatrix = GLKMatrix4Scale(baseMatrix, size*aspect/scaledAspect, size, 1)
        // Offset so that the text is center-aligned
        baseMatrix = GLKMatrix4Translate(baseMatrix, 0, -0.5, 0)
        
        var altTexture : Bool = false
        // Now, loop over every character individually
        for (i, char) in text.characters.enumerate() {
          if String(char) == " " {
            continue
          }
          let charMatrix = GLKMatrix4Translate(baseMatrix, GLfloat(i), 0, 0)
          tool.program.setModelView(charMatrix)
          
          // Find the coordinates for this character
          if let coords = atlas.coords[char] {
            if altTexture {
              altTexture = false
              tool.bind(atlas.texture)
            }
            tool.program.setUVProperties(
                xOffset: atlas.uvSize.width*GLfloat(coords.x),
                yOffset: atlas.uvSize.height*GLfloat(coords.y+1),
                xScale:  atlas.uvSize.width,
                yScale:  -atlas.uvSize.height)
            //glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
            tool.draw(tool.texturedSquare!)
          } else {
            // We don't recognise this character. This is a problem.
            // Use the old text drawing to render it
            let entry = getTextEntry(String(char), size: fontSize)
            tool.bind(entry.texture)
            altTexture = true
            tool.program.setUVProperties(xOffset: 0, yOffset: 0, xScale:  1, yScale:  1)
            glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
          }
        }
      } else {
        // Couldn't get an atlas
        return false
      }
      return true
  }
}

