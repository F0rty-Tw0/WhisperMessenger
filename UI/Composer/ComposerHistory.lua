local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Up in an empty box recalls sent lines; Up/Down step while the box still
-- shows the recalled line unedited. Any other Up/Down, and any Up/Down with
-- Shift, Ctrl or Alt held, keeps the game's own cursor move between rows.
-- parts.getSentHistory(fits): newest-first lines (nil = no recall).
-- parts.fits(text): the open chat takes the text whole.
-- parts.refresh(): the composer's text-changed steps, run after each put.
local ComposerHistory = {}

local function modifierDown()
  local isModifierKeyDown = _G.IsModifierKeyDown
  return type(isModifierKeyDown) == "function" and isModifierKeyDown() and true or false
end

function ComposerHistory.Create(input, parts)
  local previous = input:GetScript("OnKeyDown")
  local entries, index, shown
  local isPutting = false
  local history = {}

  function history.stop()
    entries, index, shown = nil, 0, nil
  end

  -- In game SetText fires OnTextChanged before shown is read; isPutting
  -- marks that change as the recall's own. A failing put still clears it,
  -- or every later change would pass for the recall's own.
  local function write(text)
    input:SetText(text)
    if input.SetCursorPosition then
      input:SetCursorPosition(#text)
    end
    parts.refresh()
  end

  local function put(text)
    isPutting = true
    local ok, err = pcall(write, text)
    isPutting = false
    if not ok then
      error(err, 0)
    end
    shown = input:GetText() or ""
  end

  local function step(key)
    if key == "UP" then
      if entries[index + 1] ~= nil then
        index = index + 1
        put(entries[index])
      end
    elseif index > 1 then
      index = index - 1
      put(entries[index])
    else
      put("")
      history.stop()
    end
  end

  local function start()
    entries = parts.getSentHistory and parts.getSentHistory(parts.fits) or {}
    if entries[1] == nil then
      history.stop()
      return false
    end
    index = 1
    put(entries[1])
    return true
  end

  local function handled(key)
    local text = input:GetText() or ""
    if entries ~= nil then
      if text == shown then
        step(key)
        return true
      end
      history.stop()
    end
    if key ~= "UP" or text ~= "" then
      return false
    end

    return start()
  end

  input:SetScript("OnKeyDown", function(self, key, ...)
    local isArrow = key == "UP" or key == "DOWN"
    if isArrow and not modifierDown() then
      local tookKey = handled(key)
      if tookKey then
        return
      end
    end
    if previous then
      previous(self, key, ...)
    end
  end)

  function history.textChanged(text)
    if not isPutting and entries ~= nil and text ~= shown then
      history.stop()
    end
  end

  function history.putting()
    return isPutting
  end

  history.stop()
  return history
end

ns.ComposerHistory = ComposerHistory
return ComposerHistory
