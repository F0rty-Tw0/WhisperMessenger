local Skins = require("WhisperMessenger.UI.Theme.Skins")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  -- test_list_skins

  do
    local keys = Skins.ListKeys()
    local found = {}
    for _, key in ipairs(keys) do
      found[key] = true
    end
    assert(found.modern == true, "test_list_skins: missing modern")
    assert(found.blizzard == true, "test_list_skins: missing blizzard")
  end

  -- test_modern_spec

  do
    local spec = Skins.Get("modern")
    assert(type(spec) == "table", "test_modern_spec: should return table")
    assert(spec.window_backdrop == nil, "test_modern_spec: window_backdrop should be nil")
    assert(spec.close_button_atlas == nil, "test_modern_spec: close_button_atlas should be nil")
    assert(spec.pane_header_texture == nil, "test_modern_spec: pane_header_texture should be nil so modern presets keep the flat color header")
  end

  -- test_blizzard_spec

  do
    local spec = Skins.Get("blizzard")
    assert(type(spec) == "table", "test_blizzard_spec: should return table")
    assert(type(spec.window_backdrop) == "table", "test_blizzard_spec: window_backdrop should be table")
    assert(spec.window_backdrop.bgFile == "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "test_blizzard_spec: bgFile mismatch")
    assert(
      spec.window_backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border",
      "test_blizzard_spec: edgeFile reverted to UI-Tooltip-Border (DialogBox-Border at edgeSize 32 covered title text)"
    )
    assert(spec.window_backdrop.tile == true, "test_blizzard_spec: tile should be true")
    assert(spec.window_backdrop.tileSize == 16, "test_blizzard_spec: tileSize")
    assert(spec.window_backdrop.edgeSize == 16, "test_blizzard_spec: edgeSize")
    assert(type(spec.window_backdrop.insets) == "table", "test_blizzard_spec: insets should be table")
    -- Close button intentionally NOT skinned: `common-iconbutton-close`
    -- atlas rendered blank on some clients. ChromeBuilder.applyTheme falls
    -- back to UI-StopButton (the original modern X) which is reliable
    -- across all flavors.
    assert(spec.close_button_atlas == nil, "test_blizzard_spec: close_button_atlas should be nil (atlas rendered blank in-game)")

    -- Send button + scrollbar knob intentionally NOT skinned (see Skins.lua
    -- comment for rationale): the Blizzard textures don't fit our composer
    -- layout / slim scrollbar widths.
    assert(
      spec.send_button_normal_texture == nil,
      "test_blizzard_spec: send_button_normal_texture should be nil (modern pill carries the send button)"
    )
    assert(
      spec.scrollbar_thumb_texture == nil,
      "test_blizzard_spec: scrollbar_thumb_texture should be nil (slim color thumb works better at our slider width)"
    )

    -- Stage 2C: contact row highlight overlay
    assert(
      spec.contact_row_highlight_texture == "Interface\\QuestFrame\\UI-QuestTitleHighlight",
      "test_blizzard_spec: contact_row_highlight_texture mismatch"
    )

    -- Pane inset texture: the same Blizzard bgFile used by the window
    -- backdrop, painted on the contacts pane and conversation area so
    -- they read as native Blizzard panels instead of flat addon surfaces.
    assert(
      spec.pane_inset_texture == "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      "test_blizzard_spec: pane_inset_texture should match window backdrop bgFile"
    )

    -- Conversation-pane header banner: the FriendsFrame header strip reads as
    -- a distinct native banner above the thread under the Azeroth skin.
    assert(
      spec.pane_header_texture == "Interface\\FriendsFrame\\UI-FriendsFrame-FriendHeader",
      "test_blizzard_spec: pane_header_texture should point at FriendsFrame header banner"
    )
  end

  -- test_get_unknown_returns_nil

  do
    local spec = Skins.Get("nonexistent")
    assert(spec == nil, "test_get_unknown_returns_nil: Get should return nil for unknown key")
  end

  -- test_active_skin_follows_preset

  do
    local previous = Theme.GetPreset()

    Theme.SetPreset("wow_default")
    assert(Skins.GetActive() == "modern", "test_active_skin: wow_default should map to modern")

    Theme.SetPreset("elvui_dark")
    assert(Skins.GetActive() == "modern", "test_active_skin: elvui_dark should map to modern")

    Theme.SetPreset("plumber_warm")
    assert(Skins.GetActive() == "modern", "test_active_skin: plumber_warm should map to modern")

    Theme.SetPreset("wow_native")
    assert(Skins.GetActive() == "blizzard", "test_active_skin: wow_native should map to blizzard")

    if previous then
      Theme.SetPreset(previous)
    end
  end

  print("  All skin tests passed")
end
