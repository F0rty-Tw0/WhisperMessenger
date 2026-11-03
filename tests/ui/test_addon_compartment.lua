local AddonCompartment = require("WhisperMessenger.UI.MinimapIcon.AddonCompartment")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Retail's addon compartment (the addon list button by the minimap): one
-- entry that opens the messenger and shows the unread number.
local function fakeCompartment()
  local frame = { entries = {} }
  function frame:RegisterAddon(data)
    self.entries[#self.entries + 1] = data
  end
  return frame
end

local function withCompartment(frame, fn)
  local saved = rawget(_G, "AddonCompartmentFrame")
  rawset(_G, "AddonCompartmentFrame", frame)
  local ok, err = pcall(fn)
  rawset(_G, "AddonCompartmentFrame", saved)
  assert(ok, err)
end

local function recorder()
  local calls = { toggles = 0, marks = 0 }
  local options = {
    onToggle = function()
      calls.toggles = calls.toggles + 1
    end,
    onMarkAllRead = function()
      calls.marks = calls.marks + 1
    end,
  }
  return calls, options
end

local function click(data, buttonName)
  data.func(data, { buttonName = buttonName }, {})
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_registers_one_entry_with_the_minimap_icon_art
  withCompartment(fakeCompartment(), function()
    local entry = AddonCompartment.Register({})
    local frame = _G.AddonCompartmentFrame
    assert(entry ~= nil, "an entry comes back")
    assert(#frame.entries == 1, "one entry, got " .. #frame.entries)
    assert(frame.entries[1].text == "Whisper Messenger", "got " .. tostring(frame.entries[1].text))
    assert(frame.entries[1].icon == "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png", "minimap icon art")
  end)

  -- test_no_compartment_registers_nothing
  withCompartment(nil, function()
    assert(AddonCompartment.Register({}) == nil, "no compartment, no entry")
  end)

  -- test_compartment_without_register_method_registers_nothing
  withCompartment({}, function()
    assert(AddonCompartment.Register({}) == nil, "no RegisterAddon, no entry")
  end)

  -- test_left_click_toggles_the_window
  withCompartment(fakeCompartment(), function()
    local calls, options = recorder()
    AddonCompartment.Register(options)
    click(_G.AddonCompartmentFrame.entries[1], "LeftButton")
    assert(calls.toggles == 1, "toggled once, got " .. calls.toggles)
  end)

  -- test_right_click_does_nothing_like_the_minimap_icon
  withCompartment(fakeCompartment(), function()
    local calls, options = recorder()
    AddonCompartment.Register(options)
    click(_G.AddonCompartmentFrame.entries[1], "RightButton")
    assert(calls.toggles == 0 and calls.marks == 0, "right click is ignored")
  end)

  -- test_shift_left_click_marks_all_read
  withCompartment(fakeCompartment(), function()
    local savedShift = rawget(_G, "IsShiftKeyDown")
    rawset(_G, "IsShiftKeyDown", function()
      return true
    end)
    local calls, options = recorder()
    AddonCompartment.Register(options)
    click(_G.AddonCompartmentFrame.entries[1], "LeftButton")
    rawset(_G, "IsShiftKeyDown", savedShift)
    assert(calls.marks == 1 and calls.toggles == 0, "shift-click marks all read, window untouched")
  end)

  -- test_unread_count_shows_in_the_entry_text
  withCompartment(fakeCompartment(), function()
    local entry = AddonCompartment.Register({})
    local data = _G.AddonCompartmentFrame.entries[1]
    entry.setUnreadCount(3, 1)
    assert(data.text == "Whisper Messenger (3)", "got " .. tostring(data.text))
    entry.setUnreadCount(0, 0)
    assert(data.text == "Whisper Messenger", "count clears, got " .. tostring(data.text))
  end)

  -- test_tooltip_shows_the_unread_split_and_hints
  withCompartment(fakeCompartment(), function()
    local lines = {}
    local savedTooltip = rawget(_G, "GameTooltip")
    local hidden = false
    rawset(_G, "GameTooltip", {
      SetOwner = function() end,
      SetText = function(_, text)
        lines[#lines + 1] = text
      end,
      AddLine = function(_, text)
        lines[#lines + 1] = text
      end,
      Show = function() end,
      Hide = function()
        hidden = true
      end,
    })
    local entry = AddonCompartment.Register({})
    local data = _G.AddonCompartmentFrame.entries[1]
    entry.setUnreadCount(3, 1)
    data.funcOnEnter({})
    data.funcOnLeave({})
    rawset(_G, "GameTooltip", savedTooltip)
    local text = table.concat(lines, "\n")
    assert(lines[1] == "Whisper Messenger", "title first, got " .. tostring(lines[1]))
    assert(string.find(text, "1 unread, 2 in addon pages", 1, true), "unread split, got " .. text)
    assert(string.find(text, "Shift-click: mark all as read", 1, true), "click hint, got " .. text)
    assert(hidden, "leaving hides the tooltip")
  end)
end
