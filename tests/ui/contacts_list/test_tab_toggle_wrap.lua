local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Localization = require("WhisperMessenger.Locale.Localization")

-- On a narrow contacts pane the three footer tabs wrap: Requests moves to its
-- own row and the footer doubles in height. Both skins.

local function createToggle(nativeChrome, width)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, 500)
  local toggle = TabToggle.Create(factory, parent, { initialMode = "whispers", nativeChrome = nativeChrome })
  toggle.frame:SetSize(width, 24)
  toggle.setModes({ "whispers", "groups", "requests" })
  return toggle
end

local function resize(toggle, width)
  toggle.frame:SetSize(width, toggle.frame.height)
  toggle.frame.scripts.OnSizeChanged(toggle.frame)
end

return function()
  Localization.Configure({ language = "enUS" })

  for _, nativeChrome in ipairs({ false, true }) do
    local skin = nativeChrome and "native" or "modern"
    local rowHeight = nativeChrome and TabToggle.NATIVE_HEIGHT or TabToggle.HEIGHT

    -- test_narrow_footer_doubles_its_height
    local toggle = createToggle(nativeChrome, 210)
    assert(toggle.frame.height == 2 * rowHeight, skin .. ": wrapped footer is two rows, got " .. tostring(toggle.frame.height))
    local reserved = toggle.reservedHeightFor(toggle.frame:GetWidth())
    assert(reserved == 2 * rowHeight, skin .. ": list reserves both rows, got " .. tostring(reserved))

    -- test_narrow_footer_moves_requests_to_its_own_row
    local requests = FindUI.ofType(toggle.frame, "Button")[3]
    assert(requests.points[1][1] == "TOPLEFT" and requests.points[1][5] == -rowHeight, skin .. ": Requests starts on the second row")

    -- test_reserved_height_for_is_pure
    assert(toggle.reservedHeightFor(600) == rowHeight, skin .. ": wide pane needs one row")
    assert(toggle.reservedHeightFor(210) == 2 * rowHeight, skin .. ": narrow pane needs two rows")
    assert(toggle.frame.height == 2 * rowHeight, skin .. ": asking does not change the footer")

    -- test_widening_returns_to_one_row
    resize(toggle, 600)
    assert(toggle.frame.height == rowHeight, skin .. ": wide footer is one row again")
    assert(toggle.reservedHeightFor(toggle.frame:GetWidth()) == rowHeight, skin .. ": list reserves one row again")
    assert(requests.points[1][1] == "TOPLEFT" and requests.points[1][4] == -200, skin .. ": Requests back in the right third")

    -- test_two_tabs_never_wrap
    resize(toggle, 150)
    assert(toggle.frame.height == 2 * rowHeight, skin .. ": three tabs wrap at 150px")
    toggle.setModes({ "whispers", "groups" })
    assert(toggle.frame.height == rowHeight, skin .. ": two tabs keep one row")
    assert(toggle.reservedHeightFor(toggle.frame:GetWidth()) == rowHeight, skin .. ": two tabs reserve one row")
    assert(toggle.reservedHeightFor(150) == rowHeight, skin .. ": two tabs need one row")
  end
end
