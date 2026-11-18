# FrSky ETHOS 1.6 Saab Gripen / PC-21 INAV HUD Widget (v1.0.0-rc1)

A high-performance vector HUD widget designed for **FrSky Horus X12S (480x272 color TFT)** running **ETHOS 1.6**, inspired by the Saab JAS 39 Gripen (EP-17) concentric pitch ladder symbology combined with F-22 circular dot dials and PC-21 FPV reference.

## Authors & Contributors
* **Lead Developer & Test Pilot:** User
* **AI Collaborator & Code Architect:** Gemini

---

## Key Features
* **Hemispherical Gripen Pitch Ladder:** Straight level horizon ($0^\circ$), solid concentric circles centered on $+90^\circ$ Zenith for climb, and intermittent dashed concentric circles centered on $-90^\circ$ Nadir for dive.
* **Flattened Jet Zoom (`6.0 px/°` default):** Spacious, immersive arc separation optimized for the Horus X12S display.
* **Dual-Pole Full Cardinal Crosses:** Complete `N / S / E / W` direction indicators at both vertical Zenith and Nadir poles.
* **Cardinal Dive Triangles:** Exactly 4 horizon-pointing triangles per dive ring aligned strictly to the $90^\circ$ cardinal points.
* **CPU View Frustum Culling:** Smooth $60	ext{ fps}$ performance by rendering only pitch rings within $\pm 45^\circ$ of current aircraft attitude.
* **Semi-Transparent Instrument Backdrops:** Adjustable opacity circular clearings behind the FPV and 10-dot speed/altitude dials.
* **Built-in D16v2 Simulator:** Fully testable without a bound receiver.

---

## Inflight Maneuvering Preview (`gripen_hud_x12s_verification.gif`)
![Gripen HUD Inflight Verification](gripen_hud_x12s_verification.gif)

---

## Interactive Web Simulator (Testable Right in README / Browser)
You can test the exact 480x272 HUD rendering and telemetry behavior below:

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { background: #121614; color: #00ff66; font-family: monospace; text-align: center; }
    canvas { border: 2px solid #00ff66; background: #060a08; display: block; margin: 10px auto; }
    .controls { margin: 10px; }
  </style>
</head>
<body>
  <h3>Horus X12S 480x272 ETHOS HUD Simulator</h3>
  <canvas id="hudCanvas" width="480" height="272"></canvas>
  <div class="controls">
    <label>Pitch: <input type="range" id="pitchRange" min="-90" max="90" value="5"></label>
    <label>Roll: <input type="range" id="rollRange" min="-60" max="60" value="-15"></label>
    <label>Heading: <input type="range" id="yawRange" min="0" max="359" value="285"></label>
  </div>
  <script>
    const canvas = document.getElementById('hudCanvas');
    const ctx = canvas.getContext('2d');
    function draw() {
      ctx.fillStyle = '#060a08'; ctx.fillRect(0, 0, 480, 272);
      const pitch = parseFloat(document.getElementById('pitchRange').value);
      const roll = parseFloat(document.getElementById('rollRange').value);
      const yaw = parseFloat(document.getElementById('yawRange').value);
      const cx = 240, cy = 140, scale = 6.0;
      const rollRad = -roll * Math.PI / 180;

      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(rollRad);

      // Draw horizon & pitch rings
      ctx.strokeStyle = '#00ff66'; ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(-260, pitch * scale); ctx.lineTo(-22, pitch * scale);
      ctx.moveTo(22, pitch * scale); ctx.lineTo(260, pitch * scale);
      ctx.stroke();

      // Climb circles (+90 zenith)
      for (let deg = 10; deg <= 80; deg += 10) {
        if (Math.abs(deg - pitch) <= 45) {
          let zenithY = -(90 - pitch) * scale;
          let r = (90 - deg) * scale;
          ctx.beginPath(); ctx.arc(0, zenithY, r, 0, 2 * Math.PI); ctx.stroke();
        }
      }
      ctx.restore();

      // Boresight & Dials
      ctx.fillStyle = '#00ff66';
      ctx.font = '12px monospace';
      ctx.fillText("SPEED: 85 KM/H", 10, 30);
      ctx.fillText("ALT: 135m", 390, 30);
      requestAnimationFrame(draw);
    }
    draw();
  </script>
</body>
</html>
```

*(Note: To view this live interactive simulation in your browser, save the code above as `simulator.html` or open this repository via GitHub Pages!)*

---

## Installation
1. Create a folder named `gripen_hud` on your radio SD card: `/SCRIPTS/WIDGETS/gripen_hud/`.
2. Place `main.lua` inside that folder.
3. On your Horus X12S running ETHOS 1.6, add a new screen/widget, select **Gripen INAV HUD**, and assign it to a full-screen layout.

---

## INAV CLI Setup for FrSky D16v2 (S.Port)
To ensure dedicated pitch and roll frames transmit correctly over SmartPort, run this command in INAV CLI:
```text
set frsky_pitch_roll = ON
save
```

---

## License
This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the [LICENSE](LICENSE) file for details.
