local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Buttons = ns.MessengerWindowChromeBuilderButtons or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")

local MarkAllReadButton = {}

-- True when any contact, on any tab, still has unread messages.
function MarkAllReadButton.HasUnread(contacts)
  for _, contact in ipairs(contacts or {}) do
    if (tonumber(contact.unreadCount) or 0) > 0 then
      return true
    end
  end
  return false
end

-- Creates the "Mark all as read" title-bar button (double-check icon). Size
-- and anchor come from TitleBarLayout; it sits last in the left group so
-- hiding it never shifts another button. Starts hidden; the window shows it
-- (setShown) while anything is unread.
function MarkAllReadButton.Create(factory, frame, theme, onClick)
  local markAllRead = Buttons.CreatePlainIcon(factory, frame, theme, "title_mark_read_icon", "Mark all as read")
  local button = markAllRead.button
  if button.SetScript then
    button:SetScript("OnClick", function()
      if onClick then
        onClick()
      end
    end)
  end
  button:Hide()

  return {
    button = button,
    setShown = function(shown)
      button:SetShown(shown == true)
    end,
    applyTheme = markAllRead.applyTheme,
  }
end

ns.MessengerWindowChromeBuilderMarkAllReadButton = MarkAllReadButton

return MarkAllReadButton
