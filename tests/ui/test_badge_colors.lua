local FakeUI = require("tests.helpers.fake_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local Theme = require("WhisperMessenger.UI.Theme")
local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

local MODERN_PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark", "wow_native" }

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

-- WCAG relative luminance / contrast ratio.
local function channel(c)
  return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(c)
  return 0.2126 * channel(c[1]) + 0.7152 * channel(c[2]) + 0.0722 * channel(c[3])
end
local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  if la < lb then
    la, lb = lb, la
  end
  return (la + 0.05) / (lb + 0.05)
end

-- Build every unread badge the addon shows, each with a count so it is visible.
local function buildBadges(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 500)

  local row = factory.CreateFrame("Button", nil, parent)
  RowElements.createUnreadBadge(factory, row)
  local rowItem = { unreadCount = 3 }
  RowElements.updateUnreadBadge(row, rowItem)

  local toggle = TabToggle.Create(factory, parent, { initialMode = "whispers" })
  toggle.setUnreadCounts(0, 6)

  local widget = ToggleIcon.Create(factory, { unreadCount = 2 })
  local minimapParent = factory.CreateFrame("Frame", "Minimap", nil)
  minimapParent:SetSize(140, 140)
  local minimap = MinimapIcon.Create(factory, { parent = minimapParent, unreadCount = 2 })

  local function rebind()
    RowElements.updateUnreadBadge(row, rowItem)
    toggle.setUnreadCounts(0, 6)
    widget.refreshTheme()
    minimap.refreshTheme()
  end

  return {
    rebind = rebind,
    list = {
      { name = "row", bg = row.unreadBadge.background, label = row.unreadBadge.label },
      { name = "tab", bg = TabParts.badgeBg(TabParts.groups(toggle).badge), label = TabParts.badgeLabel(TabParts.groups(toggle).badge) },
      { name = "widget", bg = widget.badgeBackground, label = widget.badgeLabel },
      { name = "minimap", bg = minimap.badgeBackground, label = minimap.badgeLabel },
    },
  }
end

local function assertPainted(badges, bg, text, context)
  for _, b in ipairs(badges.list) do
    assert(colorsMatch(b.bg.vertexColor, bg), context .. ": " .. b.name .. " badge bg mismatch")
    assert(colorsMatch(b.label.textColor, text), context .. ": " .. b.name .. " badge text mismatch")
  end
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  -- test_modern_badge_pair_is_accent_with_readable_text
  for _, key in ipairs(MODERN_PRESETS) do
    Theme.SetPreset(key)
    local bg, text = Theme.BadgeColors()
    assert(colorsMatch(bg, Theme.COLORS.accent), key .. ": badge bg is the accent")
    assert(colorsMatch(text, Theme.COLORS.unread_badge_text), key .. ": badge text is unread_badge_text")
    local ratio = contrast(text, bg)
    assert(ratio >= 4.5, key .. ": badge text readable, got " .. string.format("%.2f", ratio))
  end

  -- test_every_badge_uses_the_shared_pair_on_modern
  Theme.SetPreset("wow_default")
  local badges = buildBadges(factory)
  assertPainted(badges, Theme.COLORS.unread_badge, Theme.COLORS.unread_badge_text, "wow_default")

  -- test_every_badge_is_smooth_and_shadowless: unsnapped circle edge, no
  -- inherited drop shadow thickening the digits.
  for _, b in ipairs(badges.list) do
    assert(b.bg.snapToPixelGrid == false and b.bg.texelSnappingBias == 0, b.name .. " badge circle should not be texel-snapped")
    local shadow = b.label.shadowOffset
    assert(shadow and shadow[1] == 0 and shadow[2] == 0, b.name .. " badge label shadow should be off")
  end

  -- test_every_badge_repaints_after_preset_switch
  Theme.SetPreset("plumber_warm")
  badges.rebind()
  assertPainted(badges, Theme.COLORS.unread_badge, Theme.COLORS.unread_badge_text, "plumber_warm")

  -- test_azeroth_badges_use_the_shared_pair
  Theme.SetPreset("wow_native")
  badges.rebind()
  assertPainted(badges, Theme.COLORS.unread_badge, Theme.COLORS.unread_badge_text, "wow_native")

  Theme.SetPreset(previousPreset)
  print("PASS: test_badge_colors")
end
