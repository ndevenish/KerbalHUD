//
//  GameViewController.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 04/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import GLKit
import OpenGLES
import UIKit

class GameViewController: GLKViewController {
  var program : ShaderProgram?
  var drawing : DrawingTools?
  
  var context: EAGLContext? = nil
  
  deinit {
    self.tearDownGL()
    
    if EAGLContext.currentContext() === self.context {
      EAGLContext.setCurrentContext(nil)
    }
  }
  
  var telemachus : TelemachusInterface?
  var panel : InstrumentPanel?
  
  let tapRec = UITapGestureRecognizer()
  
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Prevent sleep
    UIApplication.sharedApplication().idleTimerDisabled = true
    
    self.context = EAGLContext(API: .OpenGLES2)
    
    if !(self.context != nil) {
      print("Failed to create ES context")
    }
    
    let view = self.view as! GLKView
    view.context = self.context!
    view.drawableStencilFormat = .Format8
    
    self.setupGL()
    telemachus = try! TelemachusInterface(hostname: "192.168.1.197", port: 8085)
    panel?.connection = telemachus!
    
    tapRec.addTarget(self, action: "registerTap")
    self.view.addGestureRecognizer(tapRec)
    
  }
  
  func registerTap() {
    let loc = tapRec.locationInView(self.view)
    // Convert this to a fractional point
    let conv = Point2D(x: Float(loc.x/self.view.bounds.width),
                       y: Float(loc.y/self.view.bounds.height))
    panel?.registerTap(conv)
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
    program!.use()
    
    // Extract the default FBO so we can bind back
    (self.view as! GLKView).bindDrawable()
    var defaultFBO : GLint = 0
    glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &defaultFBO)
    drawing?.defaultFramebuffer = GLuint(defaultFBO)

    // Load the prograde etc markers
    let markers = SVGImage(fromBundleFile: "Markers.svg")
    markers.addElementsToImageLibrary(drawing!.images, size: Size2D(w: 256, h: 256))

    glEnable(GLenum(GL_BLEND));
    glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA));

    //glInsertEventMarkerEXT(0, "com.apple.GPUTools.event.debug-frame")

    panel = InstrumentPanel(tools: drawing!)
    panel?.AddInstrument(NavBall(tools: drawing!))
    panel?.AddInstrument(HSIIndicator(tools: drawing!))
    panel?.AddInstrument(NewPlaneHud(tools: drawing!))
    
    glEnable(GLenum(GL_CULL_FACE))
    glCullFace(GLenum(GL_BACK))
    glFrontFace(GLenum(GL_CW))
  }
  
  func tearDownGL() {
    EAGLContext.setCurrentContext(self.context)
  }
  
  
  // MARK: - GLKView and GLKViewController delegate methods
  
  func update() {
    
    // Calculate the frame times
    Clock.frameUpdate()
    drawing!.screenSizePhysical = Size2D(
      w: Int(self.view.bounds.size.width * UIScreen.mainScreen().scale),
      h: Int(self.view.bounds.size.height * UIScreen.mainScreen().scale))
    
    if (telemachus?.isConnected ?? false == false) {
      let current = Clock.time
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
      fakeData["v.rcsValue"]        = JSON(curInt % 6)
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
      telemachus?.processJSONMessage(fakeData)
    }

    panel!.update()
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
      if let instr = panel {
        instr.draw()
      }
    }
    processGLErrors()
  

  }
}
