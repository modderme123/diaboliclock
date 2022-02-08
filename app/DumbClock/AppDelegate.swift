//
//  AppDelegate.swift
//  TimeViewer
//
//  Created by Milo on 8/28/21.
//

import Cocoa
import ScriptingBridge
import Starscream
import SystemConfiguration

@objc protocol TabThing {
  @objc optional var URL: String { get }
}

@objc protocol WindowThing {
  @objc optional var activeTab: TabThing { get }
  @objc optional var mode: String { get }
}

extension SBObject: WindowThing, TabThing {}

@objc protocol ChromeThing {
  @objc optional func windows() -> [WindowThing]
}

extension SBApplication: ChromeThing {}

public func SystemIdleTime() -> Double? {
  var iterator: io_iterator_t = 0
  defer { IOObjectRelease(iterator) }
  guard
    IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOHIDSystem"), &iterator)
      == KERN_SUCCESS
  else {
    return nil
  }

  let entry: io_registry_entry_t = IOIteratorNext(iterator)
  defer { IOObjectRelease(entry) }
  guard entry != 0 else { return nil }

  var unmanagedDict: Unmanaged<CFMutableDictionary>? = nil
  defer { unmanagedDict?.release() }
  guard
    IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS
  else { return nil }
  guard let dict = unmanagedDict?.takeUnretainedValue() else { return nil }

  let key: CFString = "HIDIdleTime" as CFString
  let value = CFDictionaryGetValue(dict, Unmanaged.passUnretained(key).toOpaque())
  let number: CFNumber = unsafeBitCast(value, to: CFNumber.self)
  var nanoseconds: Int64 = 0
  guard CFNumberGetValue(number, CFNumberType.sInt64Type, &nanoseconds) else { return nil }
  let interval = Double(nanoseconds) / Double(NSEC_PER_SEC)

  return interval
}

public func macadress() -> String {
  guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
    return ""
  }

  return interfaces.map(SCNetworkInterfaceGetHardwareAddressString)[0]! as String
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, WebSocketDelegate {
  var statusBarItem: NSStatusItem!
  var menuItem: NSMenuItem!
  var oldMenu: String?
  var oldWindow: AXUIElement?
  var observer: AXObserver?
  var socket: WebSocket!
  var isConnected = false

  func windowTitleChanged(
    _ axObserver: AXObserver,
    axElement: AXUIElement,
    notification: CFString
  ) {

    let frontmost = NSWorkspace.shared.frontmostApplication!
    var z: AnyObject?
    AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &z)

    menuItem.title = frontmost.localizedName! + ";" + (z as? String ?? "")

    var stringOut = ""
    label: if frontmost.localizedName == "Google Chrome" {
      let chromeObject: ChromeThing = SBApplication.init(bundleIdentifier: "com.google.Chrome")!
      let f = chromeObject.windows!()[0]
      guard f.mode != "incognito" else {
        stringOut = "incognito"
        break label
      }

      let t = f.activeTab!
      guard let url = t.URL else {
        stringOut = ""
        break label
      }
      let components = URLComponents(url: URL(string: url)!, resolvingAgainstBaseURL: false)!

      stringOut = (components.host ?? "").replacingOccurrences(of: "www.", with: "")
    } else {
      stringOut = (frontmost.localizedName ?? "").lowercased()
    }

    var message: String
    switch stringOut {
    case "docs.google.com",
      "classroom.google.com",
      "sheets.google.com",
      "drive.google.com",
      "canvas.instructure.com",
      "slides.google.com",
      "overleaf.com",
      "todoist.com",
      "colab.research.google.com",
      "scholar.google.com",
      "jstor.org",
      "www-jstor-org.ezproxy.sfpl.org",
      "www.wiktionary.org",
      "portal.proofschool.org",
      "tinkercad.com",
      "owl.purdue.edu":
      message = "productivity"
    case "reddit.com",
      "twitter.com",
      "facebook.com":
      message = "social media"
    case "nytimes.com",
      "wsj.com",
      "news",
      "news.ycombinator.com":
      message = "news"
    case "mail.google.com",
      "meet.google.com",
      "messages",
      "facetime",
      "slack",
      "adobe connect",
      "zoom.us":
      message = "communication"
    case "steam",
      "cool math games",
      "ksp",
      "minecraft",
      "league of legends",
      "trackmania",
      "baba is you",
      "geometry dash",
      "hollow knight",
      "dead cells",
      "chess",
      "lichess.com":
      message = "games"
    case "netflix.com",
      "youtube.com",
      "spotify.com",
      "music.youtube.com",
      "spotify",
      "vimeo.com",
      "wikipedia.org",
      "buzzfeed.com",
      "quora.com":
      message = "entertainment"
    case "matlab",
      "octave",
      "mathematica",
      "desmos.com",
      "wolframalpha.com",
      "geogebra.org",
      "geogebra",
      "grapher",
      "calculator",
      "aops.com":
      message = "math"
    case "code",
      "arduino ide",
      "terminal",
      "kitty",
      "intellij idea",
      "xcode",
      "sublime text 3",
      "idle",
      "github.com",
      "stackoverflow.com",
      "arduino.cc",
      "developer.mozilla.org",
      "fork":
      message = "programming"
    case "amazon.com",
      "alibaba.com",
      "ebay.com",
      "etsy.com",
      "goodeggs.com",
      "thisiswhyimbroke.com",
      "stocks",
      "lego.com":
      message = "shopping"
    case "gimp",
      "adobe illustrator",
      "pixelmator",
      "sketchup",
      "tinkercad",
      "fusion 360",
      "fritzing",
      "preview",
      "quicktime",
      "pinterest.com":
      message = "art"
    case "incognito":
      message = "incognito"
    case "google.com",
      "finder",
      "newtab":
      message = oldMenu ?? ""  // preserve previous message
    case let x:
      print("Failed", x)
      message = "miscellaneous"
    }

    if self.isConnected {
      socket.write(string: message)
    }

    oldMenu = message
  }

  func didReceive(event: WebSocketEvent, client: WebSocket) {
    switch event {
    case .connected(_):
      print("websocket is connected")
      self.isConnected = true
      socket.write(string: macadress())
    case .disconnected(_, _):
      print("websocket is disconnected")
      DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
        print("reconnecting")
        self.isConnected = false
        self.reconnect()
      }
    case .text(let string):
      print("Received text: \(string)")
    case .binary(let data):
      print("Received data: \(data.count)")
    default:
      break
    }
  }

  func reconnect() {
    if isConnected { return }

    let request = URLRequest(url: URL(string: "ws://atunnel.cf")!, timeoutInterval: 5)
    self.socket = WebSocket(request: request)
    self.socket.delegate = self
    self.socket.connect()
    isConnected = false
    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
      self.reconnect()
    }
  }

  @objc private func focusedWindowChanged(_ observer: AXObserver, window: AXUIElement) {
    if oldWindow != nil {
      AXObserverRemoveNotification(
        observer, oldWindow!, kAXFocusedWindowChangedNotification as CFString)
    }

    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    AXObserverAddNotification(observer, window, kAXTitleChangedNotification as CFString, selfPtr)

    windowTitleChanged(
      observer, axElement: window, notification: kAXTitleChangedNotification as CFString)

    oldWindow = window
  }

  @objc private func focusedAppChanged() {
    if observer != nil {
      CFRunLoopRemoveSource(
        RunLoop.current.getCFRunLoop(),
        AXObserverGetRunLoopSource(observer!),
        CFRunLoopMode.defaultMode)
    }

    let frontmost = NSWorkspace.shared.frontmostApplication!
    let pid = frontmost.processIdentifier
    let x = AXUIElementCreateApplication(pid)

    AXObserverCreate(
      pid,
      {
        (
          _ axObserver: AXObserver,
          axElement: AXUIElement,
          notification: CFString,
          userData: UnsafeMutableRawPointer?
        ) -> Void in
        guard let userData = userData else {
          print("Missing userData")
          return
        }
        let application = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        if notification == kAXFocusedWindowChangedNotification as CFString {
          application.focusedWindowChanged(axObserver, window: axElement)
        } else {
          application.windowTitleChanged(
            axObserver, axElement: axElement, notification: notification)
        }
      }, &observer)

    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    AXObserverAddNotification(
      observer!, x, kAXFocusedWindowChangedNotification as CFString, selfPtr)

    CFRunLoopAddSource(
      RunLoop.current.getCFRunLoop(),
      AXObserverGetRunLoopSource(observer!),
      CFRunLoopMode.defaultMode)

    var focusedWindow: AnyObject?
    AXUIElementCopyAttributeValue(x, kAXFocusedWindowAttribute as CFString, &focusedWindow)

    if focusedWindow != nil {
      focusedWindowChanged(observer!, window: focusedWindow as! AXUIElement)
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    statusBarItem.button?.title = "⏱"

    let statusBarMenu = NSMenu(title: "DumbClock Status Menu")
    statusBarMenu.autoenablesItems = false
    statusBarItem.menu = statusBarMenu

    menuItem = statusBarMenu.addItem(
      withTitle: "DumbClock/Magic", action: nil,
      keyEquivalent: "")
    menuItem.isEnabled = false

    statusBarMenu.addItem(
      withTitle: "Quit",
      action: #selector(AppDelegate.quit),
      keyEquivalent: "")

    self.reconnect()

    if !AXIsProcessTrusted() {
      let alert = NSAlert()
      alert.messageText = "You have not given accessibility permissions"
      alert.addButton(withTitle: "OK")
      alert.alertStyle = .warning
      alert.runModal()
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(self.focusedAppChanged),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil)
    self.focusedAppChanged()
    self.detectIdle()
  }

  func detectIdle() {
    let seconds = 15.0 - SystemIdleTime()!
    if seconds < 0.0 {
      socket.write(string: "idle")

      var monitor: Any?
      monitor = NSEvent.addGlobalMonitorForEvents(matching: [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown,
      ]) { e in
        NSEvent.removeMonitor(monitor!)
        if let oldMenu = self.oldMenu { self.socket.write(string: oldMenu) }
        self.detectIdle()
      }

      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
      self.detectIdle()
    }
  }

  @objc func quit() {
    NSApplication.shared.terminate(self)
  }
}
