import { WebSocketServer } from "ws";

const wss = new WebSocketServer({ port: 4444 });

let connections = [];
let servos = new Set();
wss.on("connection", (ws, req) => {
  let channelName = undefined;
  ws.on("message", (data) => {
    if (channelName === undefined) {
      channelName = data.toString("utf8");
      if (channelName == "robot") {
        servos.add(ws);
      } else {
        console.log("User joined");
        connections.push({ ws, ip: channelName || req.socket.remoteAddress });
        connections.sort((a, b) => a.ip.localeCompare(b.ip));
      }
    } else {
      console.log(channelName, ":", data.toString("utf8"));
      var index = connections.findIndex((x) => x.ws == ws);
      if (index == -1 || index > 3) return;
      servos.forEach((s) => {
        s.send(index+":"+data);
      });
    }
  });

  ws.on("close", () => {
    if (!servos.delete(ws)) {
      var index = connections.findIndex((x) => x.ws == ws);
      if (index !== -1) connections.splice(index, 1);
    }
  });
});
