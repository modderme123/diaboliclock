import { WebSocketServer } from "ws";

const wss = new WebSocketServer({ port: 4444 });

let servos = {};
wss.on("connection", (ws) => {
  let clientType = undefined;
  ws.on("message", (data) => {
    if (clientType === undefined) {
      clientType = data.toString('utf8');
      console.log("User joined ", clientType);
      if (!(clientType in servos)) servos[clientType] = [];
      servos[clientType].push(ws);
    } else {
      console.log(clientType, ":", data.toString('utf8'));
      servos[clientType].forEach((s) => {
        if (s != ws) s.send(data);
      });
    }
  });

  ws.on("close", () => {
    if(!(clientType in servos)) return;
    var index = servos[clientType].indexOf(ws);
    if (index !== -1) servos[clientType].splice(index, 1);
  });

  ws.send("something");
});
