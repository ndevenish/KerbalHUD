//
//  VertexBuffers.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 30/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import GLKit

public struct VertexArray {
  var name : GLuint
  var buffer_name : GLuint
}

extension VertexArray {
  public static var Empty : VertexArray { return VertexArray(name: 0, buffer_name: 0) }
}

extension DrawingTools {
  // Generates and binds a vertex array and buffer object, ready for filling
  // and associated with the parameters specified
  func createVertexArray(positions positions: GLuint, textures: GLuint) -> VertexArray {
    var vao : GLuint = 0
    var buffer : GLuint = 0
    
    glGenVertexArrays(1, &vao)
    glBindVertexArray(vao)
    glGenBuffers(1, &buffer)

    let b = VertexArray(name: vao, buffer_name: buffer)
    bind(b)
    
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
    
    let stride = GLsizei(GLuint(sizeof(GLfloat))*(positions+textures))
    
    glEnableVertexAttribArray(program.attributes.position)
    glVertexAttribPointer(program.attributes.position, GLint(positions), GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, BUFFER_OFFSET(0))
    
    if textures > 0 {
      let offset = Int(sizeof(GLfloat)*Int(positions))
      glEnableVertexAttribArray(program.attributes.texture)
      glVertexAttribPointer(program.attributes.texture, GLint(textures), GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, BUFFER_OFFSET(offset))
    }
    return b
  }
  
  func deleteVertexArray(array: VertexArray) {
    var name = array.buffer_name
    glDeleteBuffers(1, &name)
    name = array.name
    glDeleteVertexArrays(1, &name)
  }
}

//// Load the vertex information for a textured square
//glGenVertexArrays(1, &vertexArrayTextured)
//glBindVertexArray(vertexArrayTextured)
//glGenBuffers(1, &vertexBufferTextured)
//glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferTextured)
//// Set up the vertex array information
//glEnableVertexAttribArray(program.attributes.position)
//glEnableVertexAttribArray(program.attributes.texture)
//glVertexAttribPointer(program.attributes.position, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*4), BUFFER_OFFSET(0))
//glVertexAttribPointer(program.attributes.texture, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)*4), BUFFER_OFFSET(8))
//// Now copy the data into the buffer
//var texturedSquare : [GLfloat] = [
//  0,0,0,1,
//  0,1,0,0,
//  1,0,1,1,
//  1,1,1,0
//]
//glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat)*texturedSquare.count, &texturedSquare, GLenum(GL_STATIC_DRAW))
//glBindVertexArray(0)