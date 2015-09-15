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
  
  func draw(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment, rotation: GLfloat, transform : GLKMatrix4)
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



/// Work out the size of texture we require for a particular count of characters
private func _required_texture_size(count: Int, size : Size2D<Int>) -> CGSize {
  // Work out the power of two length required for the maximum dimension
  let pwrMaxRequired = Int(ceil(log2(Float(max(size))*sqrt(Float(count)))))
  // Check the power below this, as it MIGHT work with uneven character aspect
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

  private var textAtlasses : [Int: TextureAtlas] = [:]
  
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
      glPushGroupMarkerEXT(0, "Drawing Text: " + text)
      defer {
        glPopGroupMarkerEXT()
      }
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
    glPushGroupMarkerEXT(0, "Drawing Text to texture: " + text)
    defer {
      glPopGroupMarkerEXT()
    }
    let font = UIFont(name: fontName, size: CGFloat(size))!
    let attrs = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor()]
    
    let scale = Float(UIScreen.mainScreen().scale)
    
    // Render the text to a CGContext
    let text = text as NSString
    let renderedSize: CGSize = text.sizeWithAttributes(attrs)
    let texSize = (Size2DFromCGSize(renderedSize) * scale)
      .map({Int(ceil($0))})

    UIGraphicsBeginImageContextWithOptions(texSize.asCGSize, false, 1)
    
    let context = UIGraphicsGetCurrentContext()
    CGContextTranslateCTM(context, 0, CGFloat(texSize.h))
    CGContextScaleCTM(context, CGFloat(scale), -CGFloat(scale))
    
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

  private func createAtlas(size: Int) -> TextureAtlas {
    guard size > 0 && size < 100 else {
      fatalError("Invalid atlas size")
    }
    glPushGroupMarkerEXT(0, "Creating texture atlas \(fontName)_\(size)")
    
    // Clear any errors before running this process
    processGLErrors()
    tool.saveState()
    defer {
      tool.restoreState()
      glPopGroupMarkerEXT()
    }
    let scale : Float = Float(UIScreen.mainScreen().scale)
    
    let atlasText = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~Δ☊¡¢£¤¥¦§¨©ª«¬☋®¯°±²³´µ¶·¸¹º»¼½¾¿˚π"
    let font = UIFont(name: fontName, size: CGFloat(size))
    let attrs : [String : AnyObject] = [NSFontAttributeName: font!, NSForegroundColorAttributeName: UIColor.whiteColor()]
    
    // How large is a single character? Work out points, rounded points, pixels and rounded pixels
    let singleCharacterSizePts = Size2DFromCGSize(("W" as NSString).sizeWithAttributes(attrs))
    let characterFullPointSize = singleCharacterSizePts.map({Int(ceil($0))})
    let characterPixelSize = singleCharacterSizePts.map({$0*scale})
    let characterFullPixelSize = characterFullPointSize.map({Int(ceil(Float($0) * scale))})
    
    let textureSize = _required_texture_size(atlasText.characters.count, size: characterFullPixelSize)

    // Calculate the exact UV size to use
    let uvSize = Size2D(w: GLfloat(characterPixelSize.w)/GLfloat(textureSize.width),
      h: GLfloat(characterPixelSize.h)/GLfloat(textureSize.height))
    
    
    let atlas = TextureAtlas(tools: tool,
      totalSize: Size2DFromCGSize(textureSize).map({UInt($0)}),
      itemSize: characterFullPixelSize.map({UInt($0)}))
    atlas.texture.debugName(fontName + "_" + String(size))
    
    for char in atlasText.characters.map({ String($0) }) {
      let tex = drawToTexture(char, size: size)
      try! atlas.addItem(char, item: tex, realAspect: uvSize.aspect)
      tool.deleteTexture(tex)
    }

    textAtlasses[size] = atlas
    return atlas
  }
  
  private func drawFromAtlas(
    text: String, size : GLfloat, position : Point2D,
    align : NSTextAlignment = .Left,
    rotation: GLfloat = 0,
    transform : GLKMatrix4 = GLKMatrix4Identity) -> Bool
  {
    // Prevent usage of the atlas if not monospaced
    if !monospaced {
      return false
    }
    // Apply the transformation to a vector to get the x scale, then convert to points
    let scaledX = (transform * GLKVector3.eX).length * tool.scaleToPoints.x //* Float(tool.screenSizePhysical.w)
    let scaledY = (transform * GLKVector3.eY).length * tool.scaleToPoints.y//*  Float(tool.screenSizePhysical.h)
    let scaledAspect = scaledX/scaledY
    
    let fontSize = Int(ceil(size*scaledY / tool.pointsToScreenScale))
    guard fontSize < 100 && fontSize > 0 else {
      fatalError()
    }
    // Load the atlas
    let atlas = textAtlasses[fontSize] ?? createAtlas(fontSize)
    tool.bind(atlas.texture)

    // Calculate the total end size, for things like alignment
    let aspect = atlas.itemSize.aspect
    
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
    
    // Now, loop over every character individually
    for (i, char) in text.characters.map({String($0)}).enumerate() {
      if char == " " {
        continue
      }
      // Position this character
      let charMatrix = GLKMatrix4Translate(baseMatrix, GLfloat(i), 0, 0)
      tool.program.setModelView(charMatrix)
      
      // Retrieve, or create and get, the atlas entry
      let atlasRect : CGRect
      if let entrySource = atlas[char] {
        atlasRect = entrySource
      } else {
        // We need to render this ourselves.
        let tex = drawToTexture(char, size: fontSize)
        atlasRect = try! atlas.addItem(char, item: tex)
        tool.deleteTexture(tex)
      }

      tool.program.setUVProperties(
        xOffset: Float(atlasRect.origin.x), yOffset: Float(atlasRect.origin.y),
        xScale: Float(atlasRect.size.width), yScale: Float(atlasRect.size.height))
      tool.draw(tool.texturedSquare!)
    }
    return true
  }
}

class TextureAtlas {
  enum TextureAtlasError : ErrorType {
    case AtlasFull
  }
  private var tools : DrawingTools
  /// The framebuffer and texture used for atlas rendering
  private var framebuffer : Framebuffer
  /// The pixel size of a single item in the atlas
  private(set) var itemSize : Size2D<UInt>
  /// Precalculated rects for every item in the atlas
  private var items : [String : CGRect] = [:]
  private var atlasSize : Size2D<UInt>
  var slotsRemaining : UInt { return slotCount - UInt(items.count) }
  var slotCount : UInt { return UInt(atlasSize.w*atlasSize.h) }
  var texture : Texture { return framebuffer.texture }
  
  init(tools: DrawingTools, totalSize: Size2D<UInt>, itemSize: Size2D<UInt>)
  {
    self.tools = tools
    self.framebuffer = tools.createTextureFramebuffer(totalSize, depth: false, stencil: false)
    self.itemSize = itemSize
    // Calculate what item dimensions we can have
    atlasSize = Size2D(w: UInt(totalSize.w / itemSize.w),
                       h: UInt(totalSize.h / itemSize.h))
  }
  
  init(tools: DrawingTools, fromExistingAtlas: Texture,
    withItemSize: Size2D<Int>,
    andItems: [String],
    precalculatedUVSize: Size2D<Float>? = nil)
  {
    guard fromExistingAtlas.size != nil else {
      fatalError("Cannot create atlas from unknown texture size")
    }
    glPushGroupMarkerEXT(0, "Creating texture atlas")
    defer {
      glPopGroupMarkerEXT()
    }
    self.tools = tools
    atlasSize = Size2D(w: UInt(fromExistingAtlas.size!.w / withItemSize.w),
                       h: UInt(fromExistingAtlas.size!.h / withItemSize.h))
    // Build a new framebuffer from this texture
    framebuffer = tools.createFramebufferForTexture(fromExistingAtlas)
    self.itemSize = withItemSize.map {UInt($0)}

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
    for (index, item) in andItems.enumerate() {
      let indexX = UInt(index) % atlasSize.w
      let indexY = UInt(index) / atlasSize.w
      let xPos = itemSize.w*indexX
      let yPos = UInt(framebuffer.size.h) - (indexY + 1)*itemSize.h
      
      let cPos = CGRectMake(CGFloat(xPos), CGFloat(yPos), uvWidth, uvHeight)
      items[item] = cPos
    }
  }
  
  subscript (index: String) -> CGRect? {
    return items[index]
  }

  /** Add an item to the atlas texture.
  - parameters item       The texture to place in the atlas entry
  - parameters realAspect The *real* aspect ratio of the image, allowing for
                          e.g. fractional font sizes */
  func addItem(itemName: String, item: Texture, realAspect: Float = 1) throws -> CGRect {
    guard slotsRemaining > 0 else {
      throw TextureAtlasError.AtlasFull
    }
    glPushGroupMarkerEXT(0, "Adding item named " + itemName + " to atlas")
    defer {
      glPopGroupMarkerEXT()
    }
    tools.saveState()
    defer {
      tools.restoreState()
    }
    // Work out the next entries rect
    let index = slotCount-slotsRemaining
    let indexX = index % atlasSize.w
    let indexY = index / atlasSize.w
    let xPos = itemSize.w*indexX
    let yPos = UInt(framebuffer.size.h) - (indexY + 1)*itemSize.h
    
    // Scale the texture into the destination, retaining aspect ratio
    let fitScale = 1 / max(Float(item.size!.w) / Float(itemSize.w), Float(item.size!.h) / Float(itemSize.h))

    // Draw the texture into the atlas
    glPushGroupMarkerEXT(0, "Binding Buffer " + String(framebuffer.name))
    tools.bind(framebuffer, clear: false)
    glPopGroupMarkerEXT()
    tools.program.setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)
    tools.program.setModelView(GLKMatrix4Identity)
    
    let dr = FixedBounds(left: Float(xPos),
      bottom: Float(yPos),
      width: Float(item.size!.w)*fitScale,
      height: Float(item.size!.h)*fitScale)
    
    tools.setOrthProjection(left: 0, right: Float(framebuffer.size.w), bottom: 0, top: Float(framebuffer.size.h))
    
    tools.program.setColor(Color4.White)
    tools.bind(item)
    tools.DrawTexturedSquare(dr)
    
    // Scale the UVWidth to 1
    let uvScaled = Size2D(w: realAspect/itemSize.aspect, h: 1)

    // Add this entry to the index
    let origin = Point2D(x: Float(xPos)/Float(framebuffer.size.w),
                         y: Float(yPos)/Float(framebuffer.size.h))
    let itemBox = Size2D(w: Float(itemSize.w)/Float(framebuffer.size.w),
                         h: Float(itemSize.h)/Float(framebuffer.size.h))
    let result = CGRectMake(CGFloat(origin.x), CGFloat(origin.y),
      CGFloat(itemBox.w)*CGFloat(uvScaled.w),
      CGFloat(itemBox.h)*CGFloat(uvScaled.h))
    items[itemName] = result
    return result
  }
}

class DeferredAtlasRenderer : TextRenderer {
  private var parent : AtlasTextRenderer
  private var tools : DrawingTools
  var aspect : Float { return parent.aspect }
  var fontName : String { return parent.fontName }
  
  struct TextEntry {
    var text : String
    var size : GLfloat
    var position : Point2D
    var align : NSTextAlignment
    var rotation : GLfloat
    var transform : GLKMatrix4
  }
  var unprocessedEntries : [TextEntry] = []
  
  init(tools: DrawingTools, parent: AtlasTextRenderer) {
    self.parent = parent
    self.tools = tools
  }
  
  func draw(text: String, size : GLfloat, position : Point2D, align : NSTextAlignment, rotation: GLfloat, transform : GLKMatrix4)
  {
    unprocessedEntries.append(TextEntry(text: text, size: size, position: position, align: align, rotation: rotation, transform: transform))
  }
  
  func generateDrawable() -> Drawable? {
    guard !unprocessedEntries.isEmpty else {
      return nil
    }
    let maxSize = unprocessedEntries.map({$0.size}).maxElement()!
    // Generate an atlas for this
    let atlas = parent.createAtlas(Int(ceil(maxSize)))
    
    // Now generate every entry
    let triangles = unprocessedEntries.flatMap {self.trianglesFor($0, atlas: atlas)}
    return tools.LoadTriangles(triangles)
  }
  
  func trianglesFor(entry: TextEntry, atlas: TextureAtlas)
    -> [Triangle<TexturedPoint2D>]
  {
    let fontSize = Int(entry.size)
    
    // Work out the end size for the entry
    let entrySize = entry.size * Size2D(w: aspect*Float(entry.text.characters.count), h: 1)
    // Start from whatever extra transform we have been passed
    var baseMatrix = entry.transform
    // Now adjust the position
    baseMatrix = GLKMatrix4Translate(baseMatrix, entry.position.x, entry.position.y, 0)
    // And apply the alignment
    let offset : GLfloat
    switch(entry.align) {
    case .Right:
      offset = -entrySize.w
    case .Center:
      offset = -entrySize.w/2
    default:
      offset = 0
    }
    baseMatrix = GLKMatrix4Translate(baseMatrix, offset, 0, 0)
    // Apply the rotation
    baseMatrix = GLKMatrix4Rotate(baseMatrix, entry.rotation, 0, 0, 1)
    // Scale to match the shape and size of a single character
    baseMatrix = GLKMatrix4Scale(baseMatrix, entry.size, entry.size, 1)
    // Offset so that the text is center-aligned
    baseMatrix = GLKMatrix4Translate(baseMatrix, 0, -0.5, 0)
    
    // Loop over every character
    var triangles : [Triangle<TexturedPoint2D>] = []
    for (i, char) in entry.text.characters.map({String($0)}).enumerate() {
      if char == " " {
        continue
      }
      // calculate the matrix for positioning this character
      let charMatrix = GLKMatrix4Translate(baseMatrix, GLfloat(i), 0, 0)
      
      // Apply this to each of the vertex points
      let bL = charMatrix * GLKVector3Make(0, 0, 0)
      let bR = charMatrix * GLKVector3Make(1, 0, 0)
      let tL = charMatrix * GLKVector3Make(0, 1, 0)
      let tR = charMatrix * GLKVector3Make(1, 1, 0)
      
      // Work out the UV rect for this character
      let r : CGRect
      if let entrySource = atlas[char] {
        r = entrySource
      } else {
        let tex = parent.drawToTexture(char, size: fontSize)
        r = try! atlas.addItem(char, item: tex)
        tools.deleteTexture(tex)
      }
      
      let vtxBL = TexturedPoint2D(bL.x, bL.y, u: Float(r.minX), v: Float(r.minY))
      let vtxTL = TexturedPoint2D(tL.x, tL.y, u: Float(r.minX), v: Float(r.maxY))
      let vtxTR = TexturedPoint2D(tR.x, tR.y, u: Float(r.maxX), v: Float(r.maxY))
      let vtxBR = TexturedPoint2D(bR.x, bR.y, u: Float(r.maxX), v: Float(r.minY))
      
      // We now have enough information to build the triangles
      let TriA = Triangle<TexturedPoint2D>(vtxBR, vtxBL, vtxTL)
      let TriB = Triangle<TexturedPoint2D>(vtxBR, vtxTL, vtxTR)
      
      triangles.appendContentsOf([TriA, TriB])
    }
    
    return triangles
  }
}
