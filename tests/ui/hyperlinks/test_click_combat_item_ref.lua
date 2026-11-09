-- In combat a plain click on an item link in our frames must not reach
-- Blizzard's SetItemRef: it opens the pinned item tooltip through ShowUIPanel,
-- which refuses addon code in combat and prints "Interface action failed
-- because of an AddOn". The click pins the tooltip directly instead, the way
-- SetItemRef does without the panel call.
local FakeUI = require("tests.helpers.fake_ui")
local WriteWatch = require("tests.helpers.write_watch")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local ITEM_LINK = "item:6948"
local STUBBED = { "ChatFrameMixin", "SetItemRef", "ShowUIPanel", "InCombatLockdown", "IsModifiedClick", "ItemRefTooltip", "UIParent", "LinkUtil" }

local function newTooltip(calls, opts)
  local tooltip = { shown = opts.shown == true }
  function tooltip.IsShown(self)
    return self.shown
  end
  function tooltip.SetOwner(_self, owner, anchor)
    calls[#calls + 1] = "SetOwner " .. tostring(owner and owner.name) .. " " .. anchor
  end
  local setterName = opts.classic and "SetHyperlink" or "ItemRefSetHyperlink"
  rawset(tooltip, setterName, function(_self, link)
    calls[#calls + 1] = setterName .. " " .. link
  end)
  return tooltip
end

-- opts: combat, modified, tooltip (false = none), shown, classic,
-- registered (link types with a Blizzard handler).
local function withClickEnv(opts, fn)
  local saved = {}
  for _, key in ipairs(STUBBED) do
    saved[key] = rawget(_G, key)
  end
  local calls = {}
  local mixinWrites = {}
  local registered = opts.registered or {}
  -- A click may call Blizzard's handler but never assign into the mixin.
  rawset(
    _G,
    "ChatFrameMixin",
    WriteWatch.Wrap("ChatFrameMixin", {
      OnHyperlinkClick = function(_self, link)
        calls[#calls + 1] = "blizzard " .. link
      end,
    }, mixinWrites)
  )
  rawset(_G, "SetItemRef", function(link)
    calls[#calls + 1] = "SetItemRef " .. link
  end)
  rawset(_G, "ShowUIPanel", function(_panel)
    calls[#calls + 1] = "ShowUIPanel"
  end)
  rawset(_G, "InCombatLockdown", function()
    return opts.combat ~= false
  end)
  rawset(_G, "IsModifiedClick", function()
    return opts.modified == true
  end)
  rawset(_G, "ItemRefTooltip", opts.tooltip ~= false and newTooltip(calls, opts) or nil)
  rawset(_G, "UIParent", { name = "UIParent" })
  rawset(_G, "LinkUtil", {
    IsLinkHandlerRegistered = function(linkType)
      return registered[linkType] == true
    end,
  })
  local ok, err = pcall(fn, calls)
  for _, key in ipairs(STUBBED) do
    rawset(_G, key, saved[key])
  end
  if not ok then
    error(err, 0)
  end
  assert(#mixinWrites == 0, "a click assigned " .. table.concat(mixinWrites, ", "))
end

local function click(link, onLinkClick)
  local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
  Hyperlinks.EnableOn(frame, onLinkClick)
  frame:GetScript("OnHyperlinkClick")(frame, link, "[" .. link .. "]", "LeftButton")
end

return function()
  -- test_plain_item_click_in_combat_pins_item_ref_tooltip_without_show_ui_panel
  withClickEnv({ registered = { item = true } }, function(calls)
    local callbacks = 0
    click(ITEM_LINK, function()
      callbacks = callbacks + 1
    end)
    assert(
      table.concat(calls, ", ") == "SetOwner UIParent ANCHOR_PRESERVE, ItemRefSetHyperlink " .. ITEM_LINK,
      "expected the tooltip pinned without Blizzard's handler, got " .. table.concat(calls, ", ")
    )
    assert(callbacks == 1, "the caller's callback should run once, ran " .. callbacks)
  end)

  -- test_plain_item_click_in_combat_keeps_an_open_item_ref_tooltip_in_place
  withClickEnv({ shown = true }, function(calls)
    click(ITEM_LINK)
    assert(table.concat(calls, ", ") == "ItemRefSetHyperlink " .. ITEM_LINK, "an open tooltip keeps its owner, got " .. table.concat(calls, ", "))
  end)

  -- test_plain_item_click_in_combat_uses_set_hyperlink_on_classic
  withClickEnv({ classic = true }, function(calls)
    click(ITEM_LINK)
    assert(calls[2] == "SetHyperlink " .. ITEM_LINK and #calls == 2, "Classic pins with SetHyperlink, got " .. table.concat(calls, ", "))
  end)

  -- test_plain_spell_click_in_combat_pins_item_ref_tooltip
  withClickEnv({ registered = { spell = true } }, function(calls)
    click("spell:133")
    assert(calls[2] == "ItemRefSetHyperlink spell:133", "spell links fall through to the tooltip too, got " .. table.concat(calls, ", "))
  end)

  -- test_link_type_without_blizzard_handler_in_combat_pins_item_ref_tooltip
  withClickEnv({}, function(calls)
    click("achievement:6:Player-1:0:0:0:0")
    assert(calls[2] == "ItemRefSetHyperlink achievement:6:Player-1:0:0:0:0", "unhandled types reach the tooltip, got " .. table.concat(calls, ", "))
  end)

  -- test_link_type_with_blizzard_handler_in_combat_goes_to_blizzard
  withClickEnv({ registered = { garrfollower = true } }, function(calls)
    click("garrfollower:1")
    assert(table.concat(calls, ", ") == "blizzard garrfollower:1", "handled types stay with Blizzard, got " .. table.concat(calls, ", "))
  end)

  -- test_modified_item_click_in_combat_goes_to_blizzard
  withClickEnv({ modified = true }, function(calls)
    click(ITEM_LINK)
    assert(table.concat(calls, ", ") == "blizzard " .. ITEM_LINK, "a modified click stays with Blizzard, got " .. table.concat(calls, ", "))
  end)

  -- test_item_click_out_of_combat_goes_to_blizzard
  withClickEnv({ combat = false }, function(calls)
    click(ITEM_LINK)
    assert(table.concat(calls, ", ") == "blizzard " .. ITEM_LINK, "out of combat Blizzard handles the click, got " .. table.concat(calls, ", "))
  end)

  -- test_item_click_in_combat_without_item_ref_tooltip_goes_to_blizzard
  withClickEnv({ tooltip = false }, function(calls)
    local callbacks = 0
    click(ITEM_LINK, function()
      callbacks = callbacks + 1
    end)
    assert(table.concat(calls, ", ") == "blizzard " .. ITEM_LINK, "without the tooltip Blizzard handles the click, got " .. table.concat(calls, ", "))
    assert(callbacks == 1, "the callback should still run once, ran " .. callbacks)
  end)
end
