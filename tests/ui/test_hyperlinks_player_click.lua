local FakeUI = require("tests.helpers.fake_ui")
local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Shift-clicking a player name in our own window while the composer has focus
-- inserts the plain name. The click must not reach Blizzard's SetItemRef: with
-- none of Blizzard's chat boxes open it would also send a /who for the name.
return function()
  local env = LinkHooksEnv.New()
  local setItemRefCalls = {}
  env.globals.SetItemRef = function(link, _text, _button, _frame)
    table.insert(setItemRefCalls, link)
  end
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)
  local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

  local playerLink = "player:Gæmmer-Kazzak:1:WHISPER"
  local playerText = "|cff3fc7eb|Hplayer:Gæmmer-Kazzak:1:WHISPER|hGæmmer|h|r"

  local function reset(focused, chatLinkClick)
    env.Reset()
    setItemRefCalls = {}
    input.focused = focused
    rawset(_G, "IsModifiedClick", function(action)
      return action == "CHATLINK" and chatLinkClick
    end)
  end

  -- test_shift_clicked_player_name_inserts_name_without_set_item_ref
  do
    reset(true, true)
    local handled = Hyperlinks.HandleClick(playerLink, playerText, "LeftButton", {})
    assert(handled == true, "the click should be handled")
    assert(env.inserts[1] == "Gæmmer-Kazzak", "expected the plain player name, got: " .. tostring(env.inserts[1]))
    assert(#setItemRefCalls == 0, "SetItemRef must not run (it sends /who), ran " .. #setItemRefCalls .. " times")
  end

  -- test_shift_clicked_player_name_with_unfocused_composer_goes_to_set_item_ref
  do
    reset(false, true)
    Hyperlinks.HandleClick(playerLink, playerText, "LeftButton", {})
    assert(#setItemRefCalls == 1, "an unfocused composer leaves the click to Blizzard")
    assert(#env.inserts == 0, "an unfocused composer must not receive the name")
  end

  -- test_plain_player_click_goes_to_set_item_ref
  do
    reset(true, false)
    Hyperlinks.HandleClick(playerLink, playerText, "LeftButton", {})
    assert(#setItemRefCalls == 1, "a plain click opens a whisper through SetItemRef")
  end

  -- test_shift_clicked_item_goes_to_set_item_ref
  do
    reset(true, true)
    Hyperlinks.HandleClick("item:6948", "|Hitem:6948|h[Hearthstone]|h", "LeftButton", {})
    assert(setItemRefCalls[1] == "item:6948", "other links still go through SetItemRef")
  end

  -- The in-game path: our frames' click script, with Blizzard's chat click
  -- handler present (every flavor has it).
  local savedMixin = rawget(_G, "ChatFrameMixin")
  local blizzardCalls = {}
  rawset(_G, "ChatFrameMixin", {
    OnHyperlinkClick = function(self, link, text, button)
      table.insert(blizzardCalls, link)
      _G.SetItemRef(link, text, button, self)
    end,
  })
  local function clickInFrame(link, text)
    blizzardCalls = {}
    local callbacks = 0
    local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    Hyperlinks.EnableOn(frame, function()
      callbacks = callbacks + 1
    end)
    frame:GetScript("OnHyperlinkClick")(frame, link, text, "LeftButton")
    return callbacks
  end

  -- test_shift_clicked_player_name_in_our_frame_goes_only_into_composer
  do
    reset(true, true)
    local callbacks = clickInFrame(playerLink, playerText)
    assert(env.inserts[1] == "Gæmmer-Kazzak" and #env.inserts == 1, "expected the plain player name once, got: " .. tostring(env.inserts[1]))
    assert(#blizzardCalls == 0 and #setItemRefCalls == 0, "Blizzard's handler must not run (it sends /who)")
    assert(callbacks == 1, "the caller's callback should run once, ran " .. callbacks)
  end

  -- test_shift_clicked_player_name_in_our_frame_with_unfocused_composer_goes_to_blizzard
  do
    reset(false, true)
    clickInFrame(playerLink, playerText)
    assert(blizzardCalls[1] == playerLink, "an unfocused composer leaves the click to Blizzard")
    assert(#env.inserts == 0, "an unfocused composer must not receive the name")
  end

  -- test_shift_clicked_battlenet_name_in_our_frame_goes_to_blizzard
  -- (Blizzard ignores it, so no /who and the encoded account name stays out)
  do
    reset(true, true)
    local bnLink = "BNplayer:|Kq12|k:12:3:BN_WHISPER:"
    clickInFrame(bnLink, "|H" .. bnLink .. "|h[|Kq12|k]|h")
    assert(blizzardCalls[1] == bnLink, "a Battle.net name stays with Blizzard")
    assert(#env.inserts == 0, "a Battle.net name must not be inserted, got: " .. tostring(env.inserts[1]))
  end

  rawset(_G, "ChatFrameMixin", savedMixin)
  env.Restore()
end
