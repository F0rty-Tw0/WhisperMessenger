local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Util = ns.ComposerChatLinkHookUtil or require("WhisperMessenger.UI.Composer.ChatLinkHookUtil")
local ChatLinkSourcesAddOns = ns.ComposerChatLinkSourcesAddOns or require("WhisperMessenger.UI.Composer.ChatLinkSourcesAddOns")

-- Some Blizzard click handlers only insert a chat link while one of Blizzard's
-- own chat boxes is open (`IsModifiedClick("CHATLINK") and GetActiveWindow()`).
-- Our composer can never be that box: answering GetActiveWindow means
-- replacing it, which taints chat. Post-hooks rebuild the link the handler
-- would have made and pass it to `insert`.
--
-- Accepted side effects. A post-hook cannot change what Blizzard's code does
-- or returns: InsertLink still returns false with no Blizzard chat box open,
-- and gated handlers take their other branch, so next to our insert:
-- - shift-clicking a bag or bank stack also opens the split-stack popup;
-- - an open Auction House search box also gets the item name;
-- - quest log shift-click also toggles watching the quest;
-- - achievement shift-click also toggles tracking it;
-- - glyph shift-right-click also opens the remove-glyph popup;
-- - objective tracker header shift-click also untracks the entry, and the
--   quest item button there also uses the item;
-- - Encounter Journal and quest tracker clicks also do their plain-click
--   action (open the boss, expand the section, open the quest).
-- Only replacing Blizzard's functions could stop these, and that taints.
local ChatLinkSources = {}

ChatLinkSources.IsChatLinkClick = Util.IsChatLinkClick

local function hasQuestLinkApi()
  return _G.QuestLogListScrollFrame ~= nil
    and type(_G.FauxScrollFrame_GetOffset) == "function"
    and type(_G.GetQuestIDFromLogIndex) == "function"
    and type(_G.GetQuestLink) == "function"
end

local function questLinkForLogIndex(questIndex)
  if type(_G.GetQuestIDFromLogIndex) ~= "function" or type(_G.GetQuestLink) ~= "function" then
    return nil
  end
  local questID = _G.GetQuestIDFromLogIndex(questIndex)
  return questID and _G.GetQuestLink(questID)
end

-- Wrath and later insert the quest's link; Vanilla and TBC insert the title.
local function questLogLink(button)
  if hasQuestLinkApi() then
    local link = questLinkForLogIndex(button:GetID() + (_G.FauxScrollFrame_GetOffset(_G.QuestLogListScrollFrame) or 0))
    if type(link) == "string" and link ~= "" then
      return link
    end
  end
  local title = button:GetText()
  if type(title) ~= "string" then
    return nil
  end
  return (string.gsub(title, "^ +", ""))
end

local function hookQuestLog(insert)
  Util.HookGlobal("QuestLogTitleButton_OnClick", function(button)
    if type(button) ~= "table" or button.isHeader or not Util.IsChatLinkClick() then
      return
    end
    insert(questLogLink(button))
  end)
end

-- Wrath quest tracker: quest and achievement lines, and the quest item button.
local function watchLineLink(line)
  if line.type == "QUEST" and type(_G.GetQuestIndexForWatch) == "function" then
    return questLinkForLogIndex(_G.GetQuestIndexForWatch(line.index))
  end
  if line.type == "ACHIEVEMENT" and type(_G.GetAchievementLink) == "function" then
    return _G.GetAchievementLink(line.index)
  end
  return nil
end

local function hookWatchFrame(insert)
  Util.HookGlobal("WatchFrameLinkButtonTemplate_OnClick", function(line)
    if type(line) == "table" and line.index ~= nil and Util.IsChatLinkClick() then
      insert(watchLineLink(line))
    end
  end)
  Util.HookGlobal("WatchFrameItem_OnClick", function(itemButton)
    local getItemInfo = _G.GetQuestLogSpecialItemInfo
    if type(itemButton) ~= "table" or type(itemButton.GetID) ~= "function" or type(getItemInfo) ~= "function" then
      return
    end
    if Util.IsChatLinkClick() then
      insert((getItemInfo(itemButton:GetID())))
    end
  end)
end

-- Battleground scoreboard player names (Vanilla: OnClick, later: OnMouseUp).
local function hookScoreboard(insert)
  local function onClick(row, mouseButton)
    if type(row) ~= "table" or mouseButton ~= "LeftButton" or type(row.text) ~= "table" or not Util.IsChatLinkClick() then
      return
    end
    insert(row.text:GetText())
  end
  Util.HookGlobal("ScorePlayer_OnClick", onClick)
  Util.HookGlobal("ScorePlayer_OnMouseUp", onClick)
end

function ChatLinkSources.Register(insert)
  hookQuestLog(insert)
  hookWatchFrame(insert)
  hookScoreboard(insert)
  ChatLinkSourcesAddOns.Register(insert)
end

ns.ComposerChatLinkSources = ChatLinkSources
return ChatLinkSources
