local Composer = require("WhisperMessenger.UI.Composer")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

local SEND_ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\send.png"
local HOVER_CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function textureWithPath(frame, path)
  return FindUI.find(frame, function(node)
    return node.texturePath == path
  end)
end

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

-- The send button is an accent paper-plane glyph, no border/fill.
local function testIconSendButton(key)
  Theme.SetPreset(key)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local composer = Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
  local btn = composer.sendButton

  assert(btn.ghost == nil, key .. ": no outline parts on the send button")
  local sendIcon = assert(textureWithPath(btn, SEND_ICON_TEXTURE), key .. ": send glyph is the bundled paper plane")
  local hoverCircle = assert(textureWithPath(btn, HOVER_CIRCLE_TEXTURE), key .. ": send button carries a hover circle")
  assert(sendIcon.desaturated ~= true, key .. ": paper plane is not desaturated")
  assert(sendIcon.width >= 18 and sendIcon.width <= 20, key .. ": glyph is 18-20px, got " .. tostring(sendIcon.width))
  assert(sendIcon.shown == true, key .. ": icon visible")
  assert(colorsMatch(sendIcon.vertexColor, Theme.COLORS.accent), key .. ": icon uses the accent color")

  local originalTooltip = _G.GameTooltip
  local tooltipText
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text)
      tooltipText = text
    end,
    Show = function() end,
    Hide = function() end,
  }
  btn.scripts.OnEnter(btn)
  assert(hoverCircle.shown == true, key .. ": hover shows a faint circle")
  local wantCircle = Theme.COLORS.bg_contact_hover
  local vc = hoverCircle.vertexColor
  assert(vc[1] == wantCircle[1] and vc[2] == wantCircle[2] and vc[3] == wantCircle[3], key .. ": hover circle is neutral")
  assert(hoverCircle.alpha == wantCircle[4], key .. ": hover circle at the token's faint alpha")
  assert(tooltipText == "Send", key .. ": hover tooltip names the action, got " .. tostring(tooltipText))
  local hc = sendIcon.vertexColor
  local accent = Theme.COLORS.accent
  assert(hc[1] >= accent[1] and hc[2] >= accent[2] and hc[3] >= accent[3], key .. ": hover brightens the glyph")
  assert(not colorsMatch(hc, accent), key .. ": hover glyph differs from idle accent")
  btn.scripts.OnLeave(btn)
  assert(hoverCircle.shown == false, key .. ": leave hides the circle")
  _G.GameTooltip = originalTooltip

  composer.setEnabled(false)
  local dc = sendIcon.vertexColor
  assert(math.abs(dc[1] - dc[2]) < 0.01 and math.abs(dc[2] - dc[3]) < 0.01, key .. ": disabled glyph is neutral grey")
  assert(math.abs(dc[4] - 0.5) < 0.01, key .. ": disabled glyph at ~0.5 alpha")
  btn.scripts.OnEnter(btn)
  assert(hoverCircle.shown ~= true, key .. ": disabled button has no hover circle")
  btn.scripts.OnLeave(btn)
end

return function()
  local previousPreset = Theme.GetPreset()
  for _, key in ipairs(Theme.ListPresets()) do
    testIconSendButton(key)
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_send_button_hover")
end
