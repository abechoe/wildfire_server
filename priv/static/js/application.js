class webSocketHandler {
  setup() {
    console.log('>>>>>> inside setup?')
    this.socket = new WebSocket('ws://localhost:4000/ws/query')

    this.socket.addEventListener('message', (event) => {
      const pre = document.createElement('pre')
      pre.innerHTML = event.data

      document.getElementById('info').append(pre)
    })

    this.socket.addEventListener('close', () => {
      this.setup()
    })
  }
}

(function () {
  const socket = new webSocketHandler()
  socket.setup()
})()