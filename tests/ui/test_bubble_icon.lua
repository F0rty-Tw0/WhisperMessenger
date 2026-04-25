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

  -- test_incoming_icon_right_click_opens_player_menu
  -- Right-clicking the class icon next to an incoming bubble opens the WoW
  -- context menu for that player (same menu as right-clicking a name in the
  -- default chat).
  do
    local bubbleFrame = makeBubbleFrame()
    local opened
    local msg = {
      direction = "in",
      classTag = "MAGE",
      playerName = "Jaina-Proudmoore",
      guid = "Player-1-AAAA",
      channel = "WOW",
    }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "in", {
      openPlayerMenu = function(message, anchor)
        opened = { message = message, anchor = anchor }
        return true
      end,
    })

    assert(result.frame.mouseEnabled == true, "expected the incoming icon frame to be mouse-enabled")
    local handler = result.frame.scripts and result.frame.scripts.OnMouseUp
    assert(type(handler) == "function", "expected OnMouseUp handler on the incoming icon frame")

    handler(result.frame, "LeftButton")
    assert(opened == nil, "left-clicking the icon must not open the player menu")

    handler(result.frame, "RightButton")
    assert(opened ~= nil, "right-clicking the icon should open the player menu")
    assert(opened.message == msg, "expected the original message forwarded to the opener")
    assert(opened.anchor == result.frame, "expected the icon frame as the menu anchor")
  end

  -- test_outgoing_icon_does_not_open_player_menu
  -- The outgoing icon represents you — there is no remote player to target.
  do
    local bubbleFrame = makeBubbleFrame()
    local opened = false
    _G.UnitClass = nil
    local msg = { direction = "out" }
    local result = BubbleIcon.CreateIcon(factory, parent, bubbleFrame, msg, "out", {
      openPlayerMenu = function()
        opened = true
        return true
      end,
    })

    local handler = result.frame.scripts and result.frame.scripts.OnMouseUp
    if type(handler) == "function" then
      handler(result.frame, "RightButton")
    end
    assert(opened == false, "outgoing icon must not open a player menu")
  end
end
