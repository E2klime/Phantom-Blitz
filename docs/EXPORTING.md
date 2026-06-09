# Exporting (PC / Mobile / Web)

`export_presets.cfg` ships with presets for **Windows, Linux, macOS, Android,
iOS and Web**. Before the first export, install the matching export templates:
**Editor → Manage Export Templates → Download and Install** (one download
covers all platforms).

General flow: **Project → Export… → pick preset → Export Project**.
Outputs default to `build/<platform>/`.

## Windows / Linux / macOS

Work out of the box with templates installed (`embed_pck` is on — single-file
output). macOS additionally wants code-signing for distribution outside your
machine (Export dialog → Signing; an ad-hoc signature is fine for testing).

## Web (HTML5)

1. Export the **Web** preset → `build/web/index.html`.
2. Serve the folder over HTTP(S) — `file://` won't work. Quick test:
   `python3 -m http.server -d build/web 8000`.
3. Your hosting must send these headers (required by Godot 4 web exports for
   threads/SharedArrayBuffer):

   ```
   Cross-Origin-Opener-Policy: same-origin
   Cross-Origin-Embedder-Policy: require-corp
   ```

   (itch.io has a checkbox for this; for nginx/netlify add the headers.)
4. Multiplayer from a browser requires a **WebSocket** dedicated server
   (see [NETWORKING.md](NETWORKING.md)); on an HTTPS page you'll need
   `wss://` (put the server behind a TLS proxy like caddy/nginx).

Touch controls appear automatically on phones/tablets in the browser.

## Android

1. Install Android Studio (SDK) + a debug keystore, then point Godot at them:
   **Editor → Editor Settings → Export → Android**.
2. The preset's package name is `com.phantomblitz.game` — change it.
3. Export → `phantom-blitz.apk`, or use **One-click deploy** with a device
   over USB.

The game is landscape (`orientation=4` = sensor landscape) and uses the touch
HUD automatically.

## iOS

1. Requires a Mac with Xcode and an Apple developer account.
2. Set the bundle identifier in the preset, export the Xcode project, then
   archive/sign in Xcode as usual.

## Dedicated Linux server

Export the **Linux** preset (or just use the Godot binary + project) and run:

```sh
./phantom-blitz.x86_64 --headless -- --server --port 7777
```

For browsers add `--websocket`. No GPU needed; a tiny VPS is enough for a
16-player arena.

## Renderer note

The project uses the **GL Compatibility** renderer — the single renderer that
covers all six targets (desktop GL, mobile GLES3, WebGL2). Don't switch to
Forward+/Mobile unless you drop web support.
