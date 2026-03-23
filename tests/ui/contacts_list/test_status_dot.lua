local StatusDot = require("WhisperMessenger.UI.ContactsList.StatusDot")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local anchorFrame = factory.CreateFrame("Frame", nil, parent)
  anchorFrame:SetSize(40, 40)

  -- test_create_returns_frame_and_texture
  do
    local result = StatusDot.create(factory, parent, anchorFrame, nil)
    assert(result ~= nil, "create should return a table")
    assert(result.frame ~= nil, "result should have frame")
    assert(result.texture ~= nil, "result should have texture")
  end

  -- test_online_availability_sets_green
  do
    local avail = { canWhisper = true, status = "Online" }
    local result = StatusDot.create(factory, parent, anchorFrame, avail)
    local color = result.texture.vertexColor
    assert(color ~= nil, "vertex color should be set for online")
    -- online = { 0.30, 0.82, 0.40, 1.0 }
    assert(math.abs(color[1] - 0.30) < 0.01, "online R should be ~0.30, got: " .. tostring(color[1]))
    assert(math.abs(color[2] - 0.82) < 0.01, "online G should be ~0.82, got: " .. tostring(color[2]))
  end

  -- test_away_availability_sets_yellow
  do
    local avail = { canWhisper = true, status = "Away" }
    local result = StatusDot.create(factory, parent, anchorFrame, avail)
    local color = result.texture.vertexColor
    assert(color ~= nil, "vertex color should be set for away")
    -- away = { 0.90, 0.72, 0.20, 1.0 }
    assert(math.abs(color[1] - 0.90) < 0.01, "away R should be ~0.90, got: " .. tostring(color[1]))
    assert(math.abs(color[2] - 0.72) < 0.01, "away G should be ~0.72, got: " .. tostring(color[2]))
  end

  -- test_busy_availability_sets_red
  do
    local avail = { canWhisper = false, status = "Busy" }
    local result = StatusDot.create(factory, parent, anchorFrame, avail)
    local color = result.texture.vertexColor
    assert(color ~= nil, "vertex color should be set for busy")
    -- dnd = { 0.85, 0.25, 0.25, 1.0 }
    assert(math.abs(color[1] - 0.85) < 0.01, "busy R should be ~0.85, got: " .. tostring(color[1]))
    assert(math.abs(color[2] - 0.25) < 0.01, "busy G should be ~0.25, got: " .. tostring(color[2]))
  end

  -- test_offline_availability_sets_gray
  do
    local avail = { canWhisper = false, status = "Offline" }
    local result = StatusDot.create(factory, parent, anchorFrame, avail)
    local color = result.texture.vertexColor
    assert(color ~= nil, "vertex color should be set for offline")
    -- offline = { 0.45, 0.45, 0.50, 1.0 }
    assert(math.abs(color[1] - 0.45) < 0.01, "offline R should be ~0.45, got: " .. tostring(color[1]))
    assert(math.abs(color[2] - 0.45) < 0.01, "offline G should be ~0.45, got: " .. tostring(color[2]))
  end

  print("PASS: test_status_dot")
end
