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
  /// Retrieve a single data value
  subscript(index : String) -> JSON? { get }
  
  /** Finds the age of the named data variable.
  - parameter name The data variable to query
  - returns: Number of seconds since update,
             or infinity if unknown */
  func ageOfData(name : String) -> Double
  
  /// Subscribe to a single API variable
  func subscribe(name : String)
  /// Unsubscribe from a single API variable
  func unsubscribe(name : String)
  /// Subscribe to a whole number of API variables
  func subscribe(apiNames : [String])
  /// Unsubscribe from a whole number of API variables
  func unsubscribe(apiNames : [String])
  /// Send an API request to the server only once
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
  
  /// The websocket object being used to talk to telemachus
  private var _socket : WebSocket? = nil

  /// The current data set, by integrating all the data recieved
  private var _latestData : [String: (time: Double, data: JSON)] = [:]
  /// Subscriptions we have yet to dispatch. Used for e.g. subscriptions
  /// requested without an active connection.
  private var _pendingSubscriptions : [String] = []
  /// One-time requests we have yet to dispatch. Used for e.g. subscriptions
  /// requested without an active connection.
  private var _pendingOneshots : [String] = []
  
  /// Temporary subscriptions, that we only need the data once for. Once a
  /// value is recieved for each of these variables, we will be unsubscribed
  /// from it.
  private var _temporarySubscriptions = Set<String>()
  
  /// Timer initialised when the connection connects
  private var _connectionTime : Timer?
  /// Timer to keep track of the last time we debug printed a data dump
  private var _dumpTimer : Timer?
  
  /// The current subscriptions, and the number of times it has been subscribed
  var _subscriptions : [String : Int ] = [:]
  /// GCD Queue for processing incoming websocket messages
  private var _parseQueue : dispatch_queue_t
  
  /// Tracks number of dropped messages due to still processing
  private var dropped : Int = 0
  /// The number of messages we are currently reading
  private var reading : Int = 0
  /// Varaibles we have recieved an error for. Each variable will only be printed once.
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
  
  /// Is the websocket actively connected?
  var isConnected : Bool { get { return _socket?.isConnected ?? false } }
  
  func websocketDidConnect(socket: WebSocket)
  {
    print("Connected to socket!")
    _connectionTime = Clock.createTimer()
    // Reset the subscriptions
    _subscriptions = [:]
    // Form an initial subscription packet
    var apiParts : [String] = ["\"rate\": 0"]
    _pendingSubscriptions.append("p.paused")
    if _pendingSubscriptions.count > 0 {
      let list = _pendingSubscriptions.map({"\"" + $0 + "\""}).joinWithSeparator(",")
      apiParts.append("\"+\": [\(list)]")
      for name in _pendingSubscriptions {
        let val = _subscriptions[name] ?? 0
        _subscriptions[name] = val + 1
      }
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
    _subscriptions.removeAll()
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
        print("Error processing API: ", api, ";\n", error.stringValue)
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
    return CACurrentMediaTime() - (_latestData[name]?.time ?? -Double.infinity)
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
        print("Data: ", _subscriptions)
        continue
      }
      _subscriptions[name] = count - 1
    }
    // Unsubscribe from anything with a count of zero
    let toUnsubscribe = _subscriptions.filter({(k,v) in v == 0}).map({$0.0})
    if !toUnsubscribe.isEmpty {
      print("Unsubscribing really from " + toUnsubscribe.joinWithSeparator(", "))
      let list = toUnsubscribe.map({"\"" + $0 + "\""}).joinWithSeparator(",")
      let api = "\"-\": [\(list)]"
      _socket?.writeString("{\(api)}")
    }
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