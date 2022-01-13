const net = require("net");
const server = net.createServer();

let servos = new Set();
server.on("connection", (conn) => {
  conn.setEncoding("utf8");

  let clientType = undefined;

  let completeData = "";
  conn.on("data", (d) => {
    completeData += d.toString();
    const dataArray = completeData.split("\n", 1);
    if (dataArray.length > 1) {
      const message = dataArray[0];
      completeData = dataArray[1];

      if (clientType === undefined) {
        if (message == "arduino") {
          servos.add(conn);
          clientType = "arduino";
        } else {
          clientType = "web";
        }
      } else if (clientType == "web") {
        servos.forEach((s) => {
          s.write(message);
        });
      }
      console.log(message);
    }

    console.log("connection data from ", d);
  });
  conn.once("close", () => {
    console.log("connection closed");
    servos.delete(conn);
  });
  conn.on("error", (err) => {
    console.log("Connection error: ", err.message);
    servos.delete(conn);
  });
});

server.listen(4444, () => {
  console.log("server listening to", server.address());
});
