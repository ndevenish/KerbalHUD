//
//  GameViewController.swift
//  KerbalHUD
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
let MESH_PROGRADE = 3

//struct FlightData {
//  var Pitch   : GLfloat = 0
//  var Roll    : GLfloat = 0
//  var Heading : GLfloat = 0
//  
//  var DeltaH  : GLfloat = 0
//  var AtmHeight : GLfloat = 0
//  var TerrHeight : GLfloat = 0
//  var RadarHeight : GLfloat = 0
//  var DynPressure : GLfloat = 0
//  var AtmPercent : GLfloat = 0
//  var AtmDensity : GLfloat = 0
//  var ThrottleSet : GLfloat = 0
//  var ThrottleActual : GLfloat = 0
//  var Speed : GLfloat = 0
//  var EASpeed : GLfloat = 0
//  var HrzSpeed : GLfloat = 0
//  var SurfaceVelocity : (x: GLfloat, y: GLfloat, z: GLfloat) = (0,0,0)
//  var SAS : Bool = false
//  var Gear : Bool = false
//  var Lights : Bool = false
//  var Brake : Bool = false
//  var RCS : Bool = false
//  
//  var HeatAlarm : Bool = false
//  var GroundAlarm : Bool = false
//  var SlopeAlarm : Bool = false
//  
//  var RPMVariablesAvailable : Bool = false
//}

class GameViewController: GLKViewController, WebSocketDelegate {
  
//  var program: GLuint = 0
  var program : ShaderProgram?
  var drawing : DrawingTools?
  
//  var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
//  var projectionMatrix : GLKMatrix4 = GLKMatrix4Identity
//  var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
//  var rotation: Float = 0.0
//  
//  var texAttrib : GLint = 0
//  var posAttrib : GLint = 0
//  
  var vertexArray: GLuint = 0
  var vertexBuffer: GLuint = 0
//
//  var texArray : GLuint = 0
//  var texBuffer : GLuint = 0
  
  var context: EAGLContext? = nil
  
//  var pointScale : GLfloat = 1
  
//  var currentDH : GLfloat = 0

//  var latestData : FlightData? = nil
  
  var display : Instrument?
  
  var square : Drawable2D?
  
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

    if let APIvars = display?.variables {
      let APIcodeString = ",".join(APIvars.map({ "\"" + $0 + "\"" }))
      socket.writeString("{\"+\":[" + APIcodeString + "],\"rate\": 0}")
    } else {
      print("Connected to server, but no instrument active")
    }
  }
  func websocketDidDisconnect(socket: WebSocket, error: NSError?)
  {
    if let err = error {
      print ("Error: \(err). Disconnected.")
    } else {
      print ("Disconnected.")
    }
    print ("Attempting connection again..")
    socket.connect()
  }
  func websocketDidReceiveMessage(socket: WebSocket, text: String)
  {
//    print ("Recieved Message: \(text)")
    let json = JSON(data: text.dataUsingEncoding(NSUTF8StringEncoding)!)
    if let inst = display {
      // Convert the JSON into a dictionary
      inst.update(json.dictionaryValue)
    }
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
    
    program = ShaderProgram()
    drawing = DrawingTools(shaderProgram: program!)
    
    display = RPMPlaneHUD(tools: drawing!)

    //    glEnable(GLenum(GL_DEPTH_TEST))

//    var squareVertexData: [GLfloat] = [
//      0,0,
//      0,1,
//      1,1,
//      1,1,
//      1,0,
//      0,0,
//    ]

//    let sqVpoints : [Point2D] = [
//      (0,0),(0,1),(1,1),(1,1),(1,0),(0,0)
//    ]
//    square = drawing!.LoadVertices(VertexRepresentation.Triangles, vertices: sqVpoints)
    
//    glGenBuffers(1, &vertexBuffer)
//    glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
//    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * squareVertexData.count), &squareVertexData, GLenum(GL_STATIC_DRAW))
//    
//    glGenVertexArrays(1, &vertexArray)
//    glBindVertexArray(vertexArray)
//    glEnableVertexAttribArray(program!.attributes.position)
//    glVertexAttribPointer(program!.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 8, BUFFER_OFFSET(0))
//    glBindVertexArray(0);
//    
  }
  
  func tearDownGL() {
    EAGLContext.setCurrentContext(self.context)
    
//    glDeleteBuffers(1, &vertexBuffer)
//    glDeleteVertexArrays(1, &vertexArray)
    
  }
  
  // MARK: - GLKView and GLKViewController delegate methods
  
  func update() {
    let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
    let drawWidth = display?.screenWidth ?? 1.0
    let drawHeight = display?.screenHeight ?? 1.0
    
    if aspect > 1 {
      let edge = (aspect-1)*0.5
      program!.projection = GLKMatrix4MakeOrtho(-edge*drawWidth, (1+edge)*drawWidth, 0, drawHeight, -10, 10)
    } else {
      let edge = (1.0/aspect - 1)*0.5
      program!.projection = GLKMatrix4MakeOrtho(0, drawWidth, (-edge)*drawHeight, (1+edge)*drawHeight, -10, 10)
    }
  }
  
//  func drawSquare(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
//  {
//    glBindVertexArray(vertexArray)
//    
//    var baseMatrix = GLKMatrix4Identity
//    baseMatrix = GLKMatrix4Translate(baseMatrix, left, bottom, 0.1)
//    baseMatrix = GLKMatrix4Scale(baseMatrix, right-left, top-bottom, 1)
//    let mvp = GLKMatrix4Multiply(program!.projection, baseMatrix)
//    program!.setModelViewProjection(mvp)
//    glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
//  }
  
//
//  func drawLine(  from  : (x: GLfloat, y: GLfloat),
//                      to: (x: GLfloat, y: GLfloat),
//                  width : GLfloat,
//             transform  : GLKMatrix4 = GLKMatrix4Identity) {
//    let width = width / pointScale
//    glBindVertexArray(vertexArray)
//              
//    // Calculate the rotation for this vector
//    let rotation_angle = atan2(to.y-from.y, to.x-from.x)
//
//    let length = sqrt(pow(to.y-from.y, 2) + pow(to.x-from.x, 2))
//    var baseMatrix = transform
//    baseMatrix = GLKMatrix4Translate(baseMatrix, from.x, from.y, 0.1)
//    baseMatrix = GLKMatrix4Rotate(baseMatrix, (0.5*3.1415926)-rotation_angle, 0, 0, -1)
//    baseMatrix = GLKMatrix4Scale(baseMatrix, width, length, 1)
//    baseMatrix = GLKMatrix4Translate(baseMatrix, -0.5, 0, 0)
//    
//    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    let mesh = meshes[MESH_SQUARE]
//    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)
//  }
//  
//  func drawTriangle(point : (x: GLfloat, y: GLfloat), rotation : GLfloat, height : GLfloat)
//  {
////    let height = height / pointScale
//    glBindVertexArray(vertexArray)
//    
//    var baseMatrix = GLKMatrix4Identity
//    baseMatrix = GLKMatrix4Translate(baseMatrix, point.x, point.y, 0.1)
//    baseMatrix = GLKMatrix4Rotate(baseMatrix, rotation, 0, 0, -1)
//    baseMatrix = GLKMatrix4Scale(baseMatrix, height, height, 1)
//    
//    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    let mesh = meshes[MESH_TRIANGLE]
//    glDrawArrays(GLenum(GL_TRIANGLES), mesh.offset, mesh.size)
//  }
//  
//  func constrainDrawing(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat)
//  {
//    glEnable(GLenum(GL_STENCIL_TEST))
//    glStencilFunc(GLenum(GL_ALWAYS), 1, 0xFF)
//    glStencilOp(GLenum(GL_KEEP), GLenum(GL_KEEP), GLenum(GL_REPLACE))
//    glColorMask(GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE))
//    glStencilMask(0xFF)
//    glClear(GLenum(GL_STENCIL_BUFFER_BIT))
//
//    drawSquare(left, bottom: bottom, right: right, top: top)
//
//    glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
//    
//    glStencilFunc(GLenum(GL_EQUAL), 1, 0xFF)
//    // Prevent further writing to the stencil from this point
//    glStencilMask(0x00);
//  }
//  func unconstrainDrawing() {
//    glDisable(GLenum(GL_STENCIL_TEST))
//  }
//  
//  func drawHUDCenter() {
//    glBindVertexArray(vertexArray)
//        var baseMatrix = GLKMatrix4MakeTranslation(0.5, 0.5, 0)
//    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    let mesh = meshes[MESH_HUD]
//    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), mesh.offset, mesh.size)
//    baseMatrix = GLKMatrix4Scale(baseMatrix, -1, 1, 1)
//    mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), mesh.offset, mesh.size)
//  }
//  
//  func drawPrograde(x: GLfloat, y: GLfloat) {
//    glBindVertexArray(vertexArray)
//    
//    let baseMatrix = GLKMatrix4MakeTranslation(x, y, 0)
//
//    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    let mesh = meshes[MESH_PROGRADE]
//
//    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), mesh.offset, mesh.size)
//  }
//  
//  func PseudoLog10(x : Double) -> Double
//  {
//    
//    if abs(x) <= 1.0 {
//      return x
//    }
//    return (1.0 + log10(abs(x))) * sign(x)
//  }
//  
//  func InversePseudoLog10(x : Double) -> Double
//  {
//    if abs(x) <= 1.0 {
//      return x
//    }
//    return pow(10, abs(x)-1)*sign(x)
//  }
  
  override func glkView(view: GLKView, drawInRect rect: CGRect) {

    // TODO: Replace this with fake server-side data
//    if let s = socket {
//      if !s.isConnected {
//        currentDH += 0.01
//
//        latestData = FlightData()
//        
//        latestData!.DeltaH = currentDH
//        latestData!.Pitch = currentDH*2
//        latestData!.Roll = currentDH*5
//        latestData!.Heading = currentDH*5
//        latestData!.AtmHeight = 1000+currentDH*10
//      }
//    }
    
    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    
//    glBindVertexArray(vertexArray)
    
    if let program = program {
      program.use()
      program.setColor(red: 0, green: 1, blue: 0)
      program.setModelViewProjection(program.projection)
      if let instr = display {
        instr.draw()
      }
      
//      drawing!.DrawLine((0.1,0.1), to: (0.9,0.9), width: 0.1)
//      drawing!.DrawSquare(0.3, bottom: 0.1, right: 0.5, top: 0.3)

//      program.setColor(red: 1, green: 0, blue: 0)
//      let tk = drawing!
//      let tri = tk.Load2DPolygon([(0,0), (0, 1), (1,0)])!
//      tk.Draw(tri)

      processGLErrors()

    }
//    glUniform3f(uniforms[UNIFORM_COLOR], 0.0, 1.0, 0.0)
    
//    let thick : GLfloat = 1.0
//    let thin  : GLfloat = 0.5
    
    
//    if let data = latestData {
//      constrainDrawing(0.25, bottom: 0.25, right: 0.75, top: 0.75)
//      drawPitchDisplay(data.Pitch,roll: data.Roll)
//
////      glUniform3f(uniforms[UNIFORM_COLOR], 0.84, 0.98, 0.0)
////      drawPrograde(0.6, y: 0.6)
////      glUniform3f(uniforms[UNIFORM_COLOR], 0.0, 1.0, 0.0)
//
//      constrainDrawing(0.0, bottom: 0.25, right: 1.0, top: 0.75)
//      drawLogDisplay(data.DeltaH, left: true)
//      drawLogDisplay(data.RadarHeight, left: false)
//      
//      // Draw the heading indicator
//      constrainDrawing(0.25, bottom: 0.25, right: 0.75, top: 1)
//      drawHeadingDisplay(data.Heading)
//      
//      unconstrainDrawing()
//    }
//    
//    drawHUDCenter()
//    
//    // Log display lines
//    drawLine((0.25,0.25), to:(0.25,0.75), width: 1)
//    drawLine((0.75,0.25), to:(0.75,0.75), width: 1)
//    
//    // Line across and triangles for HUD display
//    drawLine((0.25,0.5), to: (0.45,0.5), width: 0.5)
//    drawLine((0.55,0.5), to: (1.0,0.5), width: 0.5)
//    drawTriangle((0.25, 0.5), rotation: 3.1415926/2, height: 0.03125)
//    drawTriangle((0.75, 0.5), rotation: -3.1415926/2, height: 0.03125)
//    drawTriangle((0.5, 0.75), rotation: 3.1415926, height: 0.03125)
//
//    
//    
//    // Fixed text
//    drawText("PRS:", align: .Left, position: (0.025, 1-0.075), fontSize: 16)
//
//    drawText("ASL:", align: .Right, position: (0.75, 1-0.075), fontSize: 16)
//    drawText("TER:", align: .Right, position: (0.75, 1-(0.075+0.05)), fontSize: 16)
//
//    drawText("SPD:", align: .Left, position: (0.025, 0.025+3*0.05), fontSize: 16)
//    drawText("HRZ:", align: .Left, position: (0.025, 0.025+1*0.05), fontSize: 16)
//    drawText("THR:", align: .Left, position: (0.025, 0.025), fontSize: 16)
//    
//    if let data = latestData {
//      drawText(String(format:"%7.3fkPa", data.DynPressure/1000), align: .Left, position: (0.14, 1-0.075), fontSize: 16)
//      
//      drawText(String(format:"%.0fm", data.AtmHeight), align: .Right, position: (0.925, 1-0.075), fontSize: 16)
//      drawText(String(format:"%.0fm", data.TerrHeight), align: .Right, position: (0.925, 1-(0.075+0.05)), fontSize: 16)
//      
//      drawText(String(format:"%.0fm/s", data.Speed), align: .Right, position: (0.37, 0.025+3*0.05), fontSize: 16)
//      drawText(String(format:"%.0fm/s", data.HrzSpeed), align: .Right, position: (0.37, 0.025+1*0.05), fontSize: 16)
//      
//      drawText(String(format:"%5.1f%%", 100*data.ThrottleSet), align: .Left, position: (0.14, 0.025), fontSize: 16)
//      drawText(String(format:"%05.1f˚", data.Heading), align: .Center, position: (0.5, 0.75+0.05+0.025), fontSize: 16)
//      drawText(String(format:"P:  %05.1f˚ R:  %05.1f˚", data.Pitch, -data.Roll), align: .Center,
//        position: (0.5, 0.25-10.0/pointScale), fontSize: 10)
//
//      drawText(String(format:"%6.0fm/s", (data.DeltaH > -0.5 ? abs(data.DeltaH) : data.DeltaH)), align: .Right, position: (0.25, 0.75), fontSize: 12)
//      drawText(String(format:"%6.0fm", data.RadarHeight), align: .Left, position: (0.75, 0.75), fontSize: 12)
//      
//
//      if data.SAS {
//        drawText("SAS",   align: .Right, position: (0.15,   1-(0.325)), fontSize: 16)
//      }
//      if data.Gear {
//        drawText("GEAR",  align: .Right, position: (0.15,   1-(0.325+0.05)), fontSize: 16)
//      }
//      if data.Brake {
//        drawText("BRAKE", align: .Right, position: (0.15,   1-(0.325+2*0.05)), fontSize: 16)
//      }
//      if data.Lights {
//        drawText("LIGHT", align: .Right, position: (0.15,   1-(0.325+3*0.05)), fontSize: 16)
//      }
//
//      if data.RPMVariablesAvailable {
//        drawText(String(format:"ATM: %5.1f%%", data.AtmPercent*100.0), align: .Left, position: (0.025, 1-(0.075+0.05)), fontSize: 16)
//        drawText("EAS:", align: .Left, position: (0.025, 0.025+2*0.05), fontSize: 16)
//        drawText(String(format:"%.0fm/s", data.EASpeed), align: .Right, position: (0.37, 0.025+2*0.05), fontSize: 16)
//        drawText(String(format:"[%5.1f%%]", data.ThrottleActual*100.0), align: .Left, position: (0.33, 0.025), fontSize: 16)
//        
//        if data.HeatAlarm {
//          drawText("HEAT!", align: .Left, position: (0.83,   1-(0.325)), fontSize: 16)
//        }
//        if data.GroundAlarm {
//          drawText("GEAR!", align: .Left, position: (0.83,   1-(0.325+0.05)), fontSize: 16)
//          
//        }
//        if data.SlopeAlarm {
//          drawText("SLOPE!", align: .Left, position: (0.83,   1-(0.325+2*0.05)), fontSize: 16)
//        }
//      }
//
//    }
  
//    if let sock = socket {
//      if !sock.isConnected {
//        
////        glUniform3f(uniforms[UNIFORM_COLOR], 1.0, 0.0, 0.0)
////        drawText("NO DATA", align: .Center, position: (0.5, 0.2), fontSize: 20)
////
////        drawText("CONNECTING",
////          align: .Right, position: (1-0.05, 0.05), fontSize: 20)
//      }
//    }
    // Indicators
    
    // 8 =  0.0125
    // 16 = 0.025
    // 32 = 0.05

//    // Delete any unused text textures
//    for i in (0..<textCache.count).reverse() {
//      if usedText.contains(i) { continue }
//      var name = textCache[i].texture.name
//      glDeleteTextures(1, &name)
//      textCache.removeAtIndex(i)
//    }
//    usedText.removeAll()
  }

//  struct TextEntry {
//    let text : String
//    let size : GLfloat
//    let texture : GLKTextureInfo
//  }
//  var textCache : [TextEntry] = []
//  var usedText : Set<Int> = []
//  
//  
//  func drawText(text: String, align : NSTextAlignment, position : (x: GLfloat, y: GLfloat), fontSize : GLfloat,
//    rotate: GLfloat = 0, transform : GLKMatrix4 = GLKMatrix4Identity) {
//    
//    let fontSize = fontSize * (pointScale / 375)///0.58 * GLfloat(UIScreen.mainScreen().scale)
//      
//    let texture : GLKTextureInfo
//
//    var matchIndex : Optional<Int> = nil
//    // Look for an entry in the cache with this string and font size
//    for (index, entry) in textCache.enumerate() {
//      if entry.size == fontSize && entry.text == text {
//        matchIndex = index
//        break
//      }
//    }
//      
//    if let index = matchIndex {
//      texture = textCache[index].texture
//      usedText.insert(index)
//    } else {
//      // Let's work out the font size we want, approximately
//      let font = UIFont(name: "Menlo", size: CGFloat(fontSize))!
//      let attrs = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor()]
//      
//      let nsString: NSString = text as NSString
//      let size: CGSize = nsString.sizeWithAttributes(attrs)
//      UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
//      let context = UIGraphicsGetCurrentContext()
//      nsString.drawAtPoint(CGPoint(x: 0, y: 0), withAttributes: attrs)
//      let image = CGBitmapContextCreateImage(context)!
//      UIGraphicsEndImageContext()
//      
//      do {
//        texture = try GLKTextureLoader.textureWithCGImage(image, options: nil)
//        textCache.append(TextEntry(text: text, size: fontSize, texture: texture))
//        usedText.insert(textCache.count-1)
//      } catch {
//        print("ERROR generating texture")
//        return
//      }
//    }
//    glBindVertexArray(texArray)
//    glBindTexture(texture.target, texture.name)
//    
//    // work out how tall we want it.
//    let squareHeight = GLfloat(fontSize) / pointScale
//    let squareWidth = squareHeight * GLfloat(texture.width)/GLfloat(texture.height)
//    var baseMatrix = transform
//    switch(align) {
//    case .Left:
//      baseMatrix = GLKMatrix4Translate(baseMatrix, position.x, position.y, 0)
//    case .Right:
//      baseMatrix = GLKMatrix4Translate(baseMatrix, position.x-squareWidth, position.y, 0)
//    case .Center:
//      baseMatrix = GLKMatrix4Translate(baseMatrix, position.x-squareWidth/2, position.y, 0)
//    default:
//      break
//    }
//    
//    //      baseMatrix = GLKMatrix4Translate(baseMatrix, position.x - (left ? 0 : squareWidth), position.y, 0)
//    baseMatrix = GLKMatrix4Rotate(baseMatrix, rotate, 0, 0, -1)
//    baseMatrix = GLKMatrix4Scale(baseMatrix, squareWidth, squareHeight, 1)
//    baseMatrix = GLKMatrix4Translate(baseMatrix, 0, -0.5, 0)
//    
//    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
//    withUnsafePointer(&mvp, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    glUniform1i(uniforms[UNIFORM_USETEX], 1)
//    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0,4)
//    
//    glUniform1i(uniforms[UNIFORM_USETEX], 0)
//  }
//  
//  func drawHeadingDisplay(heading : Float)
//  {
//    let minAngle = Int(floor((heading - 27.5)/10))*10
//    let maxAngle = Int(ceil((heading + 27.5)/10))*10
//
//    for var angle = minAngle; angle <= maxAngle; angle += 10 {
//      let x = (Float(angle) - (heading - 27.5)) / 55.0
//      let height = angle % 20 == 0 ? 0.025 : 0.025*0.75
//      drawLine((0.25+x/2, 0.75), to: (0.25+x/2, GLfloat(0.75+height)), width: 1)
//    }
//    for var angle = minAngle; angle <= maxAngle; angle += 10 {
//      if angle % 20 != 0 {
//        continue
//      }
//      let x = (Float(angle) - (heading - 27.5)) / 55.0
////      drawLine((0.25+x/2, 0.75), to: (0.25+x/2, GLfloat(0.75+height)), width: 1)
//      drawText(String(format:"%d", angle), align: .Center, position: (0.25+x/2, 0.75+0.025+0.0125), fontSize: 10)
//    }
//  }
//  
//  func drawPitchDisplay(pitch : Float, roll : Float)
//  {
//    let minAngle = Int(floor((pitch - 67.5)/10))*10
//    let maxAngle = Int(ceil((pitch + 67.5)/10))*10
//    let offset = pitch / 90 / 2
//    // Build a transform to apply to all lines putting it in the right area
//    var pitchT = GLKMatrix4Identity
//    pitchT = GLKMatrix4Translate(pitchT, 0.5, 0.5, 0)
//    pitchT = GLKMatrix4Rotate(pitchT, roll*3.1415926/180, 0, 0, -1)
//    pitchT = GLKMatrix4Translate(pitchT, 0, -offset, 0)
//
//    for var angle = minAngle; angle <= maxAngle; angle += 5 {
//      let x : GLfloat
//      if angle % 20 == 0 {
//        x = 0.1
//      } else if angle % 10 == 0 {
//        x = 0.05
//      } else {
//        x = 0.5*0.025
//      }
//
//      // Scale 0->90 to 0->1, then 0->0.5
//      let y : GLfloat = (GLfloat(angle))/90*0.5
//      drawLine((-x, y), to: (x, y), width: 1, transform: pitchT)
//    }
//    for var angle = minAngle; angle <= maxAngle; angle += 10 {
//      if angle % 20 != 0 {
//        continue
//      }
//      
//      // Scale 0->90 to 0->1, then 0->0.5
//      let y : GLfloat = (GLfloat(angle))/90*0.5
//      drawText(String(format: "%d", angle), align: .Left, position: (0.1125, y),
//        fontSize: (angle == 0 ? 16 : 8), rotate: 0, transform: pitchT)
//      drawText(String(format: "%d", angle), align: .Left, position: (-0.1125, y),
//        fontSize: (angle == 0 ? 16 : 8), rotate: 3.1415926, transform: pitchT)
//      
////      drawLine((-x, y), to: (x, y), width: 1, transform: pitchT)
//    }
//
//  }
//  
//  func drawLogDisplay(value : Float, left : Bool)
//  {
//    let xPos : GLfloat = left ? 0.25 : 0.75
//
//    let lgeTickSize : GLfloat = 0.025 * (left ? -1 : 1)
//    let medTickSize = lgeTickSize / 2
//    let smlTickSize = medTickSize / 2
//    
//    let center = PseudoLog10(Double(value))
//    // Calculate the minimum and maximum of the log range to draw
//    let logRange = left ? 4 : 4.6
//    var logMin = Int(floor(center)-logRange/2)
//    var logMax = Int(ceil(center)+logRange/2)
//    if !left {
//      logMin = max(0, logMin)
//      logMax = min(5, logMax)
//    }
//    let bottom = center - logRange / 2
////    let top    = center + logRange / 2
//    // Draw the major marks
//    for power in logMin...logMax {
//      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
//      drawLine((xPos,y), to: (xPos+GLfloat(lgeTickSize), y), width: 1)
//
//      
//      if !(power == logMax) {
//        var nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let halfPoint = PseudoLog10(nextPow*0.5)
//        y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
//        drawLine((xPos,y), to: (xPos+GLfloat(medTickSize), y), width: 1)
//
//        nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let doubPoint = PseudoLog10(nextPow*0.1*2)
//        y = 0.25 + 0.5 * GLfloat((doubPoint-bottom)/logRange)
//        drawLine((xPos,y), to: (xPos+GLfloat(smlTickSize), y), width: 1)
//      }
//    }
//    // Draw text in a separate pass
//    for power in logMin...logMax {
//      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
//      var txt = NSString(format: "%.0f", abs(InversePseudoLog10(Double(power))))
//      drawText(txt as String, align: left ? .Right : .Left, position: (xPos + lgeTickSize * 1.25, y), fontSize: 12)
//      
//      if !(power == logMax) {
//        let nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
//        let halfPoint = PseudoLog10(nextPow*0.5)
//        y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
//        if abs(nextPow) == 1 {
//          txt = NSString(format: "%.1f", abs(nextPow*0.5))
//        } else {
//          txt = NSString(format: "%.0f", abs(nextPow*0.5))
//        }
//        drawText(txt as String, align: left ? .Right : .Left, position: (xPos + medTickSize * 1.25, y), fontSize: 9)
//      }
//    }
//    
//  }
//  
//

}

//

//
//var gTextureSquareVertexData : [GLfloat] = [
//  0,0,0,0,1,
//  0,1,0,0,0,
//  1,0,0,1,1,
//  1,1,0,1,0
//]
//// Equilateral triangle with height 1, facing up, with point at 0,0
//var gTriangleData : [GLfloat] = [
//  0,0,0,
//  0.625,-1,0,
//  -0.625,-1,0,
//]
//
//func openSemiCircle(r : GLfloat, w : GLfloat) -> [(x: GLfloat, y: GLfloat)]
//{
//  var points : [(x: GLfloat, y: GLfloat)] = []
//  let Csteps = 20
//  let innerR = r - w/2
//  let outerR = r + w/2
//  
//  for step in 0...Csteps {
//    let theta = GLfloat((3.1415926/Double(Csteps))*Double(step))
//    points.append((innerR*sin(theta), innerR*cos(theta)))
//    points.append((outerR*sin(theta), outerR*cos(theta)))
//  }
//  return points
//}
//
//func openCircle(start : GLfloat, end : GLfloat, r : GLfloat, w : GLfloat) -> [(x: GLfloat, y: GLfloat)]
//{
//  var points : [(x: GLfloat, y: GLfloat)] = []
//  let Csteps = 20
//  let innerR = r - w/2
//  let outerR = r + w/2
//  
//  for step in 0...Csteps {
//    let theta = Float(start) + Float(Double(end-start) * (Double(step)/Double(Csteps)))
//    
//    points.append((innerR*sin(theta), innerR*cos(theta)))
//    points.append((outerR*sin(theta), outerR*cos(theta)))
//  }
//  return points
//}
//
//


//
//func boxPoints(left: GLfloat, bottom: GLfloat, right: GLfloat, top: GLfloat) -> [(x: GLfloat, y: GLfloat)]
//{
//  return [
//    (left, top),
//    (right, top),
//    (left, bottom),
//    (right, bottom)
//  ]
//}
//
//func progradeMarker() -> [GLfloat]
//{
//  var points = openCircle(0, end: 2*3.1415926, r: 12, w: 3)
//  appendTriangleStrip(&points, with: boxPoints(-30, bottom: -1, right: -14, top: 1))
//  appendTriangleStrip(&points, with: boxPoints(-1, bottom: 14, right: 1, top: 30))
//  appendTriangleStrip(&points, with: boxPoints(14, bottom: -1, right: 30, top: 1))
//  
//  return pointsTo3DVertices(points)
//}
//
//func appendTriangleStrip(inout points : [(x: GLfloat, y: GLfloat)], with : [(x: GLfloat, y: GLfloat)])
//{
//  points.append(points.last!)
//  points.append(with.first!)
//  points.extend(with)
//}
//
//func pointsTo3DVertices(points : [(x: GLfloat, y: GLfloat)]) -> [GLfloat]
//{
//  var flts : [GLfloat] = []
//  for p in points {
//    flts.append(p.x / 640)
//    flts.append(p.y / 640)
//    flts.append(0.0)
//  }
//  return flts
//}
//
//var gCenterHUD : [GLfloat] = crossHair(16, J: 68, w: 5, theta: 0.7243116395776468)
//
//var gPrograde : [GLfloat] = progradeMarker()
