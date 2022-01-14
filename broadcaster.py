#!/usr/bin/env python
import applescript
import websocket
import json
import time

browsing_apps = [
  "Google Chrome",
  "Safari"
]

homework_apps = [
  "zoom.us",
  "Arduino",
  "Sublime Text",
  "Finder"
]
homework_urls = [
  "google.com",
  "docs.google.com",
  "classroom.google.com",
  "sheets.google.com",
  "canvas.instructure.com",
  "slides.google.com",
  "overleaf.com",
  "wolframalpha.com"
]

entertainment_apps = [
  "Spotify",
  "Preview",
  "FaceTime"
]
entertainment_urls = [
  "www.youtube.com",
  "news.ycombinator.com",
  "twitter.com",
  "www.reddit.com",
  "webtoons.com",
  "music.youtube.com"
]

procrastination_apps = [
  "GitHub Desktop",
  "Visual Studio Code",
  "Etcher",
  "Terminal"
]
procrastination_urls = [
  "mail.google.com"
]

def on_open(ws): ws.send("zach")

host = "wss://atunnel.cf/"
ws = websocket.WebSocket()
ws.connect(host)
ws.send("zach")

while True:
  out = applescript.run("""
  const seApp         = Application("System Events");
  const oProcess      = seApp.processes.whose({ frontmost: true })[0];
  const appName       = oProcess.displayedName();

  let url = undefined;
  let incognito = undefined;
  let title = undefined;

  switch(appName) {
    case "Safari":
  	url = Application(appName).documents[0].url();
  	title = Application(appName).documents[0].name();

      break;
    case "Google Chrome":
    case "Brave Browser":
    case "Microsoft Edge":
      const activeWindow = Application(appName).windows[0];
      const activeTab = activeWindow.activeTab();

      url = activeTab.url();
      title = activeTab.name();
      incognito = activeWindow.mode() === 'incognito';
      break;
    default:
      mainWindow = oProcess.windows().find(w => w.attributes.byName("AXMain").value())

      if (mainWindow) {
        title = mainWindow.attributes.byName("AXTitle").value()
      }
  }


  JSON.stringify({
    app: appName,
    url,
    title,
    incognito
  });
  """, javascript=True)
  info = json.loads(out.out)
  
  if info["app"] in browsing_apps:
    message = "unknown"
    for url in homework_urls:
      if url in info["url"]:
        message = "homework"
    for url in entertainment_urls:
      if url in info["url"]:
        message = "entertainment"
    for url in procrastination_urls:
      if url in info["url"]:
        message = "procrastination"
  
  else:
    if info["app"] in homework_apps:
      message = "homework"
    elif info["app"] in entertainment_apps:
      message = "entertainment"
    elif info["app"] in procrastination_apps:
      message = "procrastination"
    else:
      message = "unknown"

  ws.send(message)
  time.sleep(1)
