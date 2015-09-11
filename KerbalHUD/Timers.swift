//
//  Timers.swift
//  KerbalHUD
//
//  Created by Nicholas Devenish on 26/08/2015.
//  Copyright © 2015 Nicholas Devenish. All rights reserved.
//

import Foundation
import QuartzCore

public enum TimerCategory {
  case Real
  case Animation
  case Frame
  case Physics
}

public protocol ITimerClock {
  /// Return a measure, in real time, of how long we have run
  var time : Double { get }
  /// The real-time length of the last frame
  var frameTime : Double { get }
  
  /// Create a timer
  func createTimer(category : TimerCategory, duration: Double, scale: Double) -> Timer
  
  // Update the clock for this frame
  func frameUpdate()
}

public protocol Timer {
  var elapsed : Double { get }
  var remaining : Double { get }
  var isDone : Bool { get }
  var scale : Double { get }
  var category : TimerCategory { get }
  var frameTime : Double { get }
  var fraction : Double { get }
}

public let Clock : ITimerClock = TimerClock()

private class TimerClock : ITimerClock {
  var time : Double { return timeBases[.Real]! }
  var frameTime : Double = 0
  
  private var startTime : Double
  private var started : Bool = false
  
  var timeBases : [TimerCategory: Double] = [
    .Real: 0,
    .Animation: 0,
    .Frame: 0,
    .Physics: 0
  ]
  
  init() {
    startTime = CACurrentMediaTime()
    
  }
  func createTimer(category : TimerCategory, duration : Double, scale : Double) -> Timer {
    return TimerImpl(clock: self, baseTime: timeBases[category]!,
      duration: duration, scale: scale, category: category)
  }
  
  func frameUpdate() {
    let time = CACurrentMediaTime()
    if !started {
      frameTime = 0
      started = true
    } else {
      frameTime = time - startTime - timeBases[.Real]!
    }
    timeBases[.Real] = CACurrentMediaTime()-startTime

    timeBases[.Animation] = timeBases[.Animation]! + frameTime
    timeBases[.Physics] = timeBases[.Physics]! + frameTime
    timeBases[.Frame] = timeBases[.Frame]! + 1
  }
}

private struct TimerImpl : Timer {
  let clock : TimerClock
  let baseTime : Double
  let duration : Double
  let scale : Double
  let category : TimerCategory
  
  var elapsed : Double {
    return scale*(clock.timeBases[category]!-baseTime)
  }
  var remaining : Double {
    return duration - elapsed
  }
  var isDone : Bool { return remaining < 0 }
  var frameTime : Double { return clock.frameTime*scale }
  var fraction : Double { return max(0, min(elapsed / duration, 1.0)) }
}

extension ITimerClock {
  func createTimer() -> Timer {
    return createTimer(.Real, duration: 0, scale: 1)
  }

  func createTimer(category : TimerCategory) -> Timer {
    return createTimer(category, duration: 0, scale: 1)
  }
  func createTimer(category : TimerCategory, duration : Double) -> Timer {
    return createTimer(category, duration: duration, scale: 1)
  }
}