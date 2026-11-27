// Online play glue for the web build. Godot calls window.gmnet through JavaScriptBridge.
// Two browsers are linked peer to peer with PeerJS (its free public server only introduces them).
// Add ?local to the URL to link two tabs of the same browser instead (testing, no internet needed).
window.gmnet = (() => {
  const PREFIX = "guildmasters-room-";
  const LOCAL = new URLSearchParams(location.search).has("local");
  let peer = null, conn = null, onMsg = null, onStatus = null, room = "";

  const newCode = () => {
    const a = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    let s = "";
    for (let i = 0; i < 5; i++) s += a[Math.floor(Math.random() * a.length)];
    return s;
  };

  function wire(c) {
    if (conn && conn !== c) conn.close();
    conn = c;
    c.on("data", (d) => { if (conn === c) onMsg(String(d)); });
    c.on("open", () => { if (conn === c) onStatus("connected"); });
    c.on("close", () => { if (conn === c) { conn = null; onStatus("closed"); } });
    c.on("error", () => { if (conn === c) { conn = null; onStatus("closed"); } });
  }

  // Same-browser stand-in for a PeerJS connection.
  function localConn(code, me) {
    const ch = new BroadcastChannel("gm-" + code), h = {};
    ch.onmessage = (e) => { if (e.data.to === me && h.data) h.data(e.data.d); };
    setTimeout(() => h.open && h.open(), 0);
    return { on: (k, f) => { h[k] = f; }, send: (d) => ch.postMessage({ to: me === "h" ? "g" : "h", d }), close: () => {} };
  }

  function host(code) {
    room = code;
    if (LOCAL) { onStatus("code:" + code); wire(localConn(code, "h")); return; }
    peer = new Peer(PREFIX + code);
    peer.on("open", () => onStatus("code:" + code));
    peer.on("connection", (c) => wire(c));
    peer.on("disconnected", () => peer.reconnect());
    peer.on("error", (e) => {
      if (e.type === "unavailable-id") { peer.destroy(); host(newCode()); }
      else if (e.type !== "peer-unavailable") onStatus("error:" + e.type);
    });
  }

  return {
    host(msgCb, statusCb) { onMsg = msgCb; onStatus = statusCb; host(newCode()); },
    join(code, msgCb, statusCb) {
      onMsg = msgCb; onStatus = statusCb;
      code = String(code).trim().toUpperCase();
      if (LOCAL) { wire(localConn(code, "g")); return; }
      if (peer) peer.destroy();
      peer = new Peer();
      peer.on("open", () => wire(peer.connect(PREFIX + code, { reliable: true })));
      peer.on("error", (e) => onStatus(e.type === "peer-unavailable" ? "error:No game with that room code is open." : "error:" + e.type));
    },
    send(s) { if (conn) conn.send(s); },
    get room() { return room; },
  };
})();
