//
//  AppDelegate.swift
//  TimeViewer
//
//  Created by Milo on 8/28/21.
//

import Cocoa
import ScriptingBridge

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

struct NetworkMessageThing: Codable {
  var app: String
  var title: String
  var url: String?
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  var statusBarItem: NSStatusItem!
  var menuItem: NSMenuItem!
  var oldTitle: NetworkMessageThing = NetworkMessageThing(app: "", title: "")
  var observer: AXObserver?

  func callback(
    _ axObserver: AXObserver,
    axElement: AXUIElement?,
    notification: CFString
  ) {

    let frontmost = (NSWorkspace.shared).frontmostApplication!
    let pid = frontmost.processIdentifier
    let x = AXUIElementCreateApplication(pid)
    var y: AnyObject?
    AXUIElementCopyAttributeValue(x, kAXFocusedWindowAttribute as CFString, &y)

    var z: AnyObject?
    if let window = y {
      AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &z)
    }

    var newTitle = NetworkMessageThing(app: frontmost.localizedName!, title: z as? String ?? "")

    if newTitle.app != oldTitle.app || newTitle.title != oldTitle.title {

      menuItem.title = newTitle.app + ";" + newTitle.title

      var dontSend = false
      if frontmost.localizedName == "Google Chrome" {
        let chromeObject: ChromeThing = SBApplication.init(bundleIdentifier: "com.google.Chrome")!

        let f = chromeObject.windows!()[0]
        let t = f.activeTab!

        if f.mode == "incognito" { dontSend = true }
        newTitle.url = t.URL
      }

      let jsonEncoder = JSONEncoder()
      let jsonData = try! jsonEncoder.encode(
        dontSend ? NetworkMessageThing(app: "", title: "") : newTitle)
      let json = String(data: jsonData, encoding: String.Encoding.utf8)
      print(json)
      //webSocketDelegate.send(json ?? "")
      oldTitle = newTitle
    }
  }

  @objc private func asdf(notification: NSNotification) {
    if observer != nil {
      CFRunLoopRemoveSource(
        RunLoop.current.getCFRunLoop(),
        AXObserverGetRunLoopSource(observer!),
        CFRunLoopMode.defaultMode)
    }

    let frontmost = (notification.object as! NSWorkspace).frontmostApplication!
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
        application.callback(axObserver, axElement: axElement, notification: notification)
      }, &observer)

    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    AXObserverAddNotification(observer!, x, kAXTitleChangedNotification as CFString, selfPtr)

    CFRunLoopAddSource(
      RunLoop.current.getCFRunLoop(),
      AXObserverGetRunLoopSource(observer!),
      CFRunLoopMode.defaultMode)

    callback(observer!, axElement: nil, notification: kAXTitleChangedNotification as CFString)
  }

  func tmp() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(self.asdf), name: NSWorkspace.didActivateApplicationNotification,
      object: nil)
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    statusBarItem.button?.title = "⏱"

    let statusBarMenu = NSMenu(title: "DumbClock Status Menu")
    statusBarMenu.autoenablesItems = false
    statusBarItem.menu = statusBarMenu

    menuItem = statusBarMenu.addItem(
      withTitle: "DumbClock/Magic", action: #selector(AppDelegate.onClick),
      keyEquivalent: "")
    menuItem.isEnabled = false

    statusBarMenu.addItem(
      withTitle: "Quit",
      action: #selector(AppDelegate.quit),
      keyEquivalent: "")

    tmp()
  }

  @objc func onClick() {
    print("Doing something!")
  }

  @objc func quit() {
    NSApplication.shared.terminate(self)
  }
}
