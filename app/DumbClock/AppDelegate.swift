//
//  AppDelegate.swift
//  TimeViewer
//
//  Created by Milo on 8/28/21.
//

import Cocoa
import ScriptingBridge
import Starscream

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
        stringOut = "unknown"
        break label
      }

      let t = f.activeTab!
      guard let url = t.URL else {
        stringOut = "unknown"
        break label
      }
      let components = URLComponents(url: URL(string: url)!, resolvingAgainstBaseURL: false)!

      switch components.host {
      case "docs.google.com",
        "classroom.google.com",
        "sheets.google.com",
        "drive.google.com",
        "canvas.instructure.com",
        "slides.google.com",
        "overleaf.com",
        "wolframalpha.com",
        "todoist.com",
        "meet.google.com",
        "colab.research.google.com",
        "scholar.google.com":
        stringOut = "homework"
      case "play.daud.io",
        "stackoverflow.com",
        "github.com",
        "mail.google.com":
        stringOut = "procrastination"
      case "www.youtube.com",
        "news.ycombinator.com",
        "twitter.com",
        "www.reddit.com",
        "webtoons.com",
        "music.youtube.com":
        stringOut = "entertainment"
      case _:
        print(components.host)
        stringOut = "unknown"
      }
    } else {
      switch frontmost.localizedName {
      case "zoom.us",
        "Anki",
        "Arduino IDE",
        "Microsoft Teams",
        "Xcode",
        "Preview":
        stringOut = "homework"
      case "Discord":
        stringOut = "entertainment"
      case "Code",
        "kitty",
        "Fork",
        "Terminal":
        stringOut = "procrastination"
      case _:
        print(frontmost.localizedName)
        stringOut = "unknown"
      }
    }

    // procrastination, homework, entertainment, unknown
    print(stringOut)
    socket.write(string: stringOut)

    oldMenu = stringOut
  }

  func didReceive(event: WebSocketEvent, client: WebSocket) {
    switch event {
    case .connected(_):
      print("websocket is connected")
      self.isConnected = true
      socket.write(string: "milo")
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
      socket.write(string: "unknown")

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
