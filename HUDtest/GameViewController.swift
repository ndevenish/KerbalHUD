//
//  GameViewController.swift
//  HUDtest
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import GLKit
import OpenGLES


func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
  let p: UnsafePointer<Void> = nil
  return p.advancedBy(i)
}

let UNIFORM_MODELVIEWPROJECTION_MATRIX = 0
let UNIFORM_NORMAL_MATRIX = 1
let UNIFORM_COLOR = 2
let UNIFORM_USETEX = 3
var uniforms = [GLint](count: 4, repeatedValue: 0)
var meshes : [(offset: GLint, size: GLint)] = []

let MESH_SQUARE = 0
let MESH_TRIANGLE = 1
let MESH_HUD = 2

struct FlightData {
  var Pitch   : GLfloat = 0
  var Roll    : GLfloat = 0
  var Heading : GLfloat = 0
  
  var DeltaH  : GLfloat = 0
  var AtmHeight : GLfloat = 0
  var TerrHeight : GLfloat = 0
  var AtmPressure : GLfloat = 0
  var AtmPercent : GLfloat = 0
  
  var ThrottleSet : GLfloat = 0
  var ThrottleActual : GLfloat = 0
  var Speed : GLfloat = 0
  var AirSpeed : GLfloat = 0
  var HrzSpeed : GLfloat = 0
  
  var SAS : Bool = false
}

class GameViewController: GLKViewController, WebSocketDelegate {
  
  var program: GLuint = 0
  
  var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
  var projectionMatrix : GLKMatrix4 = GLKMatrix4Identity
  var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
  var rotation: Float = 0.0
  
  var texAttrib : GLint = 0
  var posAttrib : GLint = 0
  
  var vertexArray: GLuint = 0
  var vertexBuffer: GLuint = 0
  
  var texArray : GLuint = 0
  var texBuffer : GLuint = 0
  
  var context: EAGLContext? = nil
  
  var pointScale : GLfloat = 1
  
  var currentDH : GLfloat = 0

  var latestData : FlightData? = nil
  
  deinit {
    self.tearDownGL()
    
    if EAGLContext.currentContext() === self.context {
      EAGLContext.setCurrentContext(nil)
    }
  }
  
  var socket : WebSocket? = nil
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.context = EAGLContext(API: .OpenGLES2)
    
    if !(self.context != nil) {
      print("Failed to create ES context")
    }
    
    let view = self.view as! GLKView
    view.context = self.context!
//    view.drawableDepthFormat = .Format24
    view.drawableStencilFormat = .Format8
    
    self.setupGL()
    self.setupSocket()
  }
  
  func setupSocket()
  {
    socket = WebSocket(url: NSURL(string: "ws://192.168.1.73:8085/datalink")!)
    if let s = socket {
      s.delegate = self
      s.connect()
    } else {
      print("Error opening websocket")
    }
  }
  
  func websocketDidConnect(socket: WebSocket)
  {
    print ("Connected to socket!")
  }
  func websocketDidDisconnect(socket: WebSocket, error: NSError?)
  {
    latestData = nil
    if let err = error {
      print ("Error: \(err). Disconnected.")
    } else {
      print ("Disconnected.")
    }
    socket.connect()
  }
  func websocketDidReceiveMessage(socket: WebSocket, text: String)
  {
    print ("Recieved Message: \(text)")
  }
  func websocketDidReceiveData(socket: WebSocket, data: NSData)
  {
       print ("Received \(data.length)b of data")
  }

  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    if self.isViewLoaded() && (self.view.window != nil) {
      self.view = nil
      
      self.tearDownGL()
      
      if EAGLContext.currentContext() === self.context {
        EAGLContext.setCurrentContext(nil)
      }
      self.context = nil
    }
  }
  
  func setupGL() {
    EAGLContext.setCurrentContext(self.context)
    
    self.loadShaders()
    
//    glEnable(GLenum(GL_DEPTH_TEST))
    glGenVertexArrays(1, &vertexArray)
    glBindVertexArray(vertexArray)
    
    glGenBuffers(1, &vertexBuffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
    let vertexCount = gSquareVertexData.count + gTriangleData.count + gCenterHUD.count
//    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * vertexCount), &gSquareVertexData, GLenum(GL_STATIC_DRAW))

    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * vertexCount), nil, GLenum(GL_STATIC_DRAW))
    // Copy all data into the buffer
    glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, GLsizeiptr(sizeof(GLfloat)*gSquareVertexData.count), &gSquareVertexData)
    meshes.append((0, GLint(gSquareVertexData.count/3)))
    
//    copy_to_buffer(gSquareVertexData, offset: 0)
//    copy_to_buffer(gTriangleData, offset: gSquareVertexData.count)
//    copy_to_buffer(gCenterHUD, offset: gSquareVertexData.count + gTriangleData.count)
    
//    
    glBufferSubData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*gSquareVertexData.count,
      GLsizeiptr(sizeof(GLfloat)*gTriangleData.count), &gTriangleData)
    meshes.append((meshes.last!.size, GLint(gTriangleData.count/3)))

    glBufferSubData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*(gSquareVertexData.count + gTriangleData.count),
      GLsizeiptr(sizeof(GLfloat)*gCenterHUD.count), &gCenterHUD)
    meshes.append((meshes.last!.size+meshes.last!.offset, GLint(gCenterHUD.count/3)))
//
    glEnableVertexAttribArray(GLuint(posAttrib))
    glVertexAttribPointer(GLuint(posAttrib), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 12, BUFFER_OFFSET(0))
//    glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Normal.rawValue))
//    glVertexAttribPointer(GLuint(GLKVertexAttrib.Normal.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))
    glBindVertexArray(0);
    
    glGenVertexArrays(1, &texArray)
    glBindVertexArray(texArray)
    glGenBuffers(1, &texBuffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), texBuffer)
    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * gTextureSquareVertexData.count),
      &gTextureSquareVertexData, GLenum(GL_STATIC_DRAW))
    glEnableVertexAttribArray(GLuint(posAttrib))
    glVertexAttribPointer(GLuint(posAttrib), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 20, BUFFER_OFFSET(0))
    glEnableVertexAttribArray(GLuint(texAttrib))
    glVertexAttribPointer(GLuint(texAttrib), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 20, BUFFER_OFFSET(12))
    
    glBindVertexArray(0);
  }
  
  func tearDownGL() {
    EAGLContext.setCurrentContext(self.context)
    
    glDeleteBuffers(1, &vertexBuffer)
    glDeleteVertexArrays(1, &vertexArray)
    
    if program != 0 {
      glDeleteProgram(program)
      program = 0
    }
  }
  
  // MARK: - GLKView and GLKViewController delegate methods
  
  func update() {
    let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
//    let projectionMatrix : GLKMatrix4
    if aspect > 1 {
      let edge = (aspect-1)*0.5
      projectionMatrix = GLKMatrix4MakeOrtho(-edge, 1+edge, 0, 1, -10, 10)
      pointScale = GLfloat(self.view.bounds.size.height)
    } else {
      let edge = (1.0/aspect - 1)*0.5
      projectionMatrix = GLKMatrix4MakeOrtho(0, 1, -edge, 1+edge, -10, 10)
      pointScale = GLfloat(self.view.bounds.size.width)
    }
    
    let baseModelViewMatrix = GLKMatrix4Identity;

    // Compute the model view matrix for the object rendered with ES2
    var modelViewMatrix = GLKMatrix4MakeTranslation(0,0,0)
//    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotation, 1.0, 1.0, 1.0)
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)
    
//    normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), nil)
    
    modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
    
  }
  
  func drawSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
  {
    glBindVertexArray(vertexArray)
    
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    let mesh = meshes[MESH_SQUARE]
    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)

  }

  func drawLine(  from  : (x: GLfloat, y: GLfloat),
                      to: (x: GLfloat, y: GLfloat),
                  width : GLfloat,
             transform  : GLKMatrix4 = GLKMatrix4Identity) {
    let width = width / pointScale
    glBindVertexArray(vertexArray)
              
    // Calculate the rotation for this vector
    let rotation_angle = atan2(to.y-from.y, to.x-from.x)

    let length = sqrt(pow(to.y-from.y, 2) + pow(to.x-from.x, 2))
    var baseMatrix = transform
    baseMatrix = GLKMatrix4Translate(baseMatrix, from.x, from.y, 0.1)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, (0.5*3.1415926)-rotation_angle, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, width, length, 1)
    baseMatrix = GLKMatrix4Translate(baseMatrix, -0.5, 0, 0)
    
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    let mesh = meshes[MESH_SQUARE]
    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)
  }
  
  func drawTriangle(point : (x: GLfloat, y: GLfloat), rotation : GLfloat, height : GLfloat)
  {
//    let height = height / pointScale
    glBindVertexArray(vertexArray)
    
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, point.x, point.y, 0.1)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, rotation, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, height, height, 1)
    
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    let mesh = meshes[MESH_TRIANGLE]
    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)
  }
  
  func constrainDrawing(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
  {
    glEnable(GLenum(GL_STENCIL_TEST))
    glStencilFunc(GLenum(GL_ALWAYS), 1, 0xFF)
    glStencilOp(GLenum(GL_KEEP), GLenum(GL_KEEP), GLenum(GL_REPLACE))
    glColorMask(GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE))
    glStencilMask(0xFF)
    glClear(GLenum(GL_STENCIL_BUFFER_BIT))

    drawSquare(left, bottom: bottom, right: right, top: top)

    glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
    
    glStencilFunc(GLenum(GL_EQUAL), 1, 0xFF)
    // Prevent further writing to the stencil from this point
    glStencilMask(0x00);
  }
  func unconstrainDrawing() {
    glDisable(GLenum(GL_STENCIL_TEST))
  }
  
  func drawHUDCenter() {
    glBindVertexArray(vertexArray)
    
//    let hudOff = (gSquareVertexData.count + gTriangleData.count)/3
    var baseMatrix = GLKMatrix4MakeTranslation(0.5, 0.5, 0)
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    let mesh = meshes[MESH_HUD]
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), mesh.offset, mesh.size)
//    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(hudOff), GLint(gCenterHUD.count/3))
    baseMatrix = GLKMatrix4Scale(baseMatrix, -1, 1, 1)
    mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), mesh.offset, mesh.size)
  }
  
  func PseudoLog10(x : Double) -> Double
  {
    
    if abs(x) <= 1.0 {
      return x
    }
    return (1.0 + log10(abs(x))) * sign(x)
  }
  
  func InversePseudoLog10(x : Double) -> Double
  {
    if abs(x) <= 1.0 {
      return x
    }
    return pow(10, abs(x)-1)*sign(x)
  }
  
  override func glkView(view: GLKView, drawInRect rect: CGRect) {
    
    currentDH += 0.01
//
//    latestData = FlightData()
//    
//    latestData!.DeltaH = currentDH
//    latestData!.Pitch = currentDH*2
//    latestData!.Roll = currentDH*5
//    latestData!.Heading = currentDH*5
//    latestData!.AtmHeight = currentDH*10
//    
    
    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    
    glBindVertexArray(vertexArray)
    
    glUseProgram(program)

    glUniform3f(uniforms[UNIFORM_COLOR], 0.0, 1.0, 0.0)

//    let thick : GLfloat = 1.0
//    let thin  : GLfloat = 0.5

    if let data = latestData {
      constrainDrawing(0.25, bottom: 0.25, right: 0.75, top: 0.75)
      drawPitchDisplay(data.Pitch,roll: data.Roll)

      constrainDrawing(0.0, bottom: 0.25, right: 1.0, top: 0.75)
      drawLogDisplay(data.DeltaH, left: true)
      drawLogDisplay(data.AtmHeight, left: false)
      
      // Draw the heading indicator
      constrainDrawing(0.25, bottom: 0.25, right: 0.75, top: 1)
      drawHeadingDisplay(data.Heading)
      
      unconstrainDrawing()
    }


    drawHUDCenter()
    
    // Log display lines
    drawLine((0.25,0.25), to:(0.25,0.75), width: 1)
    drawLine((0.75,0.25), to:(0.75,0.75), width: 1)
    
    // Line across and triangles for HUD display
    drawLine((0.25,0.5), to: (0.75,0.5), width: 0.5)
    drawTriangle((0.25, 0.5), rotation: 3.1415926/2, height: 0.03125)
    drawTriangle((0.75, 0.5), rotation: -3.1415926/2, height: 0.03125)
    drawTriangle((0.5, 0.75), rotation: 3.1415926, height: 0.03125)

    
    
    // Fixed text
    drawText("PRS:", align: .Left, position: (0.025, 1-0.075), fontSize: 16)
    drawText("ATM:", align: .Left, position: (0.025, 1-(0.075+0.05)), fontSize: 16)

    drawText("ASL:", align: .Right, position: (0.75, 1-0.075), fontSize: 16)
    drawText("TER:", align: .Right, position: (0.75, 1-(0.075+0.05)), fontSize: 16)

    drawText("SPD:", align: .Left, position: (0.025, 0.025+3*0.05), fontSize: 16)
    drawText("EAS:", align: .Left, position: (0.025, 0.025+2*0.05), fontSize: 16)
    drawText("HRZ:", align: .Left, position: (0.025, 0.025+0.05), fontSize: 16)
    drawText("THR:", align: .Left, position: (0.025, 0.025), fontSize: 16)
    
    if let data = latestData {
      drawText(String(format:"%.3fkPa", data.AtmPressure), align: .Right, position: (0.4, 1-0.075), fontSize: 16)
      drawText(String(format:"%.1f%%", data.AtmPercent), align: .Right, position: (0.27, 1-(0.075+0.05)), fontSize: 16)
      
      drawText(String(format:"%.0fm", data.AtmHeight), align: .Right, position: (0.925, 1-0.075), fontSize: 16)
      drawText(String(format:"%.0fm", data.TerrHeight), align: .Right, position: (0.925, 1-(0.075+0.05)), fontSize: 16)
      
      drawText(String(format:"%.0fm/s", data.Speed), align: .Right, position: (0.37, 0.025+3*0.05), fontSize: 16)
      drawText(String(format:"%.0fm/s", data.AirSpeed), align: .Right, position: (0.37, 0.025+2*0.05), fontSize: 16)
      drawText(String(format:"%.0fm/s", data.HrzSpeed), align: .Right, position: (0.37, 0.025+0.05), fontSize: 16)
      drawText(String(format:"%5.1f%% [%5.1f%%]", data.ThrottleSet, data.ThrottleActual), align: .Right, position: (0.52, 0.025), fontSize: 16)

      drawText(String(format:"%05.1f˚", data.Heading), align: .Center, position: (0.5, 0.75+0.05+0.025), fontSize: 16)
      drawText(String(format:"P:  %05.1f˚ R:  %05.1f˚", data.Pitch, data.Roll), align: .Center,
        position: (0.5, 0.25-10.0/pointScale), fontSize: 10)
    } else {
      glUniform3f(uniforms[UNIFORM_COLOR], 1.0, 0.0, 0.0)
      
      if let sock = socket {
        if !sock.isConnected {
          drawText("CONNECTING TO \(sock.url.host!):\(sock.url.port!)",
            align: .Right, position: (1-0.05, 0.05), fontSize: 20)
        }
      }
      drawText("NO DATA", align: .Center, position: (0.5, 0.2), fontSize: 20)
    }
    // Indicators
//    drawText("GEAR", align: .Right, position: (0.17,  1-0.325), fontSize: 16)
//    drawText("SAS", align: .Right, position: (0.17,   1-(0.325+0.05)), fontSize: 16)
//    drawText("LIGHT", align: .Right, position: (0.17, 1-(0.325+2*0.05)), fontSize: 16)
//    drawText("0", align: .Left, position: (0,0), fontSize: 20)
    
    // 8 =  0.0125
    // 16 = 0.025
    // 32 = 0.05

    // Delete any unused text textures
//    print ("Removing \(textCache.count-usedText.count) textures")
    
    for i in (0..<textCache.count).reverse() {
      if usedText.contains(i) { continue }
//      print ("Removing \(textCache[i].text)/\(textCache[i].size)")
      var name = textCache[i].texture.name
      glDeleteTextures(1, &name)
      textCache.removeAtIndex(i)
    }
    usedText.removeAll()
  }

  struct TextEntry {
    let text : String
    let size : GLfloat
    let texture : GLKTextureInfo
  }
  var textCache : [TextEntry] = []
  var usedText : Set<Int> = []
  
  
  func drawText(text: String, align : NSTextAlignment, position : (x: GLfloat, y: GLfloat), fontSize : GLfloat,
    rotate: GLfloat = 0, transform : GLKMatrix4 = GLKMatrix4Identity) {
    
    let texture : GLKTextureInfo

    var matchIndex : Optional<Int> = nil
    // Look for an entry in the cache with this string and font size
    for (index, entry) in textCache.enumerate() {
      if entry.size == fontSize && entry.text == text {
        matchIndex = index
        break
      }
    }
      
    if let index = matchIndex {
      texture = textCache[index].texture
      usedText.insert(index)
    } else {
      // Let's work out the font size we want, approximately
      let font = UIFont(name: "Menlo", size: CGFloat(fontSize))!
      let attrs = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor()]
      
      let nsString: NSString = text as NSString
      let size: CGSize = nsString.sizeWithAttributes(attrs)
      UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
      let context = UIGraphicsGetCurrentContext()
      nsString.drawAtPoint(CGPoint(x: 0, y: 0), withAttributes: attrs)
      let image = CGBitmapContextCreateImage(context)!
      UIGraphicsEndImageContext()
      
      do {
        texture = try GLKTextureLoader.textureWithCGImage(image, options: nil)
        textCache.append(TextEntry(text: text, size: fontSize, texture: texture))
        usedText.insert(textCache.count-1)
      } catch {
        print("ERROR generating texture")
        return
      }
    }
    glBindVertexArray(texArray)
    glBindTexture(texture.target, texture.name)
    
    // work out how tall we want it.
    let squareHeight = GLfloat(fontSize) / pointScale
    let squareWidth = squareHeight * GLfloat(texture.width)/GLfloat(texture.height)
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
    
    //      baseMatrix = GLKMatrix4Translate(baseMatrix, position.x - (left ? 0 : squareWidth), position.y, 0)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, rotate, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, squareWidth, squareHeight, 1)
    baseMatrix = GLKMatrix4Translate(baseMatrix, 0, -0.5, 0)
    
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    glUniform1i(uniforms[UNIFORM_USETEX], 1)
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0,4)
    
    glUniform1i(uniforms[UNIFORM_USETEX], 0)
  }
  
  func drawHeadingDisplay(heading : Float)
  {
    let minAngle = Int(floor((heading - 27.5)/10))*10
    let maxAngle = Int(ceil((heading + 27.5)/10))*10

    for var angle = minAngle; angle <= maxAngle; angle += 10 {
      let x = (Float(angle) - (heading - 27.5)) / 55.0
      let height = angle % 20 == 0 ? 0.025 : 0.025*0.75
      drawLine((0.25+x/2, 0.75), to: (0.25+x/2, GLfloat(0.75+height)), width: 1)
    }
    for var angle = minAngle; angle <= maxAngle; angle += 10 {
      if angle % 20 != 0 {
        continue
      }
      let x = (Float(angle) - (heading - 27.5)) / 55.0
//      drawLine((0.25+x/2, 0.75), to: (0.25+x/2, GLfloat(0.75+height)), width: 1)
      drawText(String(format:"%d", angle), align: .Center, position: (0.25+x/2, 0.75+0.025+0.0125), fontSize: 10)
    }
  }
  
  func drawPitchDisplay(pitch : Float, roll : Float)
  {
    let minAngle = Int(floor((pitch - 67.5)/10))*10
    let maxAngle = Int(ceil((pitch + 67.5)/10))*10
    let offset = pitch / 90 / 2
    // Build a transform to apply to all lines putting it in the right area
    var pitchT = GLKMatrix4Identity
    pitchT = GLKMatrix4Translate(pitchT, 0.5, 0.5, 0)
    pitchT = GLKMatrix4Rotate(pitchT, roll*3.1415926/180, 0, 0, -1)
    pitchT = GLKMatrix4Translate(pitchT, 0, -offset, 0)

    for var angle = minAngle; angle <= maxAngle; angle += 5 {
      let x : GLfloat
      if angle % 20 == 0 {
        x = 0.1
      } else if angle % 10 == 0 {
        x = 0.05
      } else {
        x = 0.5*0.025
      }

      // Scale 0->90 to 0->1, then 0->0.5
      let y : GLfloat = (GLfloat(angle))/90*0.5
      drawLine((-x, y), to: (x, y), width: 1, transform: pitchT)
    }
    for var angle = minAngle; angle <= maxAngle; angle += 10 {
      if angle % 20 != 0 {
        continue
      }
      
      // Scale 0->90 to 0->1, then 0->0.5
      let y : GLfloat = (GLfloat(angle))/90*0.5
      drawText(String(format: "%d", angle), align: .Left, position: (0.1125, y),
        fontSize: (angle == 0 ? 16 : 8), rotate: 0, transform: pitchT)
      drawText(String(format: "%d", angle), align: .Left, position: (-0.1125, y),
        fontSize: (angle == 0 ? 16 : 8), rotate: 3.1415926, transform: pitchT)
      
//      drawLine((-x, y), to: (x, y), width: 1, transform: pitchT)
    }

  }
  
  func drawLogDisplay(value : Float, left : Bool)
  {
    let xPos : GLfloat = left ? 0.25 : 0.75

    let lgeTickSize : GLfloat = 0.025 * (left ? -1 : 1)
    let medTickSize = lgeTickSize / 2
    let smlTickSize = medTickSize / 2
    
    let center = PseudoLog10(Double(value))
    // Calculate the minimum and maximum of the log range to draw
    let logRange = left ? 4 : 4.6
    var logMin = Int(floor(center)-logRange/2)
    var logMax = Int(ceil(center)+logRange/2)
    if !left {
      logMin = max(0, logMin)
      logMax = min(4, logMax)
    }
    let bottom = center - logRange / 2
//    let top    = center + logRange / 2
    // Draw the major marks
    for power in logMin...logMax {
      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
      drawLine((xPos,y), to: (xPos+GLfloat(lgeTickSize), y), width: 1)
      
      var nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
      let halfPoint = PseudoLog10(nextPow*0.5)
      y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
      drawLine((xPos,y), to: (xPos+GLfloat(medTickSize), y), width: 1)

      nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
      let doubPoint = PseudoLog10(nextPow*0.1*2)
      y = 0.25 + 0.5 * GLfloat((doubPoint-bottom)/logRange)
      drawLine((xPos,y), to: (xPos+GLfloat(smlTickSize), y), width: 1)
    }
    // Draw text in a separate pass
    for power in logMin...logMax {
      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
      var txt = NSString(format: "%.0f", InversePseudoLog10(Double(power)))
      drawText(txt as String, align: left ? .Right : .Left, position: (xPos + lgeTickSize * 1.25, y), fontSize: 12)
      
      let nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
      let halfPoint = PseudoLog10(nextPow*0.5)
      y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
      if abs(nextPow) == 1 {
        txt = NSString(format: "%.1f", nextPow*0.5)
      } else {
        txt = NSString(format: "%.0f", nextPow*0.5)
      }
      drawText(txt as String, align: left ? .Right : .Left, position: (xPos + medTickSize * 1.25, y), fontSize: 9)
    }
    
  }
  
  // MARK: -  OpenGL ES 2 shader compilation
  
  func loadShaders() -> Bool {
    var vertShader: GLuint = 0
    var fragShader: GLuint = 0
    var vertShaderPathname: String
    var fragShaderPathname: String
    
    // Create shader program.
    program = glCreateProgram()
    
    // Create and compile vertex shader.
    vertShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")!
    if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
      print("Failed to compile vertex shader")
      return false
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh")!
    if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
      print("Failed to compile fragment shader");
      return false
    }
    
    // Attach vertex shader to program.
    glAttachShader(program, vertShader)
    
    // Attach fragment shader to program.
    glAttachShader(program, fragShader)
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
//    glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
//    glBindAttribLocation(program, GLuint(GLKVertexAttrib.TexCoord0.rawValue), "texcoord")
    
    
//    glBindAttribLocation(program, GLuint(GLKVertexAttrib.Normal.rawValue), "normal")
    
    // Link program.
    if !self.linkProgram(program) {
      print("Failed to link program: \(program)")
      
      if vertShader != 0 {
        glDeleteShader(vertShader)
        vertShader = 0
      }
      if fragShader != 0 {
        glDeleteShader(fragShader)
        fragShader = 0
      }
      if program != 0 {
        glDeleteProgram(program)
        program = 0
      }
      
      return false
    }
    
    posAttrib = glGetAttribLocation(program, "position")
    texAttrib = glGetAttribLocation(program, "texcoord")

    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
    uniforms[UNIFORM_COLOR] = glGetUniformLocation(program, "color")
    uniforms[UNIFORM_USETEX] = glGetUniformLocation(program, "useTex")
//    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(program, "normalMatrix")
    
    // Release vertex and fragment shaders.
    if vertShader != 0 {
      glDetachShader(program, vertShader)
      glDeleteShader(vertShader);
    }
    if fragShader != 0 {
      glDetachShader(program, fragShader);
      glDeleteShader(fragShader);
    }
    
    return true
  }
  
  
  func compileShader(inout shader: GLuint, type: GLenum, file: String) -> Bool {
    var status: GLint = 0
    var source: UnsafePointer<Int8>
    do {
      source = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding).UTF8String
    } catch {
      print("Failed to load vertex shader")
      return false
    }
    var castSource = UnsafePointer<GLchar>(source)
    
    shader = glCreateShader(type)
    glShaderSource(shader, 1, &castSource, nil)
    glCompileShader(shader)
    
    //#if defined(DEBUG)
    //    var logLength: GLint = 0
    //    glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength);
    //    if logLength > 0 {
    //      var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
    //      glGetShaderInfoLog(shader, logLength, &logLength, log);
    //      NSLog("Shader compile log: \n%s", log);
    //      free(log)
    //    }
    //#endif
    
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
    if status == 0 {
      glDeleteShader(shader);
      return false
    }
    return true
  }
  
  func linkProgram(prog: GLuint) -> Bool {
    var status: GLint = 0
    glLinkProgram(prog)
    
    //#if defined(DEBUG)
    //    var logLength: GLint = 0
    //    glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength);
    //    if logLength > 0 {
    //      var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
    //      glGetShaderInfoLog(shader, logLength, &logLength, log);
    //      NSLog("Shader compile log: \n%s", log);
    //      free(log)
    //    }
    //#endif
    
    glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
    if status == 0 {
      return false
    }
    
    return true
  }
  
  func validateProgram(prog: GLuint) -> Bool {
    var logLength: GLsizei = 0
    var status: GLint = 0
    
    glValidateProgram(prog)
    glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    if logLength > 0 {
      var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
      glGetProgramInfoLog(prog, logLength, &logLength, &log)
      print("Program validate log: \n\(log)")
    }
    
    glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
    var returnVal = true
    if status == 0 {
      returnVal = false
    }
    return returnVal
  }
}

var gSquareVertexData: [GLfloat] = [
  0,0,0,
  0,1,0,
  1,1,0,
  1,1,0,
  1,0,0,
  0,0,0,
]

var gTextureSquareVertexData : [GLfloat] = [
  0,0,0,0,1,
  0,1,0,0,0,
  1,0,0,1,1,
  1,1,0,1,0
]
// Equilateral triangle with height 1, facing up, with point at 0,0
var gTriangleData : [GLfloat] = [
  0,0,0,
  0.625,-1,0,
  -0.625,-1,0,
]

func openSemiCircle(r : GLfloat, w : GLfloat) -> [(x: GLfloat, y: GLfloat)]
{
  var points : [(x: GLfloat, y: GLfloat)] = []
  let Csteps = 20
  let innerR = r - w/2
  let outerR = r + w/2
  
  for step in 0...Csteps {
    let theta = GLfloat((3.1415926/Double(Csteps))*Double(step))
    points.append((innerR*sin(theta), innerR*cos(theta)))
    points.append((outerR*sin(theta), outerR*cos(theta)))
  }
  return points
}

func crossHair(H : GLfloat, J : GLfloat, w : GLfloat, theta : GLfloat) -> [GLfloat]
{
  var points : [(x: GLfloat, y: GLfloat)] = []
  let m = sin(theta)/cos(theta)
  
  points.append((w/2,-H-J))
  points.append((  0,-H-J))
  points.append((w/2,m*w/2 - H - w/cos(theta)))
  points.append((0,-H))
  points.append((m*(H+w/cos(theta)-w/2),-w/2))
  points.append((m*(H+w/2),w/2))

  // W - the point the open box starts
  let W : GLfloat = 41.0
  points.append((W, -w/2))
  points.append((W, w/2))
  
  // B : Box Width
  // Bh : Box Height
  let B : GLfloat = 70
  let Bh : GLfloat = 17
  let BiY = (Bh-2*w)*0.5
//  points.append((W+w, -BiX))
  points.append((W+w,  BiY))
  points.append((W, Bh/2))    // 10
  points.append((W+B-w, BiY)) // 11
  points.append((W+B, Bh/2))  // 12
  points.append((W+B-w, -BiY)) // 13
  points.append((W+B, -Bh/2))  // 14
  points.append((W+w,  -BiY)) // 15
  points.append((W, -Bh/2))    // 16
  points.append((W+w,  BiY)) // 17
  points.append((W, -w/2)) // 18
  
  appendTriangleStrip(&points, with: boxPoints(0, bottom: 24, right: w/2, top: H+J))
  appendTriangleStrip(&points, with: openSemiCircle(5, w: 2.5))
  
  return pointsTo3DVertices(points)
}

func boxPoints(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) -> [(x: GLfloat, y: GLfloat)]
{
  return [
    (left, top),
    (right, top),
    (left, bottom),
    (right, bottom)
  ]
}

func appendTriangleStrip(inout points : [(x: GLfloat, y: GLfloat)], with : [(x: GLfloat, y: GLfloat)])
{
  points.append(points.last!)
  points.append(with.first!)
  points.extend(with)
}

func pointsTo3DVertices(points : [(x: GLfloat, y: GLfloat)]) -> [GLfloat]
{
  var flts : [GLfloat] = []
  for p in points {
    flts.append(p.x / 640)
    flts.append(p.y / 640)
    flts.append(0.0)
  }
  return flts
}

var gCenterHUD : [GLfloat] = crossHair(16, J: 68, w: 5, theta: 0.7243116395776468)
