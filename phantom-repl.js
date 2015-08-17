var system = require('system');
var wsUri = "ws://localhost:" + system.env['PHANTOMJS_COMM_PORT'];

websocket = new WebSocket(wsUri);
websocket.onopen = function(evt) { console.log("CONNECTED"); };
websocket.onclose = function(evt) { console.log("DISCONNECTED"); };
websocket.onmessage = function(evt) { websocket.send(eval(evt.data)); };
websocket.onerror = function(evt) { console.log("ERROR: " + evt.data); };
