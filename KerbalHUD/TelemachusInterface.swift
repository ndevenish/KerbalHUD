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
  
  private var _connectionTime : ITimer?
  private var _dumpTimer : ITimer?
  
  init (hostname : String, port : UInt) throws {
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
    socket.connect()
  }
  
  func websocketDidReceiveMessage(socket: WebSocket, text: String)
  {
    if let timer = _dumpTimer where timer.elapsed > 10 {
      print(_connectionTime!.elapsed, ":  ", text)
      _dumpTimer = Clock.createTimer()
    }
    guard let json = JSON(data: text.dataUsingEncoding(NSUTF8StringEncoding)!).dictionary else {
      print("Got message could not decode as JSON: ", text)
      return
    }
    processJSONMessage(json)
  }
  
  func processJSONMessage(json : [String : JSON]) {
    let time = CACurrentMediaTime()
    for entry in json
    {
      _latestData[entry.0] = (time, entry.1)
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
    let list = _pendingSubscriptions.map({"\"" + $0 + "\""}).joinWithSeparator(",")
    let api = "\"+\": [\(list)]"
    _socket?.writeString("{\(api)}")
  }
  func unsubscribe(apiNames : [String]) {
    if (!isConnected) { return }
    let list = _pendingSubscriptions.map({"\"" + $0 + "\""}).joinWithSeparator(",")
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
}