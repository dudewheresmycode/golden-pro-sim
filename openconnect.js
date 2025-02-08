const net = require('net');
const { EventEmitter } = require('events');

function sleep(time) {
  return new Promise(resolve => setTimeout(resolve, time));
}

const OpenConnectMessages = {
  PlayerInfo: (distance) => ({
    "Code": 201,
    "Message": "GSPro Player Information",
    "Player": { "Handed": "RH", "Club": "I7", "DistanceToTarget": distance || 0.0, "surface": null }
  }),
  Ready: {
    "Code": 202,
    "Message": "GSPro ready",
    "Player": null
  },
  ShotReceived: {
    "Code": 200,
    "Message": "Club & Ball Data received",
    "Player": null
  },
  RoundEnded: {
    "Code": 203,
    "Message": "GSPro round ended",
    "Player": null
  }
};

class OpenConnectServer extends EventEmitter {
  constructor() {
    super();
    this.server = net.createServer(this.handleServerConnection.bind(this));
  }

  listen(port) {
    return new Promise(resolve => {
      this.server.listen(port, '127.0.0.1', () => {
        console.log(`OpenConnect listening at 127.0.0.1:${port}`);
        resolve();
      });
    });
  }

  handleServerConnection(socket) {
    // socket.write('Echo server\r\n');
    console.log('connected');
    this.socket = socket;
    this.socket.on('data', async raw => {
      console.log(`received data: ${raw}`);
      try {
        const data = JSON.parse(raw);
        if (data?.ShotDataOptions?.IsHeartBeat) {
          console.log('Received heart beat.. sending player info');
          this.sendMessage(OpenConnectMessages.PlayerInfo(0));
          await sleep(500);
          this.sendMessage(OpenConnectMessages.Ready);
          await sleep(500);
          this.sendMessage(OpenConnectMessages.PlayerInfo(150));

        } else if (data?.ShotDataOptions?.ContainsBallData) {
          this.emit('shot', data);
        }
        // this.handleShot(data);
      } catch (error) {
        console.log(error);
      }
    });
    this.socket.on('close', () => {
      console.log('connection closed');
    });
    this.socket.on('error', error => {
      if (error.code === 'ECONNRESET') {
        console.log('connection hangup');
        return;
      }
      console.error(error);
    });
    // socket.pipe(socket);
  }

  sendMessage(message) {
    this.socket.write(JSON.stringify(message));
  }
}

module.exports = OpenConnectServer;