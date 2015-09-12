//
//  TelemachusInterface.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 25/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import QuartzCore

/// Stores result values sent from Kerbal
protocol IKerbalDataStore {
  subscript(index : String) -> JSON? { get }
  func ageOfData(name : String) -> Double
  
  func subscribe(name : String)
  func unsubscribe(name : String)
  func subscribe(apiNames : [String])
  func unsubscribe(apiNames : [String])
  func oneshot(name : String)
  
  /** 
  Subscribe to a variable such that we only need it once, rather than continuously.
  
  May still retrieve the value more than once, but will
  automatically unsubscribe once the value has been successfully
  retrieved.
  
  - parameter name  The name of the API variable to retrieve
  */
  func subscribeOnce(name : String)
}


class TelemachusInterface : WebSocketDelegate, IKerbalDataStore {
  
  enum CommsError : ErrorType {
    case InvalidURL
    case SocketOpenFailed
  }
  
  private let _url : NSURL
  var url : NSURL {
    get { return _url }
  }
  
  var isConnected : Bool { get { return _socket?.isConnected ?? false } }
  
  private var _socket : WebSocket? = nil
  /// Stores the last data packet recieved
  private var _textMessage : String? = nil

  private var _latestData : [String: (time: Double, data: JSON)] = [:]
  private var _pendingSubscriptions : [String] = []
  private var _pendingOneshots : [String] = []
  
  /// Temporary subscriptions, that we only need the data once
  private var _temporarySubscriptions = Set<String>()
  
  private var _connectionTime : Timer?
  private var _dumpTimer : Timer?
  
  private var _subscriptions : [String : Int ] = [:]
  private var _parseQueue : dispatch_queue_t
  private var dropped : Int = 0
  private var reading : Int = 0
  private var errored = Set<String>()
  
  init (hostname : String, port : UInt) throws {
    _parseQueue = dispatch_queue_create("kerbalhud_queue", DISPATCH_QUEUE_SERIAL)
    
    // Parse the URL
    guard let url = NSURL(scheme: "ws", host: hostname + ":" + String(port), path: "/datalink") else {
      _url = NSURL()
      throw CommsError.InvalidURL
    }
    _url = url
    
    _socket = WebSocket(url: _url)
    _socket!.delegate = self
    print("Starting connection to ", _url)
    _socket!.connect()
  }
  
  func websocketDidConnect(socket: WebSocket)
  {
    print("Connected to socket!")
    _connectionTime = Clock.createTimer()
    // Form an initial subscription packet
    var apiParts : [String] = ["\"rate\": 0"]
    if _pendingSubscriptions.count > 0 {
      let list = _pendingSubscriptions.map({"\"" + $0 + "\""}).joinWithSeparator(",")
      apiParts.append("\"+\": [\(list)]")
      _pendingSubscriptions.removeAll()
    }
    if _pendingOneshots.count > 0 {
      // Send off all the oneshots
      let list = _pendingOneshots.map({"\"" + $0 + "\""}).joinWithSeparator(",")
      apiParts.append("\"run\": [\(list)]")
      _pendingOneshots.removeAll()
    }
    let apiString = "{" + apiParts.joinWithSeparator(",") + "}"
    socket.writeString(apiString)
    print("Sending command on connect: ", apiString)
  }
  
  func websocketDidDisconnect(socket: WebSocket, error: NSError?)
  {
    if let err = error {
      print ("Error: \(err). Disconnected.")
    } else {
      print ("Disconnected.")
    }
    print ("Attempting connection again..")
    _pendingSubscriptions.appendContentsOf(_subscriptions.keys)
    socket.connect()
  }
  
  func websocketDidReceiveMessage(socket: WebSocket, text: String)
  {
    if (_dumpTimer?.elapsed ?? 20) > 10 {
      print("\n", _connectionTime!.elapsed, ":  ", text)
      _dumpTimer = Clock.createTimer()
    }
    

    if reading < 0 {
      fatalError()
    }
    // Discard any messages that arrive whilst parsing the last once
    guard reading == 0 else {
      dropped += 1
      return
    }
    
    // Read this message asynchronously
    reading += 1
    dispatch_async(_parseQueue) { () -> Void in
      defer {
        self.reading -= 1
      }
//      let timer = Clock.createTimer()
      guard let json = JSON(data: text.dataUsingEncoding(NSUTF8StringEncoding)!).dictionary else {
        print("Got message could not decode as JSON: ", text)
        return
      }
      self.processJSONMessage(json)
//      print("Done processing in ", String(format: "%.0fms (%.0ffps)", timer.elapsed*1000, 1.0/timer.elapsed))
      if self.dropped > 0 {
//        print("Dropped: ", self.dropped)
        self.dropped = 0
      }
    }
  }
  
  func processJSONMessage(json : [String : JSON]) {
    let time = CACurrentMediaTime()
    
    if let errors = json["errors"]?.dictionary {
      for (api, error) in errors.filter({(a,b) in return !errored.contains(a)}) {
        print("Error processing API: ", api, ";\n", error.stringValue, "\nUnsubscribing from ", api)
        errored.insert(api)
      }
    }
    if let unknowns = json["unknown"]?.array {
      let strApis = unknowns.map({ $0.stringValue }).filter({!errored.contains($0)})
      if !strApis.isEmpty {
        print("Unknown APIs: ", strApis.joinWithSeparator(", "))
        errored.unionInPlace(strApis)
      }
    }
    
    
    for (api, entry) in json
    {
      _latestData[api] = (time,
        coerceTelemachusVariable(api,
                          value: entry))
      if _temporarySubscriptions.contains(api) {
        _temporarySubscriptions.remove(api)
        unsubscribe(api)
      }
    }
  }
  
  func websocketDidReceiveData(socket: WebSocket, data: NSData)
  {
    fatalError("Got binary packet; not expecting")
  }

  subscript(index: String) -> JSON? {
    get {
      return _latestData[index]?.data
    }
  }
  
  func ageOfData(name : String) -> Double {
    return CACurrentMediaTime() - (_latestData[name]?.time ?? 0)
  }
  
  func subscribe(name : String) {
    subscribe([name])
  }
  func unsubscribe(name : String) {
    unsubscribe([name])
  }
  func subscribe(apiNames : [String]) {
    guard isConnected else {
      _pendingSubscriptions.appendContentsOf(apiNames)
      print ("No Connection; pending subscriptions")
      return
    }
    for name in apiNames {
      let count = _subscriptions[name] ?? 0
      _subscriptions[name] = count + 1
    }
    let list = apiNames.map({"\"" + $0 + "\""}).joinWithSeparator(",")
    let api = "\"+\": [\(list)]"
    _socket?.writeString("{\(api)}")
  }
  func unsubscribe(apiNames : [String]) {
    if (!isConnected) { return }
    for name in apiNames {
      _temporarySubscriptions.remove(name)
      let count = _subscriptions[name] ?? 0
      if count == 0 {
        print("Warning: Count mismatch for variable ", name)
        continue
      }
      _subscriptions[name] = count - 1
    }
    let list = apiNames.map({"\"" + $0 + "\""}).joinWithSeparator(",")
    let api = "\"-\": [\(list)]"
    _socket?.writeString("{\(api)}")
  }
  
  func oneshot(name : String) {
    guard isConnected else {
      _pendingOneshots.append(name)
      return
    }
    let api = "\"run\": [\"\(name)\"]"
    _socket?.writeString("{\(api)}")
  }
  
  func subscribeOnce(name: String) {
    _temporarySubscriptions.insert(name)
    subscribe(name)
  }
}