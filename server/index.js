import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 4444 });

let servos = new Set();
wss.on('connection', (ws) =>{
  let clientType = undefined;
  ws.on('message', (data) =>{
    console.log('received: %s', data);

    if (clientType === undefined) {
      console.log("here", data == "arduino");
      console.log("bla %s", data);
      if (data == "arduino") {
        servos.add(ws);
        clientType = "arduino";
      } else {
        clientType = "web";
      }
    } else if (clientType == "web") {
      servos.forEach((s) => {
        s.send(data);
      });
    }
  });

  ws.on('close', () => {
    servos.delete(ws)
  })
  ws.send('something');
});
