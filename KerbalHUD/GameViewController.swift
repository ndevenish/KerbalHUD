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
    print ("Recieved Message: \(text)")
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
//    display = HSIIndicator(tools: drawing!)
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
      fakeData["v.sasValue"]        = true
      fakeData["v.brakeValue"]      = true
      fakeData["v.lightValue"]      = true
      fakeData["v.gearValue"]       = true
      fakeData["rpm.ENGINEOVERHEATALARM"] = true
      fakeData["rpm.GROUNDPROXIMITYALARM"] = true
      fakeData["rpm.SLOPEALARM"] = true
      
      display?.update(fakeData)
    }

    // Just flush unused textures every frame for now
    drawing?.flush()
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
      if let sock = socket {
        if !sock.isConnected {
          program.setColor(red: 1, green: 0, blue: 0)
          drawing?.drawText("NO DATA", size: display!.screenHeight/10,
            position: ((display!.screenWidth/2),(display!.screenHeight/2)), align: .Center)
          drawing?.drawText("(Connecting)", size: display!.screenHeight/15,
            position: ((display!.screenWidth/2),(display!.screenHeight/30)), align: .Center)

          //        drawText("NO DATA", align: .Center, position: (0.5, 0.2), fontSize: 20)
          //
          //        drawText("CONNECTING",
          //          align: .Right, position: (1-0.05, 0.05), fontSize: 20)
        }
      }
    }
    processGLErrors()
  

  }
}
