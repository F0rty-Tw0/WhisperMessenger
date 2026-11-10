local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local TabArrows = require("WhisperMessenger.UI.ContactsList.TabArrows")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")

local function build(create)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  local arrows = create(factory, parent)
  return arrows, parent
end

local function iconOf(btn)
  return FindUI.ofType(btn, "Texture")[1]
end

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- test_modern_arrows_are_16_by_24
do
  local arrows = build(TabArrows.CreateModern)
  for _, btn in ipairs({ arrows.prev, arrows.next }) do
    assert(btn.width == 16 and btn.height == 24, "modern arrow is 16x24, got " .. tostring(btn.width) .. "x" .. tostring(btn.height))
  end
  assert(TabArrows.MODERN_WIDTH == 16, "MODERN_WIDTH is 16")
end

-- test_modern_prev_uses_the_back_icon_unflipped
do
  local arrows = build(TabArrows.CreateModern)
  local icon = iconOf(arrows.prev)
  assert(icon.texturePath == Theme.TEXTURES.title_back_icon, "back arrow uses the back icon")
  assert(icon.texCoords == nil, "back arrow is not mirrored")
end

-- test_modern_next_mirrors_the_back_icon
do
  local arrows = build(TabArrows.CreateModern)
  local icon = iconOf(arrows.next)
  local c = icon.texCoords
  assert(icon.texturePath == Theme.TEXTURES.title_back_icon, "forward arrow uses the back icon")
  assert(c and c[1] == 1 and c[2] == 0 and c[3] == 0 and c[4] == 1, "forward arrow mirrors the icon horizontally")
end

-- test_modern_disabled_arrow_is_dimmer
do
  local arrows = build(TabArrows.CreateModern)
  local icon = iconOf(arrows.prev)
  TabArrows.PaintModern(arrows.prev, true)
  local enabledAlpha = icon.alpha
  TabArrows.PaintModern(arrows.prev, false)
  assert(icon.alpha < enabledAlpha, "disabled arrow is dimmer: " .. tostring(icon.alpha) .. " vs " .. tostring(enabledAlpha))
end

-- test_modern_hover_brightens_an_enabled_arrow
do
  local arrows = build(TabArrows.CreateModern)
  local prev = arrows.prev
  local icon = iconOf(prev)
  TabArrows.PaintModern(prev, true)
  local resting = icon.vertexColor
  prev.scripts.OnEnter(prev)
  assert(not sameColor(icon.vertexColor, resting), "hover changes the icon colour")
  prev.scripts.OnLeave(prev)
  assert(sameColor(icon.vertexColor, resting), "leaving restores the resting colour")
end

-- test_modern_hover_keeps_a_disabled_arrow_dim
do
  local arrows = build(TabArrows.CreateModern)
  local prev = arrows.prev
  local icon = iconOf(prev)
  TabArrows.PaintModern(prev, false)
  local resting, restingAlpha = icon.vertexColor, icon.alpha
  prev.scripts.OnEnter(prev)
  assert(sameColor(icon.vertexColor, resting) and icon.alpha == restingAlpha, "a disabled arrow does not light up on hover")
end

-- test_native_arrows_use_spellbook_page_buttons
do
  local arrows = build(TabArrows.CreateNative)
  local prev, nextBtn = arrows.prev, arrows.next
  assert(prev.normalTexture == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "prev normal")
  assert(prev.pushedTexture == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down", "prev pushed")
  assert(prev.disabledTexture == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled", "prev disabled")
  assert(nextBtn.normalTexture == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "next normal")
  assert(nextBtn.pushedTexture == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down", "next pushed")
  assert(nextBtn.disabledTexture == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled", "next disabled")
  for _, btn in ipairs({ prev, nextBtn }) do
    assert(btn.width == 24 and btn.height == 24, "native arrow is 24x24")
  end
  assert(TabArrows.NATIVE_SIZE == 24, "NATIVE_SIZE is 24")
end

-- test_native_arrows_light_up_on_hover
do
  local arrows = build(TabArrows.CreateNative)
  for _, btn in ipairs({ arrows.prev, arrows.next }) do
    local highlight = btn.highlightTexture
    assert(highlight ~= nil, "native arrow has a highlight texture")
    assert(highlight.texturePath == NativeArt.ICON_GLOW, "native arrow glows with the icon glow, got " .. tostring(highlight.texturePath))
    assert(highlight.blendMode == "ADD", "native arrow glow is additive, got " .. tostring(highlight.blendMode))
  end
end

-- test_modern_arrows_have_no_highlight_texture
do
  local arrows = build(TabArrows.CreateModern)
  for _, btn in ipairs({ arrows.prev, arrows.next }) do
    assert(btn.highlightTexture == nil, "modern arrow has no highlight texture")
  end
end

-- test_arrows_are_children_of_the_given_parent
do
  for _, create in ipairs({ TabArrows.CreateModern, TabArrows.CreateNative }) do
    local arrows, parent = build(create)
    assert(arrows.prev:GetParent() == parent and arrows.next:GetParent() == parent, "arrows sit under the given parent")
    local buttons = FindUI.ofType(parent, "Button")
    assert(buttons[1] == arrows.prev and buttons[2] == arrows.next, "prev is created before next")
  end
end
