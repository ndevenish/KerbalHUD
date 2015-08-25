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
  
  deinit {
    self.tearDownGL()
    
    if EAGLContext.currentContext() === self.context {
      EAGLContext.setCurrentContext(nil)
    }
  }
  
  let startTime : Double = CACurrentMediaTime()
  var lastTime : Double = 0
  var runTime : Double = 0
  var frameTime : Double = 0
  
  var socket : WebSocket? = nil
  
  var latestSocketData : String?
  
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
    
    lastTime = startTime
    self.setupGL()
    self.setupSocket()
    
    
  }
  
  func setupSocket()
  {
    socket = WebSocket(url: NSURL(string: "ws://192.168.1.73:8085/datalink")!)
    if let s = socket {
      print("Starting connection...")
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
      let APIcodeString = APIvars.map({ "\"" + $0 + "\"" }).joinWithSeparator(",")
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
    // Just assign the data now, we don't need to update more than frame rate
    latestSocketData = text
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
    
//   display = RPMPlaneHUD(tools: drawing!)
    display = HSIIndicator(tools: drawing!)
    //    glEnable(GLenum(GL_DEPTH_TEST))
    
    glEnable(GLenum(GL_BLEND));
    glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA));
  }
  
  func tearDownGL() {
    EAGLContext.setCurrentContext(self.context)
  }
  
  // MARK: - GLKView and GLKViewController delegate methods
  
  var lastDataPrint : Double = 0;
  
  func update() {
    // Calculate the frame times
    let nowTime : Double = CACurrentMediaTime()
    runTime = nowTime-startTime
    frameTime = nowTime - lastTime
    lastTime = nowTime
    drawing!.time = (runTime, frameTime)
    
    // Parse the latest data
    if let data = latestSocketData {
      if runTime-lastDataPrint > 5 {
        print(String(runTime) + ": " + data)
        lastDataPrint = runTime
      }
      let json = JSON(data: data.dataUsingEncoding(NSUTF8StringEncoding)!)
      latestSocketData = nil
      if let inst = display {
        // Convert the JSON into a dictionary
        inst.update(json.dictionaryValue)
      }
    }
    
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
      let current = runTime
      let curInt = Int(current)
      var fakeData : [String: JSON] = [:]
      fakeData["rpm.RADARALTOCEAN"] = JSON(current*10)
      fakeData["v.altitude"]        = JSON(current*10)
      fakeData["v.terrainHeight"]   = JSON(50 + sin(current)*30)
      fakeData["v.verticalSpeed"]   = JSON(sin(current)*100)
      fakeData["n.roll"]            = JSON(sin(current)*15)
      fakeData["n.pitch"]           = JSON(current*2)
      fakeData["n.heading"]         = JSON(current*5)
      fakeData["rpm.available"]     = true
      fakeData["v.sasValue"]        = JSON(curInt % 2)
      fakeData["v.brakeValue"]      = JSON(curInt % 4)
      fakeData["v.lightValue"]      = JSON(curInt % 3)
      fakeData["v.gearValue"]       = JSON(curInt % 5)
      fakeData["rpm.ENGINEOVERHEATALARM"] = true
      fakeData["rpm.GROUNDPROXIMITYALARM"] = true
      fakeData["rpm.SLOPEALARM"] = true
      fakeData["rpm.ATMOSPHEREDEPTH"] = JSON(1.0/current)
      fakeData["v.dynamicPressure"] = JSON(floatLiteral: abs((fakeData["v.verticalSpeed"]?.doubleValue)!))
      fakeData["v.surfaceSpeed"] = JSON(sqrt(1 + pow(sin(current)*100, 2) + 100*cos(current)))
      fakeData["rpm.EASPEED"] = JSON(fakeData["v.surfaceSpeed"]!.floatValue/fakeData["rpm.ATMOSPHEREDEPTH"]!.floatValue)
      fakeData["f.throttle"] = JSON(abs(cos(current)))
      fakeData["rpm.EFFECTIVETHROTTLE"] = JSON(fakeData["f.throttle"]!.doubleValue*0.9)
      var prev = (current-1)*2 - current*2
      fakeData["rpm.ANGLEOFATTACK"]     = JSON(prev)
      prev = ((current-1)*5 + 90) - (current*5+90)
      fakeData["rpm.SIDESLIP"] = JSON(prev)
      fakeData["rpm.PLUGIN_JSIFAR:GetFlapSetting"] = JSON((Int(current) % 4))

      fakeData["navutil.glideslope"] = JSON(5)
      fakeData["navutil.dme"] = JSON(7500+sin(current*0.5)*2000)

      fakeData["n.heading"] = JSON(90 + 5*sin(current))
      if Int(floor(current/10)) % 2 == 0 {
        fakeData["navutil.locdeviation"] = JSON(90 - fakeData["n.heading"]!.floatValue)
      } else {
        fakeData["navutil.locdeviation"] = JSON(90 + 180 - fakeData["n.heading"]!.floatValue)
      }
      fakeData["navutil.gsdeviation"] = JSON(2*sin(current))
      fakeData["navutil.bearing"] = JSON(sin(current)*20)
      fakeData["navutil.runwayheading"] = JSON(90)
      fakeData["navutil.runway"] = JSON(["altitude": 78, "identity": "Nowhere in particular", "markers": [10000, 7000, 3000]])
      
        
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
        }
      }
    }
    processGLErrors()
  

  }
}
