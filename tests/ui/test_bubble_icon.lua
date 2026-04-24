local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local BubbleIcon = require("WhisperMessenger.UI.ChatBubble.BubbleIcon")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  -- Helper: make a minimal bubbleFrame with SetPoint
  local function makeBubbleFrame()
    return factory.CreateFrame("Frame", nil, parent)
  end

  -- test_creates_icon_for_incoming_with_class_tag
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "in", classTag = "DRUID" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "in", {})
    assert(result ~= nil, "expected result table")
    assert(result.frame ~= nil, "expected result.frame")
    assert(result.texture ~= nil, "expected result.texture")
    assert(
      result.texture.texturePath == Theme.ClassIcon("DRUID"),
      "expected DRUID class icon, got " .. tostring(result.texture.texturePath)
    )
  end

  -- test_creates_icon_for_incoming_without_class_uses_bnet
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "in" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "in", {})
    assert(result ~= nil, "expected result")
    assert(
      result.texture.texturePath == Theme.TEXTURES.bnet_icon,
      "expected bnet_icon fallback, got " .. tostring(result.texture.texturePath)
    )
  end

  -- test_creates_icon_for_incoming_with_fallback_class_tag
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "in" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "in", { fallbackClassTag = "MAGE" })
    assert(
      result.texture.texturePath == Theme.ClassIcon("MAGE"),
      "expected MAGE class icon from fallback, got " .. tostring(result.texture.texturePath)
    )
  end

  -- test_creates_icon_for_outgoing (no UnitClass in stub, falls back to armory)
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "out" }
    -- _G.UnitClass is not set in fake env, so falls back to armory icon
    _G.UnitClass = nil
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "out", {})
    assert(result ~= nil, "expected result for outgoing")
    assert(
      result.texture.texturePath == "Interface\\CHATFRAME\\UI-ChatIcon-ArmoryChat",
      "expected armory fallback for outgoing, got " .. tostring(result.texture.texturePath)
    )
  end

  -- test_outgoing_prefers_stored_senderClassTag_over_current_player
  -- Regression: messages sent from Char A must still show Char A's icon after
  -- relogging to Char B. The stored senderClassTag wins over live UnitClass.
  do
    local bubbleFrame = makeBubbleFrame()
    _G.UnitClass = function()
      return "Paladin", "PALADIN"
    end
    local msg = { direction = "out", senderClassTag = "PRIEST" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "out", {})
    assert(
      result.texture.texturePath == Theme.ClassIcon("PRIEST"),
      "expected stored PRIEST icon over live PALADIN, got " .. tostring(result.texture.texturePath)
    )
    _G.UnitClass = nil
  end

  -- test_outgoing_falls_back_to_live_UnitClass_when_no_stored_class
  -- Back-compat: legacy messages without senderClassTag still get an icon.
  do
    local bubbleFrame = makeBubbleFrame()
    _G.UnitClass = function()
      return "Paladin", "PALADIN"
    end
    local msg = { direction = "out" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "out", {})
    assert(
      result.texture.texturePath == Theme.ClassIcon("PALADIN"),
      "expected live PALADIN fallback, got " .. tostring(result.texture.texturePath)
    )
    _G.UnitClass = nil
  end

  -- test_icon_positioned_left_of_bubble_for_incoming
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "in" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "in", {})
    local iconFrame = result.frame
    assert(iconFrame.point ~= nil, "expected point set on icon frame")
    -- point[1]=anchorPoint, point[2]=relativeFrame, point[3]=relativePoint
    assert(
      iconFrame.point[1] == "TOPRIGHT",
      "expected TOPRIGHT anchor for incoming, got " .. tostring(iconFrame.point[1])
    )
    assert(
      iconFrame.point[3] == "TOPLEFT",
      "expected TOPLEFT relative point for incoming, got " .. tostring(iconFrame.point[3])
    )
  end

  -- test_icon_positioned_right_of_bubble_for_outgoing
  do
    local bubbleFrame = makeBubbleFrame()
    local msg = { direction = "out" }
    _G.UnitClass = nil
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "out", {})
    local iconFrame = result.frame
    assert(iconFrame.point ~= nil, "expected point set on icon frame")
    assert(
      iconFrame.point[1] == "TOPLEFT",
      "expected TOPLEFT anchor for outgoing, got " .. tostring(iconFrame.point[1])
    )
    assert(
      iconFrame.point[3] == "TOPRIGHT",
      "expected TOPRIGHT relative point for outgoing, got " .. tostring(iconFrame.point[3])
    )
  end
end
