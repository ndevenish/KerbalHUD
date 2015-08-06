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
var uniforms = [GLint](count: 3, repeatedValue: 0)

class GameViewController: GLKViewController {
  
  var program: GLuint = 0
  
  var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
  var projectionMatrix : GLKMatrix4 = GLKMatrix4Identity
  var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
  var rotation: Float = 0.0
  
  var vertexArray: GLuint = 0
  var vertexBuffer: GLuint = 0
  
  var context: EAGLContext? = nil
  
  var pointScale : GLfloat = 1
  
  var currentDH : GLfloat = 0

  deinit {
    self.tearDownGL()
    
    if EAGLContext.currentContext() === self.context {
      EAGLContext.setCurrentContext(nil)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.context = EAGLContext(API: .OpenGLES2)
    
    if !(self.context != nil) {
      print("Failed to create ES context")
    }
    
    let view = self.view as! GLKView
    view.context = self.context!
    view.drawableDepthFormat = .Format24
    
    self.setupGL()
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
    
    glEnable(GLenum(GL_DEPTH_TEST))
    
    glGenVertexArrays(1, &vertexArray)
    glBindVertexArray(vertexArray)
    
    glGenBuffers(1, &vertexBuffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
    let vertexCount = gSquareVertexData.count + gTriangleData.count + gCenterHUD.count
//    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * vertexCount), &gSquareVertexData, GLenum(GL_STATIC_DRAW))

    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * vertexCount), nil, GLenum(GL_STATIC_DRAW))
    // Copy all data into the buffer
    glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, GLsizeiptr(sizeof(GLfloat)*gSquareVertexData.count), &gSquareVertexData)
//    copy_to_buffer(gSquareVertexData, offset: 0)
//    copy_to_buffer(gTriangleData, offset: gSquareVertexData.count)
//    copy_to_buffer(gCenterHUD, offset: gSquareVertexData.count + gTriangleData.count)
    
//    
    glBufferSubData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*gSquareVertexData.count,
      GLsizeiptr(sizeof(GLfloat)*gTriangleData.count), &gTriangleData)
    glBufferSubData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*(gSquareVertexData.count + gTriangleData.count),
      GLsizeiptr(sizeof(GLfloat)*gCenterHUD.count), &gCenterHUD)
    
//
    glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
    glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 12, BUFFER_OFFSET(0))
//    glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Normal.rawValue))
//    glVertexAttribPointer(GLuint(GLKVertexAttrib.Normal.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))
    
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
  
  func drawLine(from : (x: GLfloat, y: GLfloat), to: (x: GLfloat, y: GLfloat), width: GLfloat) {
    let width = width / pointScale
    
    // Calculate the rotation for this vector
    let rotation_angle = atan2(to.y-from.y, to.x-from.x)

    let length = sqrt(pow(to.y-from.y, 2) + pow(to.x-from.x, 2))
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, from.x, from.y, 0.1)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, (0.5*3.1415926)-rotation_angle, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, width, length, 1)
    baseMatrix = GLKMatrix4Translate(baseMatrix, -0.5, 0, 0)
    
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
  }
  
  func drawTriangle(point : (x: GLfloat, y: GLfloat), rotation : GLfloat, height : GLfloat)
  {
//    let height = height / pointScale
    
    var baseMatrix = GLKMatrix4Identity
    baseMatrix = GLKMatrix4Translate(baseMatrix, point.x, point.y, 0.1)
    baseMatrix = GLKMatrix4Rotate(baseMatrix, rotation, 0, 0, -1)
    baseMatrix = GLKMatrix4Scale(baseMatrix, height, height, 1)
    
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    glDrawArrays(GLenum(GL_TRIANGLES), 6, 3)
    
  }
  
  func drawHUDCenter() {
    let hudOff = (gSquareVertexData.count + gTriangleData.count)/3
    var baseMatrix = GLKMatrix4MakeTranslation(0.5, 0.5, 0)
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(hudOff), GLint(gCenterHUD.count/3))
    baseMatrix = GLKMatrix4Scale(baseMatrix, -1, 1, 1)
    mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    
    glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(hudOff), GLint(gCenterHUD.count/3))
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
    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    
    glBindVertexArray(vertexArray)
    
    glUseProgram(program)
    
//    glDisable(GLenum(GL_CULL_FACE))
    
//    withUnsafePointer(&modelViewProjectionMatrix, {
//      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
//    })
//    
//    glUniform1f(uniforms[UNIFORM_STEP], 1)
//    glUniform1i(uniforms[UNIFORM_STEP], 1)
    glUniform3f(uniforms[UNIFORM_COLOR], 0.0, 1.0, 0.0)
    
//    withUnsafePointer(&normalMatrix, {
//      glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, UnsafePointer($0));
//    })
    
//    glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
//    glUniform3f(uniforms[UNIFORM_COLOR], 1.0, 0.0, 0.0)
//    glDrawArrays(GLenum(GL_TRIANGLES), 3, 3)
    
    //glInsertEventMarkerEXT(0, "com.apple.GPUTools.event.debug-frame")
//    glUniform3f(uniforms[UNIFORM_COLOR], 1.0, 0.0, 0.0)
    
//    drawLine((0,0.2), to: (1,1), width: 2)
    let thick : GLfloat = 1.0
    let thin  : GLfloat = 0.5
//    let fivepx : GLfloat = 5 //(5.0/640.0)*pointScale
    
    drawLine((0.25,0.25), to:(0.25,0.75), width: thick)
    drawLine((0.75,0.25), to:(0.75,0.75), width: thick)
    
    // Line across
    drawLine((0.25,0.5), to: (0.75,0.5), width: thin)
    
    drawTriangle((0.25, 0.5), rotation: 3.1415926/2, height: 0.03125)
    drawTriangle((0.75, 0.5), rotation: -3.1415926/2, height: 0.03125)
    drawTriangle((0.5, 0.75), rotation: 3.1415926, height: 0.03125)
    
    // box: 70x17, 60x7 inside (5 width)
    // 86 between them
//    drawLine((206.0/640.0, (320-8.5)/640.0), to: ((206.0+70.0)/640.0, (320-8.5)/640.0), width: 5)
    
    
    drawHUDCenter()
    
    
    // Draw the log displays
    // Left: 4 orders, right: 4.6 orders.
    
    // Do the height display
//    let currentDH : Float = 0
    currentDH += 0.01
    
    // Position the left log display
    var baseMatrix = GLKMatrix4MakeTranslation(0.25, 0.25, 0)
    baseMatrix = GLKMatrix4Scale(baseMatrix, 0.5, 0.5, 1)
    var mvp = GLKMatrix4Multiply(projectionMatrix, baseMatrix)
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0));
    })
    
    drawLogDisplay(currentDH, left: true)
    drawLogDisplay(currentDH, left: false)
  }
  
  func drawLogDisplay(value : Float, left : Bool)
  {
    let xPos : GLfloat = left ? 0.25 : 0.75

    let lgeTickSize = 0.1
    let medTickSize = lgeTickSize / 2
    let smlTickSize = medTickSize / 2
    
    let center = PseudoLog10(Double(value))
    // Calculate the minimum and maximum of the log range to draw
    let logRange = left ? 4 : 4.6
    var logMin = Int(floor(center)-logRange/2)
    let logMax = Int(ceil(center)+logRange/2)
    if !left {
      logMin = max(0, logMin)
    }
    let bottom = center - logRange / 2
//    let top    = center + logRange / 2
    // Draw the major marks
    for power in logMin...logMax {
      var y : GLfloat = 0.25 + 0.5 * GLfloat((Double(power)-bottom)/logRange)
      if y > 0.25 && y < 0.75 {
        drawLine((xPos,y), to: (xPos+GLfloat(lgeTickSize * (left ? -1 : 1)), y), width: 1)
      }
      
      var nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
      let halfPoint = PseudoLog10(nextPow*0.5)
      y = 0.25 + GLfloat((halfPoint-bottom)/logRange * 0.5)
      if y > 0.25 && y < 0.75 {
        drawLine((xPos,y), to: (xPos+GLfloat(medTickSize * (left ? -1 : 1)), y), width: 1)
      }

      nextPow = InversePseudoLog10(Double(power >= 0 ? power+1 : power))
      let doubPoint = PseudoLog10(nextPow*0.1*2)
      y = 0.25 + 0.5 * GLfloat((doubPoint-bottom)/logRange)
      if y > 0.25 && y < 0.75 {
        drawLine((xPos,y), to: (xPos+GLfloat(smlTickSize * (left ? -1 : 1)), y), width: 1)
      }
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
    glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
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
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
    uniforms[UNIFORM_COLOR] = glGetUniformLocation(program, "color")
    
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
  
  // Jump to the upper cursor part
  points.append(points.last!)
  points.append((w/2, 24))
  // New squares
  points.append((w/2, 24))
  points.append((0, 24))
  points.append((w/2, H+J))
  points.append((0, H+J))
  
  // Finally, append the central semicircle
  points.append(points.last!)
  
  let circPoints = openSemiCircle(5, w: 2.5)
  points.append(circPoints.first!)
  points.extend(circPoints)
  
  var flts : [GLfloat] = []
  for p in points {
    flts.append(p.x / 640)
    flts.append(p.y / 640)
    flts.append(0.0)
  }
  return flts
}

var gCenterHUD : [GLfloat] = crossHair(16, J: 68, w: 5, theta: 0.7243116395776468)
