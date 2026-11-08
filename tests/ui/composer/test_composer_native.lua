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

local function assertFileBorder(input, label)
  assert(#borderTextures(input) == 3, label .. ": 3 file-art pieces, got " .. #borderTextures(input))
  assert(next(atlasPieces(input)) == nil, label .. ": no atlas pieces")
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

  -- test_hud_composer_draws_blizzard_input_border_on_existing_edit_box
  do
    local composer = create(true)
    assert(composer.input.template == nil, "HUD: composer keeps its own EditBox (art applied, not re-templated)")
    assert(#borderTextures(composer.input) == 3, "HUD: left/middle/right input border art, got " .. #borderTextures(composer.input))
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

  -- test_retail_hud_composer_uses_search_border_atlases
  RetailHud.With(function()
    RetailHud.WithAtlas(true, function()
      local composer = create(true)
      local atlases = atlasPieces(composer.input)
      assert(next(atlases) ~= nil, "retail HUD: composer draws atlas pieces")
      for _, name in pairs(ComposerSurface.NATIVE_SEARCH_ATLAS) do
        assert(atlases[name], "retail HUD: composer draws atlas " .. name)
      end
      assert(#borderTextures(composer.input) == 0, "retail HUD: no file-art pieces mixed in")
    end)
  end)

  -- test_retail_hud_without_atlas_keeps_file_border
  RetailHud.With(function()
    RetailHud.WithAtlas(false, function()
      assertFileBorder(create(true).input, "retail HUD, atlas unknown")
    end)
  end)

  -- test_retail_hud_without_set_atlas_keeps_file_border
  RetailHud.With(function()
    RetailHud.WithAtlas(true, function()
      local factory = RetailHud.Factory(FakeUI, {
        decorate = function(frame, _)
          if frame.frameType == "EditBox" then
            RetailHud.WithoutAtlas(frame)
          end
        end,
      })
      assertFileBorder(create(true, nil, factory).input, "retail HUD, no SetAtlas")
    end)
  end)

  -- test_classic_hud_ignores_atlases
  Hud.Configure("classic")
  RetailHud.WithAtlas(true, function()
    assertFileBorder(create(true).input, "classic HUD")
  end)
  Hud.Configure("off")

  -- test_modern_composer_unchanged
  do
    local composer = create(false)
    assert(#borderTextures(composer.input) == 0, "modern: no Blizzard border art")
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
    assert(#borderTextures(composer.input) == 0 and composer.sheen ~= nil, "no options -> modern composer")
  end
end
