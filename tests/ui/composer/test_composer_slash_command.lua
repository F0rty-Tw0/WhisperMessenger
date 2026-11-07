local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- Text starting with "/" runs as a game slash command through the default
-- chat box's own Enter handler instead of being whispered to the contact.

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local sent = {}
  local drafts = {}
  local composer = Composer.Create(
    factory,
    parent,
    selectedContact,
    function(payload)
      table.insert(sent, payload)
      return true
    end,
    nil,
    nil,
    nil,
    {
      onDraftChanged = function(conversationKey, text)
        table.insert(drafts, { key = conversationKey, text = text })
      end,
    }
  )
  return composer, sent, drafts
end

-- A default chat edit box whose Enter handler records the text it would run.
local function fakeChatEditBox()
  local editBox = { text = "", ran = {} }
  function editBox:SetText(text)
    self.text = text
  end
  function editBox:GetText()
    return self.text
  end
  function editBox:GetScript(name)
    if name ~= "OnEnterPressed" then
      return nil
    end
    return function(box)
      table.insert(box.ran, box:GetText())
      box:SetText("")
    end
  end
  return editBox
end

local function press(composer, text)
  composer.input:SetText(text)
  composer.input.scripts.OnEnterPressed(composer.input)
end

return function()
  local savedChatFrame = rawget(_G, "DEFAULT_CHAT_FRAME")
  local savedChatInfo = rawget(_G, "C_ChatInfo")
  local savedRestrictedActions = rawget(_G, "C_RestrictedActions")

  local ok, err = pcall(function()
    -- test_slash_text_runs_through_default_chat_box_and_is_not_whispered
    do
      local editBox = fakeChatEditBox()
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      local composer, sent, drafts = build()
      press(composer, "/roll 100")
      assert(#editBox.ran == 1 and editBox.ran[1] == "/roll 100", "runs /roll 100 through the chat box, got " .. tostring(editBox.ran[1]))
      assert(#sent == 0, "a slash command is never whispered")
      assert(composer.input:GetText() == "", "composer cleared after running the command")
      local last = drafts[#drafts]
      assert(last and last.key == "me::WOW::arthas" and last.text == "", "draft cleared after running the command")
    end

    -- test_leading_spaces_before_slash_still_run_the_command
    do
      local editBox = fakeChatEditBox()
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      local composer, sent = build()
      press(composer, "  /dance")
      assert(editBox.ran[1] == "/dance", "trimmed command reaches the chat box, got " .. tostring(editBox.ran[1]))
      assert(#sent == 0, "a slash command is never whispered")
    end

    -- test_slash_inside_message_is_whispered_as_today
    do
      local editBox = fakeChatEditBox()
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      local composer, sent = build()
      press(composer, "hello /roll")
      assert(#sent == 1 and sent[1].text == "hello /roll", "plain message whispered unchanged")
      assert(#editBox.ran == 0, "plain message never reaches the chat box")
    end

    -- test_missing_chat_box_keeps_the_text_and_sends_nothing
    do
      rawset(_G, "DEFAULT_CHAT_FRAME", nil)
      local composer, sent, drafts = build()
      press(composer, "/roll 100")
      assert(#sent == 0, "no chat box -> slash text is still not whispered")
      assert(composer.input:GetText() == "/roll 100", "no chat box -> text stays in the composer")
      assert(#drafts == 0, "no chat box -> draft untouched")
    end

    -- test_chat_box_without_enter_handler_keeps_the_text
    do
      local editBox = fakeChatEditBox()
      editBox.GetScript = function()
        return nil
      end
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      local composer, sent = build()
      press(composer, "/roll 100")
      assert(#sent == 0, "no Enter handler -> slash text is still not whispered")
      assert(composer.input:GetText() == "/roll 100", "no Enter handler -> text stays in the composer")
      assert(editBox.text == "", "no Enter handler -> chat box left untouched")
    end

    -- test_chat_lockdown_keeps_the_text_and_never_touches_the_chat_box
    do
      local editBox = fakeChatEditBox()
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      rawset(_G, "C_ChatInfo", {
        InChatMessagingLockdown = function()
          return true
        end,
      })
      local composer, sent = build()
      press(composer, "/roll 100")
      rawset(_G, "C_ChatInfo", savedChatInfo)
      assert(#editBox.ran == 0 and editBox.text == "", "chat lockdown -> the chat box is never written")
      assert(#sent == 0, "chat lockdown -> slash text is still not whispered")
      assert(composer.input:GetText() == "/roll 100", "chat lockdown -> text stays in the composer")
    end

    -- test_boss_encounter_keeps_the_text_and_never_touches_the_chat_box
    do
      local editBox = fakeChatEditBox()
      rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
      rawset(_G, "C_RestrictedActions", {
        IsAddOnRestrictionActive = function(restrictionType)
          return restrictionType == 1 -- Encounter
        end,
      })
      local composer = build()
      press(composer, "/roll 100")
      rawset(_G, "C_RestrictedActions", savedRestrictedActions)
      assert(#editBox.ran == 0 and editBox.text == "", "encounter -> the chat box is never written")
      assert(composer.input:GetText() == "/roll 100", "encounter -> text stays in the composer")
    end
  end)

  rawset(_G, "C_ChatInfo", savedChatInfo)
  rawset(_G, "C_RestrictedActions", savedRestrictedActions)
  rawset(_G, "DEFAULT_CHAT_FRAME", savedChatFrame)
  assert(ok, err)
end
