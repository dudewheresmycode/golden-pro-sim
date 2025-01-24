const net = require('net');

const PORT = 1921;

const GSPRO_MESSAGES = {
  PLAYER: {
    "Code": 201,
    "Message": "GSPro Player Information",
    "Player": { "Handed": "RH", "Club": "LW", "DistanceToTarget": 156, "surface": null }
  },
  PLAYER: {
    "Code": 202,
    "Message": "GSPro ready",
    "Player": null
  }
};

class OpenConnectServer {
  constructor() {
    this.server = net.createServer((socket) => {
      // socket.write('Echo server\r\n');
      console.log('connected');
      socket.on('data', raw => {
        console.log(`received data: ${raw}`);
        try {
          const data = JSON.parse(raw);
          this.handleShot(data);
        } catch (error) {
          console.log(error);
        }
      });
      socket.on('close', () => {
        console.log('connection closed');
      });
      socket.on('error', error => {
        if (error.code === 'ECONNRESET') {
          console.log('connection hangup');
          return;
        }
        console.error(error);
      });
      // socket.pipe(socket);
    });
  }

  listen() {
    return new Promise(resolve => {
      server.listen(PORT, '127.0.0.1', () => {
        console.log(`listening at 127.0.0.1:${PORT}`);
        resolve();
      });
    });
  }

  handleShot(data) {

  }
}

module.exports = OpenConnectServer;