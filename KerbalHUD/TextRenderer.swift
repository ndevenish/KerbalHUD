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
    let newAtlas : TextureAtlas
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
  
  
  // Work out the size of texture we require for a particular count of characters
  private func _required_texture_size(count: Int, size : Size2D<Int>) -> CGSize {
    // Work out the power of two length required for the maximum dimension
    let pwrMaxRequired = Int(ceil(log2(Float(max(size))*sqrt(Float(count)))))
    // Check the power below this, as it MIGHT work with uneven character counts
    let charCount2 = (x: Int(floor(pow(2, Float(pwrMaxRequired-1))/Float(size.w))),
      y: Int(floor(pow(2, Float(pwrMaxRequired-1))/Float(size.h))))
    let txSize : Int
    if charCount2.x*charCount2.y > count {
      txSize = Int(pow(2, Float(pwrMaxRequired-1)))
    } else {
      txSize = Int(pow(2, Float(pwrMaxRequired)))
    }
    return CGSize(width: txSize, height: txSize)
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
    let singleCharacterSizePts = Size2DFromCGSize(("W" as NSString).sizeWithAttributes(attrs))
    let characterFullPointSize = singleCharacterSizePts.map({Int(ceil($0))})
    let characterPixelSize = singleCharacterSizePts.map({$0*Float(UIScreen.mainScreen().scale)})
    let characterFullPixelSize = singleCharacterSizePts.map({Int(ceil($0 * Float(UIScreen.mainScreen().scale)))})
    
    let textureSize = _required_texture_size(atlasText.characters.count, size: characterFullPixelSize)
    // Work out how many characters we can fit in wide and high
    let characterCount = (x: Int(floor(textureSize.width/CGFloat(characterFullPixelSize.w))),
                          y: Int(floor(textureSize.height/CGFloat(characterFullPixelSize.h))))

    // Render the texture
    UIGraphicsBeginImageContextWithOptions(textureSize, false, 1)
    let context = UIGraphicsGetCurrentContext()
    // We precalculated the adjustment due to screen scaling, so apply it manually
    CGContextScaleCTM(context, UIScreen.mainScreen().scale, UIScreen.mainScreen().scale)
    // Build a character position lookup
    var charLookup : [Character: (x: Int, y: Int)] = [:]
    // Now render every character
    for char in 0..<atlasText.characters.count {
      // Get the subset of the text string to render
      let renderChar = atlasText.characters[atlasText.characters.startIndex.advancedBy(char)]
      
      // Calculate the lookup index for this
      let lX = char % characterCount.x
      let lY = (char - lX) / characterCount.x
      charLookup[renderChar] = (lX, lY)
      
      // Work out the exact point to draw and do it
      let point = CGPoint(x: lX*characterFullPointSize.w, y: lY*characterFullPointSize.h)
      let drawString = (String(renderChar) as NSString)
      drawString.drawAtPoint(point, withAttributes: attrs)
    }
    
    // Now, grab this as a texture
    let image = CGBitmapContextCreateImage(context)!
    UIGraphicsEndImageContext()
    do {
      let texture = Texture(glk: try GLKTextureLoader.textureWithCGImage(image, options: nil))
      // Bind this, and generate a mipmap
      tool.bind(texture)
      glGenerateMipmap(GLenum(GL_TEXTURE_2D));
      
      // Calculate the exact UV size to use
      let uvSize = Size2D(w: GLfloat(characterPixelSize.w)/GLfloat(textureSize.width),
                          h: GLfloat(characterPixelSize.h)/GLfloat(textureSize.height))
      
      let ta = TextureAtlas(tools: tool, fromExistingAtlas: texture,
        withItemSize: characterFullPixelSize, andItems: atlasText.characters.map({String($0)}),
        precalculatedUVSize: uvSize)
      
      // Build the atlas texture object
      let atlas = TextAtlas(texture: texture, fontSize: size, widthInCharacters: characterCount.x,
        uvSize: (uvSize.w, uvSize.h),
        texelSize: (width: GLfloat(characterFullPixelSize.w), height: GLfloat(characterFullPixelSize.h)),
        text: atlasText, coords: charLookup, newAtlas: ta)
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
            
            if let rEntry = atlas.newAtlas.rectForEntry(String(char)) {
              tool.program.setUVProperties(
                xOffset: Float(rEntry.origin.x), yOffset: Float(rEntry.origin.y),
                xScale: Float(rEntry.size.width), yScale: Float(rEntry.size.height))
            } else {
              print("Having to use backup")
              tool.program.setUVProperties(
                xOffset: atlas.uvSize.width*GLfloat(coords.x),
                yOffset: atlas.uvSize.height*GLfloat(coords.y+1),
                xScale:  atlas.uvSize.width,
                yScale:  -atlas.uvSize.height)
            }
            
            
            
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

class TextureAtlas {
  /// The framebuffer and texture used for atlas rendering
  private var framebuffer : Framebuffer
  /// The size of a single item in the atlas
  private var itemSize : Size2D<Int>
  /// Precalculated rects for every item in the atlas
  private var items : [String : CGRect] = [:]
  private var atlasSize : Size2D<Int>
  
  init(tools: DrawingTools, fromExistingAtlas: Texture,
    withItemSize: Size2D<Int>,
    andItems: [String],
    precalculatedUVSize: Size2D<Float>? = nil)
  {
    guard fromExistingAtlas.size != nil else {
      fatalError("Cannot create atlas from unknown texture size")
    }
    atlasSize = Size2D(w: fromExistingAtlas.size!.w / withItemSize.w,
                       h: fromExistingAtlas.size!.h / withItemSize.h)
    // Build a new framebuffer from this texture
    framebuffer = tools.createFramebufferForTexture(fromExistingAtlas)
    self.itemSize = withItemSize

    let uvWidth : CGFloat
    let uvHeight : CGFloat
    if let uv = precalculatedUVSize {
      uvWidth = CGFloat(uv.w)
      uvHeight = CGFloat(uv.h)
    } else {
      uvWidth = CGFloat(itemSize.w)/CGFloat(framebuffer.size.w)
      uvHeight = CGFloat(itemSize.h)/CGFloat(framebuffer.size.h)
    }
    
    // Calculate rects on this texture for every item
    for (i, item) in andItems.enumerate() {
      let indexY = i / atlasSize.w
      let indexX = i - (atlasSize.w * indexY)
      
      // Calculate the positions for the origin point
      let xPos = CGFloat(itemSize.w*indexX)/CGFloat(framebuffer.size.w)
      let yPos = CGFloat(itemSize.h*indexY)/CGFloat(framebuffer.size.h)
      
      let cPos = CGRectMake(xPos, yPos, uvWidth, uvHeight)
      items[item] = cPos
    }
  }
  
  func rectForEntry(index : String) -> CGRect? {
    return items[index]
  }
}

