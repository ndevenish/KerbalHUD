//
//  GameViewController.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import GLKit
import OpenGLES

class GameViewController: GLKViewController, WebSocketDelegate {
  var program : ShaderProgram?
  var drawing : DrawingTools?
  
  var context: EAGLContext? = nil
  
  var display : Instrument?
  
  var current : GLfloat = 0
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
  }
  
  func tearDownGL() {
    EAGLContext.setCurrentContext(self.context)
  }
  
  // MARK: - GLKView and GLKViewController delegate methods
  
  func update() {
    let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
    let drawWidth = display?.screenWidth ?? 1.0
    let drawHeight = display?.screenHeight ?? 1.0
    
    if aspect > 1 {
      let edge = (aspect-1)*0.5
      program!.projection = GLKMatrix4MakeOrtho(-edge*drawWidth, (1+edge)*drawWidth, 0, drawHeight, -10, 10)
      drawing!.pointsToScreenScale = Float(self.view.bounds.size.height) / drawHeight
    } else {
      let edge = (1.0/aspect - 1)*0.5
      program!.projection = GLKMatrix4MakeOrtho(0, drawWidth, (-edge)*drawHeight, (1+edge)*drawHeight, -10, 10)
      drawing!.pointsToScreenScale = Float(self.view.bounds.size.width) / drawWidth
    }
    
    if !(socket?.isConnected ?? false) {
      current += 0.01
      var fakeData : [String: JSON] = [:]
      fakeData["rpm.RADARALTOCEAN"] = JSON(current*10)
      fakeData["v.verticalSpeed"]   = JSON(sin(current)*100)
      fakeData["n.roll"]            = JSON(sin(current)*15)
      fakeData["n.pitch"]           = JSON(current*2)
      fakeData["n.heading"]         = JSON(current*5 + 90)
      fakeData["rpm.available"]     = true
      display?.update(fakeData)
    }
  }
  
  override func glkView(view: GLKView, drawInRect rect: CGRect) {
    glClearColor(0,0,0,1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    
    if let program = program {
      program.use()
      program.setColor(red: 0, green: 1, blue: 0)
      program.setModelViewProjection(program.projection)
      if let instr = display {
        instr.draw()
      }
      
//      drawing!.drawText("TEST", size: 20, position: (160,160), align: .Left, rotation: 3.14/2)
      processGLErrors()
    }
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

  }
}
