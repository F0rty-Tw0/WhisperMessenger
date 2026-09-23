local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local function factionIconFor(factory, factionName)
  local row = factory.CreateFrame("Button", nil, nil)
  row.title = factory.CreateFrame("FontString", nil, row)
  row.title:SetText("Alice")
  local item = { displayName = "Alice", classTag = "WARRIOR", factionName = factionName }
  return RowElements.createFactionIcon(factory, row, item, {})
end

return function()
  local previousPreset = Theme.GetPreset()
  local previousFactionGroup = _G.UnitFactionGroup
  local factory = FakeUI.NewFactory()
  _G.UnitFactionGroup = function(unit)
    assert(unit == "player", "expected player faction lookup")
    return "Alliance", "Alliance"
  end

  -- test_modern_hides_same_faction_icon
  Theme.SetPreset("wow_default")
  assert(factionIconFor(factory, "Alliance").shown == false, "modern: same-faction contact should not show a faction icon")

  -- test_modern_shows_cross_faction_icon
  local horde = factionIconFor(factory, "Horde")
  assert(horde.shown == true, "modern: cross-faction contact should show the faction icon")
  assert(string.find(horde.texturePath or "", "Horde") ~= nil, "modern: cross-faction icon should be Horde")

  -- test_azeroth_hides_same_faction_icon_too
  Theme.SetPreset("wow_native")
  assert(factionIconFor(factory, "Alliance").shown == false, "azeroth: same-faction contact should not show a faction icon")

  -- test_unknown_player_faction_keeps_icon
  Theme.SetPreset("wow_default")
  _G.UnitFactionGroup = nil
  assert(factionIconFor(factory, "Alliance").shown == true, "modern: without player faction info the icon stays visible")

  _G.UnitFactionGroup = previousFactionGroup
  Theme.SetPreset(previousPreset)
  print("PASS: test_row_faction_icon")
end
