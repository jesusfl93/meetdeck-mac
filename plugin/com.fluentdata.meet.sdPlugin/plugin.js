// Plugin "Meet Status": botones de mic y cámara de Google Meet que muestran el estado real.
//
// Todo pasa por JavaScript en la pestaña/PWA de Meet vía AppleScript (requiere Chrome → View →
// Developer → Allow JavaScript from Apple Events):
// - keyDown hace clic en el botón de Meet: no cambia el foco ni depende de atajos (⌘E choca con la
//   extensión Claude in Chrome). Si Chrome no permite JavaScript, abre MeetMic.app / MeetCam.app.
// - Mientras el botón está visible, lee el estado cada POLL_MS.
// Sin dependencias: Node 20 del Stream Deck no trae WebSocket, así que hay un cliente mínimo abajo.

const net = require("net");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFile } = require("child_process");

const POLL_MS = 1500;
const APPS_DIR = path.join(os.homedir(), "Applications/StreamDeckMeet");
const ACTIONS = {
  "com.fluentdata.meet.mic": { key: "mic", app: "MeetMic.app" },
  "com.fluentdata.meet.cam": { key: "cam", app: "MeetCam.app" },
};

// Botones de Meet con data-is-muted, distinguidos por su etiqueta (EN/ES).
const FIND_JS = `const find = (key) => [...document.querySelectorAll('[data-is-muted]')].find((b) =>
  (key === 'mic' ? /micr[oó]fono|microphone/i : /c[aá]mara|camera/i)
    .test((b.getAttribute('aria-label') || '') + ' ' + (b.getAttribute('data-tooltip') || '')));`;

const STATE_JS = `(() => { ${FIND_JS}
  const r = {};
  for (const key of ['mic', 'cam']) {
    const b = find(key);
    if (b) r[key] = b.getAttribute('data-is-muted') === 'true';
  }
  return Object.keys(r).length ? JSON.stringify(r) : '';
})()`;

const clickJs = (key) => `(() => { ${FIND_JS}
  const b = find('${key}');
  if (!b) return '';
  b.click();
  return 'clicked';
})()`;

// Ejecuta el JS en cada pestaña de Meet hasta que una devuelva algo no vacío.
const MEET_SCRIPT = `
on run argv
	if application id "com.google.Chrome" is not running then return ""
	tell application "Google Chrome"
		repeat with w in windows
			repeat with t in tabs of w
				if URL of t contains "meet.google.com/" then
					set r to execute t javascript (item 1 of argv)
					if r is not missing value and r is not "" then return r
				end if
			end repeat
		end repeat
	end tell
	return ""
end run`;

function runInMeet(js, callback) {
  execFile("osascript", ["-e", MEET_SCRIPT, js], { timeout: 3000 }, (err, stdout, stderr) =>
    callback(err ? (stderr || err.message || "").trim() : null, (stdout || "").trim())
  );
}

const LOG = path.join(__dirname, "plugin.log");
function log(msg) {
  fs.appendFileSync(LOG, `${new Date().toISOString()} ${msg}\n`);
}

const images = {};
for (const key of ["mic", "cam"]) {
  for (const state of ["on", "off", "idle"]) {
    const png = fs.readFileSync(path.join(__dirname, "imgs", `${key}-${state}.png`));
    images[`${key}-${state}`] = "data:image/png;base64," + png.toString("base64");
  }
}

// --- Cliente WebSocket mínimo (texto, sin fragmentación) ---
function connect(port, onOpen, onMessage) {
  const sock = net.connect(port, "127.0.0.1");
  let handshaking = true;
  let buf = Buffer.alloc(0);

  function send(data, opcode = 1) {
    const payload = Buffer.isBuffer(data) ? data : Buffer.from(data);
    const n = payload.length;
    let header;
    if (n < 126) header = Buffer.from([0x80 | opcode, 0x80 | n]);
    else if (n < 65536) header = Buffer.from([0x80 | opcode, 0x80 | 126, n >> 8, n & 0xff]);
    else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode;
      header[1] = 0x80 | 127;
      header.writeBigUInt64BE(BigInt(n), 2);
    }
    const mask = crypto.randomBytes(4);
    const masked = Buffer.alloc(n);
    for (let i = 0; i < n; i++) masked[i] = payload[i] ^ mask[i & 3];
    sock.write(Buffer.concat([header, mask, masked]));
  }

  sock.on("connect", () => {
    const key = crypto.randomBytes(16).toString("base64");
    sock.write(
      `GET / HTTP/1.1\r\nHost: 127.0.0.1:${port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n` +
        `Sec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`
    );
  });

  sock.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    if (handshaking) {
      const end = buf.indexOf("\r\n\r\n");
      if (end < 0) return;
      buf = buf.subarray(end + 4);
      handshaking = false;
      onOpen();
    }
    while (buf.length >= 2) {
      const opcode = buf[0] & 0x0f;
      let len = buf[1] & 0x7f;
      let offset = 2;
      if (len === 126) {
        if (buf.length < 4) return;
        len = buf.readUInt16BE(2);
        offset = 4;
      } else if (len === 127) {
        if (buf.length < 10) return;
        len = Number(buf.readBigUInt64BE(2));
        offset = 10;
      }
      if (buf.length < offset + len) return;
      const payload = buf.subarray(offset, offset + len);
      buf = buf.subarray(offset + len);
      if (opcode === 1) onMessage(payload.toString("utf8"));
      else if (opcode === 8) process.exit(0);
      else if (opcode === 9) send(payload, 0xa);
    }
  });

  sock.on("close", () => process.exit(0));
  sock.on("error", (err) => {
    log(`socket: ${err.message}`);
    process.exit(1);
  });
  return (obj) => send(JSON.stringify(obj));
}

// --- Lógica del plugin ---
const arg = (name) => process.argv[process.argv.indexOf(name) + 1];
const visible = new Map(); // context → { key, shown }
let polling = false;
let lastError = "";

const send = connect(
  Number(arg("-port")),
  () => {
    send({ event: arg("-registerEvent"), uuid: arg("-pluginUUID") });
    log("registrado");
  },
  (raw) => {
    const msg = JSON.parse(raw);
    const action = ACTIONS[msg.action];
    if (!action) return;
    if (msg.event === "willAppear") {
      visible.set(msg.context, { key: action.key, shown: null });
      render(msg.context, undefined);
      poll();
    } else if (msg.event === "willDisappear") {
      visible.delete(msg.context);
    } else if (msg.event === "keyDown") {
      runInMeet(clickJs(action.key), (err, result) => {
        if (err) {
          // Sin JavaScript desde Apple Events: atajo de teclado vía la mini-app.
          log(`clic ${action.key}: ${err}`);
          execFile("open", ["-g", path.join(APPS_DIR, action.app)], (openErr) => {
            if (openErr) log(`open ${action.app}: ${openErr.message}`);
          });
        } else if (result !== "clicked") {
          send({ event: "showAlert", context: msg.context }); // no hay reunión
        }
        setTimeout(poll, 300);
        setTimeout(poll, 1000);
      });
    }
  }
);

function render(context, state) {
  const entry = visible.get(context);
  if (!entry) return;
  const name = `${entry.key}-${state === undefined ? "idle" : state.muted ? "off" : "on"}`;
  if (entry.shown === name) return;
  entry.shown = name;
  send({ event: "setImage", context, payload: { image: images[name], target: 0 } });
}

function poll() {
  if (polling || visible.size === 0) return;
  polling = true;
  runInMeet(STATE_JS, (err, stdout) => {
    polling = false;
    let state = {};
    if (err) {
      if (err !== lastError) log(`estado: ${err}`);
      lastError = err;
    } else {
      lastError = "";
      try {
        state = JSON.parse(stdout || "{}");
      } catch {
        state = {};
      }
    }
    for (const [context, entry] of visible) {
      const muted = state[entry.key];
      render(context, typeof muted === "boolean" ? { muted } : undefined);
    }
  });
}

setInterval(poll, POLL_MS);
