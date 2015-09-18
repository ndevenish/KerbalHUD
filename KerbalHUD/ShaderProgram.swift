//
//  Program.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 14/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

struct ShaderState {
  var color : Color4 = Color4.White
  var uvScales : (GLfloat, GLfloat, GLfloat, GLfloat) = (0,0,0,0)
  var modelViewProjection = GLKMatrix4Identity
  var projection = GLKMatrix4Identity
}

class ShaderProgram {

  private(set) static var activeProgram : ShaderProgram?
  
  private var _program : GLuint = 0
  var program : GLuint { return _program }

  var attributes : (position : GLuint, texture : GLuint, color: GLuint)
  private var uniforms : (mvp : Int32, color : Int32, uvOffset: Int32, uvScale: Int32)
  
  private var _state = ShaderState()
  var state : ShaderState {
    get { return _state }
    set {
      setColor(newValue.color)
      setProjection(newValue.projection)
      setModelViewProjection(newValue.modelViewProjection)
      setUVProperties(xOffset: newValue.uvScales.0, yOffset: newValue.uvScales.1, xScale: newValue.uvScales.2, yScale: newValue.uvScales.3)
    }
  }
  
  init() {
    _program = loadShaders()!

    let posAt = glGetAttribLocation(_program, "position")
    let texAt = glGetAttribLocation(_program, "texcoord")
    let colAt = glGetAttribLocation(_program, "colorAttrib")
    assert(posAt >= 0)
    assert(texAt >= 0)
    assert(colAt >= 0)
    attributes = (GLuint(posAt), GLuint(texAt), GLuint(colAt))

    let uMVP = glGetUniformLocation(_program, "modelViewProjectionMatrix")
    let uCol = glGetUniformLocation(_program, "color")
    let uOff = glGetUniformLocation(_program, "uvOffset")
    let uSca = glGetUniformLocation(_program, "uvScale")
    
    uniforms = (uMVP, uCol, uOff, uSca)
  }
  
  func setColor(red red : GLfloat, green : GLfloat, blue : GLfloat, alpha: GLfloat = 1.0) {
    _state.color = Color4(r: red, g: green, b: blue, a: alpha)
    glUniform4f(uniforms.color, red, green, blue, 1.0)
  }
  func setColor(color : Color4) {
    _state.color = color
    glUniform4f(uniforms.color, color.r, color.g, color.b, color.a)
  }
  
  func setUVProperties(xOffset xOffset : GLfloat = 0, yOffset : GLfloat = 0, xScale : GLfloat = 1, yScale : GLfloat = 1)
  {
    if xOffset != _state.uvScales.0 || yOffset != _state.uvScales.1 {
      glUniform2f(uniforms.uvOffset, xOffset, yOffset)
//      lastOffset = (xOffset, yOffset)
    }
    if xScale != _state.uvScales.2 || yScale != _state.uvScales.3 {
      glUniform2f(uniforms.uvScale, xScale, yScale)
//      lastScale = (xScale, yScale)
    }
    _state.uvScales = (xOffset, yOffset, xScale, yScale)
  }
  
  func setModelViewProjection(matrix : GLKMatrix4) {
    var mvp = matrix
    _state.modelViewProjection = matrix
    withUnsafePointer(&mvp, {
      glUniformMatrix4fv(uniforms.mvp, 1, 0, UnsafePointer($0));
    })
  }
  
  var projection : GLKMatrix4 { return _state.projection }

  /// Sets the modelViewProjection matrix, by multiplying in the projection
  func setModelView(matrix : GLKMatrix4) {
    setModelViewProjection(GLKMatrix4Multiply(_state.projection, matrix))
  }
  
  func setProjection(matrix : GLKMatrix4) {
    _state.projection = matrix
  }
  
  deinit {
    glDeleteProgram(_program)
    _program = 0
  }
  
  func use() {
    glUseProgram(_program)
    ShaderProgram.activeProgram = self
    setUVProperties(xOffset: 0, yOffset: 0, xScale: 1, yScale: 1)

  }
}

private func loadShaders() -> GLuint? {
  var vertShader: GLuint = 0
  var fragShader: GLuint = 0
  var vertShaderPathname: String
  var fragShaderPathname: String
  
  // Create shader program.
  let program = glCreateProgram()
  
  // Create and compile vertex shader.
  vertShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")!
  if compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
    print("Failed to compile vertex shader")
    return nil
  }
  
  // Create and compile fragment shader.
  fragShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh")!
  if !compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
    print("Failed to compile fragment shader");
    return nil
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
  if !linkProgram(program) {
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
    }
    
    return nil
  }
  
  // Release vertex and fragment shaders.
  if vertShader != 0 {
    glDetachShader(program, vertShader)
    glDeleteShader(vertShader);
  }
  if fragShader != 0 {
    glDetachShader(program, fragShader);
    glDeleteShader(fragShader);
  }
  return program
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
