local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_create_class_icon_with_known_class
  do
    local row = factory.CreateFrame("Frame", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = "WARRIOR",
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    local icon = RowElements.createClassIcon(factory, row, item)
    assert(icon ~= nil, "createClassIcon should return an icon table")
    assert(icon.frame ~= nil, "icon should have a frame")
    assert(icon.texture ~= nil, "icon should have a texture")
    assert(
      icon.texture.texturePath ~= nil,
      "icon texture should be set for known class, got: " .. tostring(icon.texture.texturePath)
    )
    assert(
      string.find(icon.texture.texturePath, "WARRIOR") ~= nil,
      "icon texture path should contain class tag, got: " .. tostring(icon.texture.texturePath)
    )
  end

  -- test_create_class_icon_without_class_uses_bnet
  do
    local row = factory.CreateFrame("Frame", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = nil,
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    local icon = RowElements.createClassIcon(factory, row, item)
    assert(icon ~= nil, "createClassIcon should return an icon table")
    assert(icon.texture ~= nil, "icon should have a texture")
    assert(
      icon.texture.texturePath ~= nil,
      "icon texture should be set for BNet fallback, got: " .. tostring(icon.texture.texturePath)
    )
    assert(
      string.find(icon.texture.texturePath, "Toast") ~= nil
        or string.find(icon.texture.texturePath, "bnet") ~= nil
        or string.find(icon.texture.texturePath, "Chat") ~= nil,
      "icon texture should be bnet icon, got: " .. tostring(icon.texture.texturePath)
    )
  end

  -- test_create_name_label_sets_text
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = "WARRIOR",
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    local label = RowElements.createNameLabel(row, item, 260)
    assert(label ~= nil, "createNameLabel should return a FontString")
    assert(label.text == "Alice", "name label should have displayName text, got: " .. tostring(label.text))
  end

  -- test_create_name_label_ellipsizes_when_width_is_tight
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.classIconFrame = factory.CreateFrame("Frame", nil, row)
    local item = {
      displayName = "VeryVeryLongContactNameForTinyPane",
      classTag = "MAGE",
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }

    local label = RowElements.createNameLabel(row, item, 140)
    assert(label ~= nil, "createNameLabel should return a FontString for narrow rows")
    assert(string.sub(label.text or "", -3) == "...", "expected long contact name to end with ellipsis")
    assert(
      label:GetStringWidth() <= label:GetWidth(),
      "expected ellipsized name width to fit label width"
    )
  end

  -- test_update_name_label_recalculates_width_on_resize
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.classIconFrame = factory.CreateFrame("Frame", nil, row)
    local item = {
      displayName = "Alice",
      classTag = "WARRIOR",
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }

    local label = RowElements.createNameLabel(row, item, 260)
    RowElements.updateNameLabel(row, item, 180)
    local expectedWidth = 180
      - Theme.LAYOUT.CONTACT_ICON_SIZE
      - Theme.LAYOUT.CONTACT_PADDING
      - 10
      - (4 + 14 + 2)
    assert(label.width == expectedWidth, "expected name label width to track parent resize")
  end


  -- test_faction_icon_keeps_right_margin
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.classIconFrame = factory.CreateFrame("Frame", nil, row)
    local item = {
      displayName = "VeryVeryLongFactionNameContact",
      classTag = "PALADIN",
      raceTag = "Human",
      factionName = "Alliance",
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    local ns_stub = {
      Identity = {
        InferFaction = function(raceTag)
          if raceTag == "Human" then
            return "Alliance"
          end
          return nil
        end,
      },
    }

    local label = RowElements.createNameLabel(row, item, 180)
    local tex = RowElements.createFactionIcon(factory, row, item, ns_stub)
    assert(label ~= nil and tex ~= nil, "expected name label and faction icon")
    local maxOffset = label.width - Theme.LAYOUT.CONTACT_FACTION_SIZE - 1
    assert(
      tex.point[4] <= maxOffset,
      "expected faction icon to preserve 1px right margin, got offset "
        .. tostring(tex.point[4])
        .. " > "
        .. tostring(maxOffset)
    )
  end


  -- test_create_faction_icon_for_alliance
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = "WARRIOR",
      raceTag = "Human",
      factionName = "Alliance",
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    -- Provide a fake title with GetStringWidth
    row.title = factory.CreateFrame("FontString", nil, row)
    row.title:SetText("Alice")
    local ns_stub = {
      Identity = {
        InferFaction = function(raceTag)
          if raceTag == "Human" then
            return "Alliance"
          end
          return nil
        end,
      },
    }
    local tex = RowElements.createFactionIcon(factory, row, item, ns_stub)
    assert(tex ~= nil, "createFactionIcon should return a texture for Alliance")
    assert(tex.shown == true, "faction icon should be shown for Alliance")
    assert(
      string.find(tex.texturePath or "", "Alliance") ~= nil,
      "faction texture should be Alliance, got: " .. tostring(tex.texturePath)
    )
  end

  -- test_create_faction_icon_for_horde
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Bob",
      classTag = "SHAMAN",
      raceTag = "Orc",
      factionName = "Horde",
      lastActivityAt = 100,
      lastPreview = "hi",
    }
    row.title = factory.CreateFrame("FontString", nil, row)
    row.title:SetText("Bob")
    local ns_stub = {
      Identity = {
        InferFaction = function(raceTag)
          if raceTag == "Orc" then
            return "Horde"
          end
          return nil
        end,
      },
    }
    local tex = RowElements.createFactionIcon(factory, row, item, ns_stub)
    assert(tex ~= nil, "createFactionIcon should return a texture for Horde")
    assert(tex.shown == true, "faction icon should be shown for Horde")
    assert(
      string.find(tex.texturePath or "", "Horde") ~= nil,
      "faction texture should be Horde, got: " .. tostring(tex.texturePath)
    )
  end

  -- test_create_faction_icon_returns_nil_for_unknown
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Carol",
      classTag = nil,
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hey",
    }
    row.title = factory.CreateFrame("FontString", nil, row)
    row.title:SetText("Carol")
    local ns_stub = {}
    local tex = RowElements.createFactionIcon(factory, row, item, ns_stub)
    -- nil or hidden — either is acceptable for unknown faction
    if tex ~= nil then
      assert(tex.shown ~= true, "faction icon should be hidden for unknown race/faction")
    end
  end

  -- test_create_timestamp_returns_font_string
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = nil,
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "hello",
    }
    local ns_stub = {
      TimeFormat = {
        ContactPreview = function(_t)
          return "5m"
        end,
      },
    }
    local label = RowElements.createTimestamp(row, item, ns_stub)
    assert(label ~= nil, "createTimestamp should return a FontString")
    assert(label.text == "5m", "timestamp label should have formatted text, got: " .. tostring(label.text))
  end

  -- test_create_preview_returns_font_string
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      displayName = "Alice",
      classTag = nil,
      raceTag = nil,
      factionName = nil,
      lastActivityAt = 100,
      lastPreview = "last message here",
    }
    local label = RowElements.createPreview(row, item, 260)
    assert(label ~= nil, "createPreview should return a FontString")
    assert(
      label.text == "last message here",
      "preview label should have lastPreview text, got: " .. tostring(label.text)
    )
  end
end
