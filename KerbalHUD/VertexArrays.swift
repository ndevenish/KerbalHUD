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
    bind(VertexArray(name: vao, buffer_name: 0))

    glGenBuffers(1, &buffer)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
    
    let stride = GLsizei(GLuint(sizeof(GLfloat))*(positions+textures))
  
    glEnableVertexAttribArray(program.attributes.position)
    glVertexAttribPointer(program.attributes.position, GLint(positions), GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, BUFFER_OFFSET(0))
    
    if textures > 0 {
      let offset = Int(sizeof(GLfloat)*Int(positions))
      glEnableVertexAttribArray(program.attributes.texture)
      glVertexAttribPointer(program.attributes.texture, GLint(textures), GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, BUFFER_OFFSET(offset))
    }
    // Return an info object
    let b = VertexArray(name: vao, buffer_name: buffer)
    return b
  }
  
  func deleteVertexArray(array: VertexArray) {
    var name = array.buffer_name
    glDeleteBuffers(1, &name)
    name = array.name
    glDeleteVertexArrays(1, &name)
  }
}
