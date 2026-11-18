-- scripts/gripen_hud/main.lua
-- Saab Gripen / PC-21 / F-22 Hybrid HUD for FrSky ETHOS 1.6 (Horus X12S 480x272)
-- Version: 1.0.0-rc1 (GPLv3, Optimized 6.0 px/° Zoom & Dual-Pole Cardinals)

local translations = { en = "Gripen INAV HUD" }
local function name()
  return translations["en"]
end

local defaultConfig = {
  hudColor      = lcd.RGB(0, 255, 102), -- Phosphor Green
  warnColor     = lcd.RGB(255, 65, 54), -- Caution Red
  bgColor       = lcd.RGB(6, 10, 8),
  pitchScale    = 6.0,                  -- 6.0 px/deg flattened jet HUD zoom
  backdropAlpha = 65,                   -- Semi-transparent opacity for instruments (0..100%)
  showGhost     = true,                 -- Fixed PC-21 waterline boresight
  alertEnable   = true,
  stallSpeed    = 35,
  minAlt        = 25,
  minVfas       = 14.0,
  minRssi       = 50,
  simMode       = false,
  srcPitch = nil, srcRoll = nil, srcYaw = nil, srcGpsCog = nil,
  srcSpeed = nil, srcAlt  = nil, srcVSpd = nil,
  srcVfas  = nil, srcCurr = nil, srcFuel = nil,
  srcTmp1  = nil, srcRssi = nil, srcHdgHome = nil, srcDistHome = nil
}

local function decodeInavMode(tmp1)
  if not tmp1 then return "DISARMED" end
  local ones     = math.floor(tmp1 % 10)
  local tens     = math.floor((tmp1 / 10) % 10)
  local hundreds = math.floor((tmp1 / 100) % 10)
  if hundreds == 1 then return "FAILSAFE" end
  if hundreds == 2 then return "NAV RTH" end
  if hundreds == 4 then return "NAV WP" end
  if tens == 1 then return "ANGLE" end
  if tens == 2 then return "HORIZON" end
  if tens == 4 then return "MANUAL" end
  if ones == 1 then return "ARMED" end
  if ones == 2 then return "ACRO" end
  return "READY"
end

local function autoBindSources(widget)
  local c = widget.config
  c.srcPitch    = c.srcPitch    or system.getSource({ name = "Pitch" })
  c.srcRoll     = c.srcRoll     or system.getSource({ name = "Roll" })
  c.srcYaw      = c.srcYaw      or system.getSource({ name = "Yaw" }) or system.getSource({ name = "Hdg" })
  c.srcGpsCog   = c.srcGpsCog   or system.getSource({ name = "GPS" })
  c.srcSpeed    = c.srcSpeed    or system.getSource({ name = "GSpd" })
  c.srcAlt      = c.srcAlt      or system.getSource({ name = "Alt" }) or system.getSource({ name = "GAlt" })
  c.srcVSpd     = c.srcVSpd     or system.getSource({ name = "VSpd" })
  c.srcVfas     = c.srcVfas     or system.getSource({ name = "VFAS" })
  c.srcCurr     = c.srcCurr     or system.getSource({ name = "Curr" })
  c.srcFuel     = c.srcFuel     or system.getSource({ name = "Fuel" })
  c.srcTmp1     = c.srcTmp1     or system.getSource({ name = "Tmp1" })
  c.srcRssi     = c.srcRssi     or system.getSource({ name = "RSSI" })
  c.srcHdgHome  = c.srcHdgHome  or system.getSource({ name = "HdgHome" })
  c.srcDistHome = c.srcDistHome or system.getSource({ name = "Dist" })
end

local function create()
  local w = {
    config = {},
    telem = {
      pitch = 0, roll = 0, yaw = 0, cog = 0,
      speed = 0, alt = 0, vspd = 0,
      vfas = 0, curr = 0, fuel = 0,
      mode = "NO TELEM", rssi = 0,
      homeDir = 0, homeDist = 0
    },
    simTime = 0,
    blink = false
  }
  for k, v in pairs(defaultConfig) do w.config[k] = v end
  autoBindSources(w)
  return w
end

local function wrap180(deg)
  while deg > 180 do deg = deg - 360 end
  while deg < -180 do deg = deg + 360 end
  return deg
end

local function rotatePt(x, y, cx, cy, cosR, sinR)
  local dx, dy = x - cx, y - cy
  return math.floor(cx + dx * cosR - dy * sinR + 0.5),
         math.floor(cy + dx * sinR + dy * cosR + 0.5)
end

local function drawGripenPitchLine(cx, cy, pitchDeg, lineDeg, pxPerDeg, cosR, sinR)
  local fullSpan = 260
  if lineDeg == 0 then
    local horizY = cy + pitchDeg * pxPerDeg
    if math.abs(horizY - cy) > 290 then return end
    local gap = 22
    local x1, y1 = rotatePt(cx - fullSpan, horizY, cx, cy, cosR, sinR)
    local x2, y2 = rotatePt(cx - gap,      horizY, cx, cy, cosR, sinR)
    local x3, y3 = rotatePt(cx + gap,      horizY, cx, cy, cosR, sinR)
    local x4, y4 = rotatePt(cx + fullSpan, horizY, cx, cy, cosR, sinR)
    lcd.drawLine(x1, y1, x2, y2)
    lcd.drawLine(x3, y3, x4, y4)
  elseif lineDeg > 0 then
    local zenithLocalY = cy - (90 - pitchDeg) * pxPerDeg
    local radius = (90 - lineDeg) * pxPerDeg
    if radius < 4 then return end
    local zx, zy = rotatePt(cx, zenithLocalY, cx, cy, cosR, sinR)
    lcd.drawCircle(zx, zy, math.floor(radius + 0.5))
  else
    local nadirLocalY = cy + (90 + pitchDeg) * pxPerDeg
    local radius = (90 + lineDeg) * pxPerDeg
    if radius < 4 then return end
    local nx, ny = rotatePt(cx, nadirLocalY, cx, cy, cosR, sinR)
    local dashCount = 16
    local stepAng = (2 * math.pi) / dashCount
    local dashAng = stepAng * 0.55
    for i = 0, dashCount - 1 do
      local a1 = i * stepAng
      local a2 = a1 + dashAng
      local x1 = math.floor(nx + math.sin(a1) * radius + 0.5)
      local y1 = math.floor(ny - math.cos(a1) * radius + 0.5)
      local x2 = math.floor(nx + math.sin(a2) * radius + 0.5)
      local y2 = math.floor(ny - math.cos(a2) * radius + 0.5)
      lcd.drawLine(x1, y1, x2, y2)
    end
    for k = 0, 3 do
      local ca = k * (math.pi / 2)
      local bx = nx + math.sin(ca) * radius
      local by = ny - math.cos(ca) * radius
      local outX, outY = math.sin(ca), -math.cos(ca)
      local tanX, tanY = -outY, outX
      lcd.drawFilledTriangle(
        math.floor(bx + outX * 5 + 0.5), math.floor(by + outY * 5 + 0.5),
        math.floor(bx - tanX * 3 + 0.5), math.floor(by - tanY * 3 + 0.5),
        math.floor(bx + tanX * 3 + 0.5), math.floor(by + tanY * 3 + 0.5)
      )
    end
  end
end

local function drawVerticalCardinalCross(px, py, yawDeg, rollRad, invertSign)
  lcd.drawCircle(px, py, 6)
  local cardinals = { {0, "N"}, {90, "E"}, {180, "S"}, {270, "W"} }
  for _, c in ipairs(cardinals) do
    local ang = math.rad(c[1] - yawDeg) * invertSign - rollRad
    local x1 = math.floor(px + math.sin(ang) * 6 + 0.5)
    local y1 = math.floor(py - math.cos(ang) * 6 + 0.5)
    local x2 = math.floor(px + math.sin(ang) * 18 + 0.5)
    local y2 = math.floor(py - math.cos(ang) * 18 + 0.5)
    lcd.drawLine(x1, y1, x2, y2)
    local tx = math.floor(px + math.sin(ang) * 25 + 0.5)
    local ty = math.floor(py - math.cos(ang) * 25 - 6 + 0.5)
    lcd.font(FONT_XS)
    lcd.drawText(tx, ty, c[2], CENTERED)
  end
end

local function drawPoleMarkers(cx, cy, pitchDeg, yawDeg, pxPerDeg, rollRad)
  local zenithDist = -(90 - pitchDeg) * pxPerDeg
  if math.abs(zenithDist) <= 240 then
    local zx, zy = rotatePt(cx, cy + zenithDist, cx, cy, cosR, sinR)
    drawVerticalCardinalCross(zx, zy, yawDeg, rollRad, 1)
  end
  local nadirDist = (90 + pitchDeg) * pxPerDeg
  if math.abs(nadirDist) <= 240 then
    local nx, ny = rotatePt(cx, cy + nadirDist, cx, cy, cosR, sinR)
    drawVerticalCardinalCross(nx, ny, yawDeg, rollRad, -1)
  end
end

local function drawBottomBankScale(cx, cy, rollDeg)
  local bankR = 104
  local ticks = { -60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60 }
  for _, deg in ipairs(ticks) do
    local a = math.rad(deg)
    local len = (deg % 30 == 0) and 7 or 4
    local x1 = math.floor(cx + math.sin(a) * bankR + 0.5)
    local y1 = math.floor(cy + math.cos(a) * bankR + 0.5)
    local x2 = math.floor(cx + math.sin(a) * (bankR + len) + 0.5)
    local y2 = math.floor(cy + math.cos(a) * (bankR + len) + 0.5)
    lcd.drawLine(x1, y1, x2, y2)
  end
  local clamped = math.max(-60, math.min(60, rollDeg))
  local pa = math.rad(-clamped)
  local tipX = math.floor(cx + math.sin(pa) * (bankR - 2) + 0.5)
  local tipY = math.floor(cy + math.cos(pa) * (bankR - 2) + 0.5)
  local b1X  = math.floor(cx + math.sin(pa - 0.05) * (bankR - 9) + 0.5)
  local b1Y  = math.floor(cy + math.cos(pa - 0.05) * (bankR - 9) + 0.5)
  local b2X  = math.floor(cx + math.sin(pa + 0.05) * (bankR - 9) + 0.5)
  local b2Y  = math.floor(cy + math.cos(pa + 0.05) * (bankR - 9) + 0.5)
  lcd.drawFilledTriangle(tipX, tipY, b1X, b1Y, b2X, b2Y)
end

local function drawTenDotDial(cx, cy, radius, value, mainText, subText, alphaByte)
  if alphaByte > 0 then
    lcd.color(lcd.RGB(6, 10, 8, alphaByte))
    lcd.drawFilledCircle(cx, cy, radius + 8)
    lcd.color(lcd.RGB(0, 255, 102))
  end
  for i = 0, 9 do
    local a = (i / 10) * (2 * math.pi)
    local dx = math.floor(cx + math.sin(a) * radius + 0.5)
    local dy = math.floor(cy - math.cos(a) * radius + 0.5)
    lcd.drawFilledCircle(dx, dy, 2)
  end
  local revFrac = (((value % 100) + 100) % 100) / 100
  local ptrAng = revFrac * (2 * math.pi)
  local x1 = math.floor(cx + math.sin(ptrAng) * (radius - 8) + 0.5)
  local y1 = math.floor(cy - math.cos(ptrAng) * (radius - 8) + 0.5)
  local x2 = math.floor(cx + math.sin(ptrAng) * (radius + 3) + 0.5)
  local y2 = math.floor(cy - math.cos(ptrAng) * (radius + 3) + 0.5)
  lcd.drawLine(x1, y1, x2, y2)
  lcd.font(FONT_BOLD)
  lcd.drawText(cx, cy - 8, mainText, CENTERED)
  lcd.font(FONT_XS)
  lcd.drawText(cx, cy + radius + 6, subText, CENTERED)
end

local function drawTopCompassAndHome(cx, yawDeg, homeDirDeg, homeDistM)
  local tapeW = 200
  local pxPerDeg = 2.2
  local yTape = 20
  lcd.setClipping(cx - tapeW / 2, 2, tapeW, 28)
  local centerDeg = math.floor(yawDeg)
  for d = centerDeg - 50, centerDeg + 50 do
    if d % 5 == 0 then
      local x = math.floor(cx + (d - yawDeg) * pxPerDeg + 0.5)
      if d % 15 == 0 then
        lcd.drawLine(x, yTape - 5, x, yTape)
        local norm = (d % 360 + 360) % 360
        local lbl = string.format("%02d", math.floor(norm / 10))
        if norm == 0 then lbl = "N"
        elseif norm == 90 then lbl = "E"
        elseif norm == 180 then lbl = "S"
        elseif norm == 270 then lbl = "W" end
        lcd.font(FONT_XS)
        lcd.drawText(x, 2, lbl, CENTERED)
      else
        lcd.drawLine(x, yTape - 3, x, yTape)
      end
    end
  end
  local relHome = wrap180(homeDirDeg - yawDeg)
  local homeX = cx + math.max(-tapeW / 2 + 6, math.min(tapeW / 2 - 6, relHome * pxPerDeg))
  lcd.drawFilledTriangle(homeX, yTape + 1, homeX - 4, yTape + 6, homeX + 4, yTape + 6)
  lcd.setClipping(0, 0, 480, 272)
  lcd.font(FONT_S)
  lcd.drawText(cx, 25, string.format("%03d", math.floor((yawDeg % 360 + 360) % 360)), CENTERED)
  local arrowY = 43
  if math.abs(relHome) > 12 then
    if relHome < 0 then
      lcd.drawLine(cx - 20, arrowY, cx + 8, arrowY)
      lcd.drawFilledTriangle(cx - 24, arrowY, cx - 17, arrowY - 4, cx - 17, arrowY + 4)
    else
      lcd.drawLine(cx - 8, arrowY, cx + 20, arrowY)
      lcd.drawFilledTriangle(cx + 24, arrowY, cx + 17, arrowY - 4, cx + 17, arrowY + 4)
    end
  end
  lcd.font(FONT_XS)
  lcd.drawText(cx + 30, arrowY - 5, string.format("H:%dm", math.floor(homeDistM)), LEFT)
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  local cfg = widget.config
  local t = widget.telem
  lcd.color(cfg.bgColor)
  lcd.drawFilledRectangle(0, 0, w, h)
  lcd.color(cfg.hudColor)
  local cx, cy = math.floor(w / 2), math.floor(h / 2) + 4
  local rollRad = math.rad(-t.roll)
  local cosR, sinR = math.cos(rollRad), math.sin(rollRad)
  local alphaByte = math.floor((cfg.backdropAlpha / 100) * 255 + 0.5)

  lcd.setClipping(0, 38, w, h - 64)
  for deg = -80, 80, 10 do
    if math.abs(deg - t.pitch) <= 45 then
      drawGripenPitchLine(cx, cy, t.pitch, deg, cfg.pitchScale, cosR, sinR)
    end
  end
  drawPoleMarkers(cx, cy, t.pitch, t.yaw, cfg.pitchScale, rollRad)

  if cfg.showGhost then
    lcd.drawLine(cx - 14, cy, cx - 6, cy)
    lcd.drawLine(cx - 6, cy, cx - 3, cy + 4)
    lcd.drawLine(cx - 3, cy + 4, cx, cy)
    lcd.drawLine(cx, cy, cx + 3, cy + 4)
    lcd.drawLine(cx + 3, cy + 4, cx + 6, cy)
    lcd.drawLine(cx + 6, cy, cx + 14, cy)
  end

  local crabDeg = wrap180(t.cog - t.yaw)
  local fpaDeg = (t.speed > 10) and math.deg(math.atan(t.vspd, t.speed / 3.6)) or 0
  local fpvX, fpvY = rotatePt(cx + crabDeg * cfg.pitchScale, cy + (t.pitch - fpaDeg) * cfg.pitchScale, cx, cy, cosR, sinR)
  fpvX = math.max(96, math.min(w - 96, fpvX))
  fpvY = math.max(54, math.min(h - 38, fpvY))

  if alphaByte > 0 then
    lcd.color(lcd.RGB(6, 10, 8, alphaByte))
    lcd.drawFilledCircle(fpvX, fpvY, 15)
    lcd.color(cfg.hudColor)
  end

  lcd.drawCircle(fpvX, fpvY, 5)
  lcd.drawLine(fpvX - 13, fpvY, fpvX - 5, fpvY)
  lcd.drawLine(fpvX + 5, fpvY, fpvX + 13, fpvY)
  lcd.drawLine(fpvX, fpvY - 10, fpvX, fpvY - 5)

  drawBottomBankScale(cx, cy, t.roll)
  lcd.setClipping(0, 0, w, h)

  drawTenDotDial(44, cy, 30, t.speed, string.format("%d", math.floor(t.speed)), "KM/H", alphaByte)
  drawTenDotDial(w - 44, cy, 30, t.alt, string.format("%d", math.floor(t.alt)), string.format("%+.1fm/s", t.vspd), alphaByte)

  drawTopCompassAndHome(cx, t.yaw, t.homeDir, t.homeDist)

  if cfg.alertEnable then
    local alertMsg = nil
    if t.vfas > 1.0 and t.vfas < cfg.minVfas then alertMsg = "LOW BATT"
    elseif t.speed > 5 and t.speed < cfg.stallSpeed then alertMsg = "STALL SPEED"
    elseif t.alt < cfg.minAlt and t.speed > 15 then alertMsg = "PULL UP / LOW ALT"
    elseif t.rssi > 0 and t.rssi < cfg.minRssi then alertMsg = "LINK CRIT" end

    if alertMsg and widget.blink then
      lcd.color(cfg.warnColor)
      lcd.drawRectangle(cx - 56, h - 46, 112, 17)
      lcd.font(FONT_S)
      lcd.drawText(cx, h - 44, alertMsg, CENTERED)
      lcd.color(cfg.hudColor)
    end
  end

  lcd.drawLine(8, h - 24, w - 8, h - 24)
  lcd.font(FONT_S)
  lcd.drawText(10, h - 20, string.format("%.1fV %.1fA %dmAh", t.vfas, t.curr, t.fuel))
  lcd.drawText(cx + 15, h - 20, t.mode, CENTERED)
  lcd.drawText(w - 10, h - 20, string.format("RSSI %d", t.rssi), RIGHT)
end

local function wakeup(widget)
  local cfg = widget.config
  local t = widget.telem
  widget.simTime = widget.simTime + 0.05
  widget.blink = (math.floor(widget.simTime * 3) % 2) == 0

  if cfg.simMode then
    t.pitch    = math.sin(widget.simTime * 0.35) * 88
    t.roll     = math.sin(widget.simTime * 0.22) * 35
    t.yaw      = (280 + math.sin(widget.simTime * 0.18) * 45) % 360
    t.cog      = (t.yaw + 7) % 360
    t.speed    = 78 + math.sin(widget.simTime * 0.3) * 24
    t.alt      = 135 + math.sin(widget.simTime * 0.35) * 45
    t.vspd     = math.cos(widget.simTime * 0.35) * 6.5
    t.vfas     = 15.8
    t.curr     = 18.4
    t.fuel     = math.floor(widget.simTime * 6) % 2200
    t.mode     = "NAV CRUISE"
    t.rssi     = 88
    t.homeDir  = 45
    t.homeDist = 420
  else
    t.pitch    = cfg.srcPitch    and cfg.srcPitch:value()    or 0
    t.roll     = cfg.srcRoll     and cfg.srcRoll:value()     or 0
    t.yaw      = cfg.srcYaw      and cfg.srcYaw:value()      or 0
    t.cog      = cfg.srcGpsCog   and cfg.srcGpsCog:value()   or t.yaw
    t.speed    = cfg.srcSpeed    and cfg.srcSpeed:value()    or 0
    t.alt      = cfg.srcAlt      and cfg.srcAlt:value()      or 0
    t.vspd     = cfg.srcVSpd     and cfg.srcVSpd:value()     or 0
    t.vfas     = cfg.srcVfas     and cfg.srcVfas:value()     or 0
    t.curr     = cfg.srcCurr     and cfg.srcCurr:value()     or 0
    t.fuel     = cfg.srcFuel     and cfg.srcFuel:value()     or 0
    t.mode     = decodeInavMode(cfg.srcTmp1 and cfg.srcTmp1:value())
    t.rssi     = cfg.srcRssi     and cfg.srcRssi:value()     or 0
    t.homeDir  = cfg.srcHdgHome  and cfg.srcHdgHome:value()  or 0
    t.homeDist = cfg.srcDistHome and cfg.srcDistHome:value() or 0
  end

  lcd.invalidate()
end

local function configure(widget)
  local c = widget.config
  local l = form.addLine("D16v2 Telemetry Simulator")
  form.addBooleanField(l, nil, function() return c.simMode end, function(v) c.simMode = v end)

  l = form.addLine("HUD Color")
  form.addColorField(l, nil, function() return c.hudColor end, function(v) c.hudColor = v end)

  l = form.addLine("Pitch Ladder Scale (px/deg)")
  form.addNumberField(l, nil, 20, 90, function() return math.floor(c.pitchScale * 10) end,
    function(v) c.pitchScale = v / 10 end)

  l = form.addLine("Instrument Backdrop Opacity (%)")
  form.addNumberField(l, nil, 0, 100, function() return c.backdropAlpha end, function(v) c.backdropAlpha = v end)

  l = form.addLine("Fixed Boresight Ghost")
  form.addBooleanField(l, nil, function() return c.showGhost end, function(v) c.showGhost = v end)

  local alertPanel = form.addExpansionPanel("HUD Caution Alerts")
  l = alertPanel:addLine("Enable Caution Banners")
  form.addBooleanField(l, nil, function() return c.alertEnable end, function(v) c.alertEnable = v end)
  l = alertPanel:addLine("Stall Speed Warn (km/h)")
  form.addNumberField(l, nil, 10, 100, function() return c.stallSpeed end, function(v) c.stallSpeed = v end)
  l = alertPanel:addLine("Min Altitude Warn (m)")
  form.addNumberField(l, nil, 5, 200, function() return c.minAlt end, function(v) c.minAlt = v end)
  l = alertPanel:addLine("Low Battery Warn (x0.1V)")
  form.addNumberField(l, nil, 60, 260, function() return math.floor(c.minVfas * 10) end,
    function(v) c.minVfas = v / 10 end)
  l = alertPanel:addLine("Min RSSI Warn (dB)")
  form.addNumberField(l, nil, 20, 90, function() return c.minRssi end, function(v) c.minRssi = v end)

  local sensPanel = form.addExpansionPanel("INAV D16v2 Sensor Mapping")
  local map = {
    { "Pitch", "srcPitch" }, { "Roll", "srcRoll" }, { "Heading / Yaw", "srcYaw" },
    { "GPS Course (COG)", "srcGpsCog" }, { "Speed (GSpd)", "srcSpeed" },
    { "Altitude", "srcAlt" }, { "Vertical Speed", "srcVSpd" },
    { "Voltage (VFAS)", "srcVfas" }, { "Current (Curr)", "srcCurr" },
    { "mAh Used (Fuel)", "srcFuel" }, { "Flight Mode (Tmp1)", "srcTmp1" },
    { "Home Direction", "srcHdgHome" }, { "Home Distance", "srcDistHome" }
  }
  for _, s in ipairs(map) do
    local sl = sensPanel:addLine(s[1])
    form.addSourceField(sl, nil, function() return c[s[2]] end, function(v) c[s[2]] = v end)
  end
end

local function read(widget)
  local c = widget.config
  for k, def in pairs(defaultConfig) do
    local val = storage.read(k)
    if val ~= nil then c[k] = val else c[k] = def end
  end
end

local function write(widget)
  for k, v in pairs(widget.config) do storage.write(k, v) end
end

local function init()
  system.registerWidget({
    key = "grpnHud", name = name, create = create,
    configure = configure, wakeup = wakeup, paint = paint,
    read = read, write = write, title = false
  })
end

return { init = init }
