local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The phone layout's two screens. The selection decides the screen: a chat
-- selected shows it, none shows the list. So every way of opening a chat
-- (row, preview, slash command) slides there, and on the list no chat counts
-- as open, which keeps new whispers unread.
local PhoneNavigator = {}

local LIST, CHAT = 0, 1

-- options: slide (PhoneSlide), isAnimatable(), onChatView(inChat),
-- getSelectedKey(), clearSelection(), focusChat().
function PhoneNavigator.Create(options)
  local slide = options.slide
  local screen = LIST
  -- The chat being left: it stays selected, so it stays filled, during the
  -- slide; refreshes that report it meanwhile must not turn the slide around.
  local leavingKey = nil

  local function go(nextScreen, done)
    screen = nextScreen
    options.onChatView(nextScreen == CHAT)
    if options.isAnimatable() then
      slide.animateTo(nextScreen, done)
      return
    end
    slide.snapTo(nextScreen)
    if done then
      done()
    end
  end

  local function syncSelection(key)
    if key == nil then
      leavingKey = nil
      if screen ~= LIST then
        go(LIST)
      end
      return
    end
    if key == leavingKey then
      return
    end
    leavingKey = nil
    if screen ~= CHAT then
      go(CHAT, options.focusChat)
    end
  end

  -- True when there was a chat to leave.
  local function back()
    if screen ~= CHAT then
      return false
    end
    leavingKey = options.getSelectedKey()
    go(LIST, function()
      leavingKey = nil
      options.clearSelection()
    end)
    return true
  end

  -- Straight to the list with no slide, for a window about to open.
  local function showList()
    leavingKey = nil
    screen = LIST
    options.onChatView(false)
    slide.snapTo(LIST)
  end

  return {
    syncSelection = syncSelection,
    back = back,
    showList = showList,
    isListView = function()
      return screen == LIST
    end,
  }
end

ns.MessengerWindowPhoneNavigator = PhoneNavigator

return PhoneNavigator
