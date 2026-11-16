local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer.Composer")
local ComposerSurface = require("WhisperMessenger.UI.Composer.ComposerSurface")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local RetailHud = require("tests.helpers.retail_hud")

local CONTACT = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }

local function create(nativeChrome, onSend, factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 60)
  return Composer.Create(factory, parent, CONTACT, onSend or function() end, nil, nil, nil, { nativeChrome = nativeChrome })
end

local function borderTextures(input)
  local out = {}
  for _, child in ipairs(input.children or {}) do
    if child.frameType == "Texture" and child.texturePath == ComposerSurface.NATIVE_BORDER_TEXTURE then
      out[#out + 1] = child
    end
  end
  return out
end

local function atlasPieces(input)
  local out = {}
  for _, child in ipairs(input.children or {}) do
    if child.frameType == "Texture" and child.atlas then
      out[child.atlas] = true
    end
  end
  return out
end

-- The input scroll template's multi-line border pieces on `frame`, by key.
local function templateBorder(frame)
  local keyByPath = {}
  for key, path in pairs(ComposerSurface.NATIVE_INPUT_BORDER) do
    keyByPath[path] = key
  end
  local pieces, count = {}, 0
  for _, child in ipairs(frame and frame.children or {}) do
    local key = child.frameType == "Texture" and keyByPath[child.texturePath]
    if key then
      pieces[key] = child
      count = count + 1
    end
  end
  return pieces, count
end

local CORNERS = { topLeft = "TOPLEFT", topRight = "TOPRIGHT", bottomLeft = "BOTTOMLEFT", bottomRight = "BOTTOMRIGHT" }

-- Nine pieces framing the box edge to edge: 8px corners on the box corners,
-- edges and middle stretched between them; nothing on the scrolling frame.
local function assertTemplateBorder(composer, label)
  local box = composer.box
  local pieces, count = templateBorder(box)
  assert(count == 9, label .. ": 9 border pieces on the box, got " .. count)
  for key, anchor in pairs(CORNERS) do
    local corner = pieces[key]
    assert(corner.width == 8 and corner.height == 8, label .. ": " .. key .. " is 8x8")
    local pt = corner.points and corner.points[1] or {}
    assert(pt[1] == anchor and pt[2] == box and pt[3] == anchor and pt[4] == 0 and pt[5] == 0, label .. ": " .. key .. " sits on the box corner")
  end
  local middle = pieces.middle.points or {}
  assert(middle[1] and middle[1][2] == pieces.left and middle[2] and middle[2][2] == pieces.right, label .. ": middle fills between the edges")
  local _, onScroll = templateBorder(composer.scroll)
  assert(onScroll == 0, label .. ": no border piece on the scrolling frame")
  assert(#borderTextures(box) == 0 and next(atlasPieces(box)) == nil, label .. ": no single-line border art mixed in")
end

local function anyEdgeShown(border)
  for _, edge in pairs(border) do
    if edge.shown then
      return true
    end
  end
  return false
end

return function()
  -- test_native_border_texture_is_blizzards_input_border_path
  do
    local expected = "Interface\\Common\\Common-Input-Border"
    assert(ComposerSurface.NATIVE_BORDER_TEXTURE == expected, "file art path, got " .. tostring(ComposerSurface.NATIVE_BORDER_TEXTURE))
  end

  -- test_search_atlas_names_are_blizzards_input_box_atlases
  do
    local atlas = ComposerSurface.NATIVE_SEARCH_ATLAS
    assert(atlas.left == "common-search-border-left", "left atlas, got " .. tostring(atlas.left))
    assert(atlas.middle == "common-search-border-middle", "middle atlas, got " .. tostring(atlas.middle))
    assert(atlas.right == "common-search-border-right", "right atlas, got " .. tostring(atlas.right))
  end

  -- test_file_border_pieces_use_input_border_slices_and_8px_edges
  do
    local input = FakeUI.NewFactory().CreateFrame("EditBox", nil, nil)
    local pieces = ComposerSurface.CreateNativeBorder(input)
    local expected = {
      left = { 0, 0.0625, 0, 0.625 },
      middle = { 0.0625, 0.9375, 0, 0.625 },
      right = { 0.9375, 1, 0, 0.625 },
    }
    for name, coords in pairs(expected) do
      local got = pieces[name].texCoords or {}
      for i = 1, 4 do
        assert(got[i] == coords[i], name .. " tex coord " .. i .. ", got " .. tostring(got[i]))
      end
    end
    assert(pieces.left.width == 8 and pieces.right.width == 8, "8px edges")
  end

  -- test_native_input_border_files_are_the_input_scroll_templates
  do
    local base = "Interface\\Common\\Common-Input-Border-"
    local suffix =
      { topLeft = "TL", top = "T", topRight = "TR", left = "L", middle = "M", right = "R", bottomLeft = "BL", bottom = "B", bottomRight = "BR" }
    for key, tail in pairs(suffix) do
      local got = ComposerSurface.NATIVE_INPUT_BORDER[key]
      assert(got == base .. tail, key .. " file, got " .. tostring(got))
    end
  end

  -- test_hud_composer_draws_the_multi_line_input_border_on_the_box
  do
    local composer = create(true)
    assert(composer.scroll:GetParent() == composer.box, "HUD: the input scroll frame sits inside the box")
    assertTemplateBorder(composer, "HUD")
  end

  -- test_hud_composer_has_no_custom_fill
  do
    local composer = create(true)
    assert(composer.paneBg.color[4] == 0, "HUD: composer pane background transparent")
    assert(anyEdgeShown(composer.border) == false, "HUD: no custom hairline over the Blizzard art")
    assert(composer.sheen == nil, "HUD: no gloss sheen")
  end

  -- test_hud_theme_refresh_keeps_blizzard_look
  do
    local composer = create(true)
    composer.refreshTheme()
    assert(composer.paneBg.color[4] == 0, "HUD refresh: pane stays transparent")
    local c = composer.input.textColor
    assert(c[1] == 1 and c[2] == 1 and c[3] == 1, "HUD refresh: input text stays Blizzard white")
    assert(anyEdgeShown(composer.border) == false, "HUD refresh: hairline stays hidden")
  end

  -- test_hud_composer_still_sends
  do
    local sent = nil
    local composer = create(true, function(payload)
      sent = payload
    end)
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(sent and sent.text == "hello" and sent.target == "Arthas", "HUD: Enter still sends")
    assert(composer.input:GetText() == "", "HUD: input clears after send")
    assert(composer.sendButton.scripts.OnClick ~= nil and composer.emojiButton.scripts.OnClick ~= nil, "HUD: send + emoji buttons wired")
  end

  -- test_retail_hud_composer_draws_the_same_border
  RetailHud.With(function()
    RetailHud.WithAtlas(true, function()
      assertTemplateBorder(create(true), "retail HUD")
    end)
  end)

  -- test_classic_hud_composer_draws_the_same_border
  Hud.Configure("classic")
  assertTemplateBorder(create(true), "classic HUD")
  Hud.Configure("off")

  -- test_hud_plain_edit_box_gets_the_border_too
  do
    local factory = RetailHud.Factory(FakeUI, { missing = { InputScrollFrameTemplate = true } })
    local composer = create(true, nil, factory)
    assert(composer.box == composer.input, "setup: no template, the edit box is the box")
    assertTemplateBorder(composer, "plain edit box")
  end

  -- test_modern_composer_unchanged
  do
    local composer = create(false)
    assert(#borderTextures(composer.box) == 0, "modern: no Blizzard border art")
    assert(select(2, templateBorder(composer.box)) == 0, "modern: no multi-line border art")
    assert(composer.sheen ~= nil, "modern: sheen kept")
    assert(composer.paneBg.color[4] ~= 0 or Theme.COLORS.bg_composer[4] == 0, "modern: pane painted with bg_composer")
    assert(composer.border.top.shown == true, "modern: top hairline kept")
  end

  -- test_default_args_are_modern
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 60)
    local composer = Composer.Create(factory, parent, CONTACT, function() end)
    assert(#borderTextures(composer.box) == 0 and composer.sheen ~= nil, "no options -> modern composer")
  end
end
