# FrSky ETHOS 1.6 Saab Gripen / PC-21 INAV HUD Widget (v1.0.0-rc1)

A high-performance vector HUD widget designed for **FrSky Horus X12S (480x272 color TFT)** running **ETHOS 1.6**, inspired by the Saab JAS 39 Gripen (EP-17) concentric pitch ladder symbology combined with F-22 circular dot dials and PC-21 FPV reference.

## Authors & Contributors
* **Lead Developer & Test Pilot:** User
* **AI Collaborator & Code Architect:** Gemini

---

## Interactive Web Simulator & Telemetry Test
You can test and tweak telemetry values (`pitch`, `roll`, `heading`, `airspeed`, `altitude`) interactively before flashing:

* **Pitch Ladder Zoom:** 6.0 px/deg flattened jet HUD curve.
* **Dual Poles:** Full `N / S / E / W` cardinal crosses at Zenith and Nadir.
* **Dive Triangles:** Exactly 4 cardinal-aligned triangles per dive ring.

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
