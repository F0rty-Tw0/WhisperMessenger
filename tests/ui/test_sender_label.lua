local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

local function findChildWithText(frame, text)
  for _, child in ipairs(frame.children) do
    if child.text == text then
      return child
    end
  end

  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_creates_label_for_incoming_message
  do
    local message = {
      direction = "in",
      kind = "user",
      text = "hello",
      sentAt = 1000,
      playerName = "Arthas",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result ~= nil, "expected CreateSenderLabel to return a result")
    assert(result.frame ~= nil, "expected result to have a frame")

    local nameFS = findChildWithText(result.frame, "Arthas")
    assert(nameFS ~= nil, "expected a FontString with playerName 'Arthas'")
    assert(nameFS.point ~= nil, "expected incoming name label to have an anchor")
    assert(nameFS.point[1] == "LEFT", "expected incoming name anchor LEFT, got " .. tostring(nameFS.point[1]))
    assert(nameFS.point[2] == result.frame, "expected incoming name label to anchor to its frame")
    assert(
      nameFS.point[3] == "LEFT",
      "expected incoming name label relative point LEFT, got " .. tostring(nameFS.point[3])
    )
    assert(
      nameFS.point[4] == Layout.MESSAGE_EDGE_INSET,
      "expected incoming name label inset "
        .. tostring(Layout.MESSAGE_EDGE_INSET)
        .. ", got "
        .. tostring(nameFS.point[4])
    )
    assert(
      result.frame.point[1] == "TOPLEFT",
      "expected incoming label frame to anchor TOPLEFT, got " .. tostring(result.frame.point[1])
    )
  end

  -- test_creates_label_for_outgoing_message
  do
    local message = {
      direction = "out",
      kind = "user",
      text = "goodbye",
      sentAt = 2000,
      playerName = "Me",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result ~= nil, "expected CreateSenderLabel to return a result")
    assert(result.frame ~= nil, "expected result to have a frame")

    local youFS = findChildWithText(result.frame, "You")
    assert(youFS ~= nil, "expected a FontString with text 'You' for outgoing message")
    assert(youFS.point ~= nil, "expected outgoing name label to have an anchor")
    assert(youFS.point[1] == "RIGHT", "expected outgoing name anchor RIGHT, got " .. tostring(youFS.point[1]))
    assert(youFS.point[2] == result.frame, "expected outgoing name label to anchor to its frame")
    assert(
      youFS.point[3] == "RIGHT",
      "expected outgoing name label relative point RIGHT, got " .. tostring(youFS.point[3])
    )
    assert(
      youFS.point[4] == -Layout.MESSAGE_EDGE_INSET,
      "expected outgoing name label inset -"
        .. tostring(Layout.MESSAGE_EDGE_INSET)
        .. ", got "
        .. tostring(youFS.point[4])
    )
    assert(
      result.frame.point[1] == "TOPRIGHT",
      "expected outgoing label frame to anchor TOPRIGHT, got " .. tostring(result.frame.point[1])
    )
  end

  -- test_outgoing_label_shows_sender_charname_when_different_from_current_player
  -- The "You" word stays plain while the " · <CharName>" suffix matches the
  -- incoming "· via <Channel>" suffix (gold, middle-dot separator).
  do
    local previousUnitName = _G.UnitName
    _G.UnitName = function()
      return "Jaina"
    end
    local message = {
      direction = "out",
      kind = "user",
      text = "from my other char",
      sentAt = 2500,
      playerName = "Recipient",
      senderName = "Arthas",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)

    local youFS = findChildWithText(result.frame, "You")
    assert(youFS ~= nil, "expected plain 'You' fontstring")

    local suffixFS = findChildWithText(result.frame, "\194\183 Arthas")
    assert(
      suffixFS ~= nil,
      "expected separate '· Arthas' suffix fontstring (middle-dot, gold), mirroring '· via <Channel>'"
    )
    -- Same gold tint the channel tag uses: 0.96, 0.78, 0.24, 1.0.
    local tc = suffixFS.textColor
    assert(
      tc ~= nil and math.abs(tc[1] - 0.96) < 0.01 and math.abs(tc[2] - 0.78) < 0.01 and math.abs(tc[3] - 0.24) < 0.01,
      "expected charname suffix to be tinted gold like channel tag, got: " .. tostring(tc and tc[1])
    )

    _G.UnitName = previousUnitName
  end

  -- test_outgoing_label_shows_plain_you_when_senderName_matches_current_player
  do
    local previousUnitName = _G.UnitName
    _G.UnitName = function()
      return "Arthas"
    end
    local message = {
      direction = "out",
      kind = "user",
      text = "from this char",
      sentAt = 2600,
      playerName = "Recipient",
      senderName = "Arthas",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    local plainYou = findChildWithText(result.frame, "You")
    assert(plainYou ~= nil, "expected plain 'You' when senderName matches current player")
    _G.UnitName = previousUnitName
  end

  -- test_outgoing_label_without_senderName_stays_plain_you
  do
    local previousUnitName = _G.UnitName
    _G.UnitName = function()
      return "Jaina"
    end
    local message = {
      direction = "out",
      kind = "user",
      text = "legacy message",
      sentAt = 2700,
      playerName = "Recipient",
      -- senderName absent (legacy history)
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    local plainYou = findChildWithText(result.frame, "You")
    assert(plainYou ~= nil, "expected plain 'You' when message has no senderName")
    _G.UnitName = previousUnitName
  end

  -- test_returns_height_18
  do
    local message = {
      direction = "in",
      kind = "user",
      text = "test",
      sentAt = 3000,
      playerName = "Bob",
    }
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
    assert(result.height == 18, "expected returned height to be 18, got " .. tostring(result.height))
  end
end
