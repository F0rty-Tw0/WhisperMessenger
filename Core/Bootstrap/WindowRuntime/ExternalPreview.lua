local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One slot for a preview another addon puts on the widget. The entry's
-- callbacks are wrapped: a click or dismiss empties the slot (only while the
-- entry is still the current one), and a caller error never escapes.
local ExternalPreview = {}

local function safeCall(fn)
  if type(fn) == "function" then
    pcall(fn)
  end
end

function ExternalPreview.New(options)
  options = options or {}
  local now = options.now or _G.time
  local askWho = options.askWho
  local current = nil
  local runningClick = false
  local holder = {}

  -- The card click is a hardware event, but SendWho is blocked once the
  -- caller's onClick has run (it sends a whisper, opens the window): the
  -- quiet /who for preview.who must be the click's first act.
  local function askWhoFor(name)
    if type(askWho) == "function" and type(name) == "string" and name ~= "" then
      pcall(askWho, name)
    end
  end

  local function clearIfCurrent(entry)
    if current == entry then
      current = nil
    end
  end

  function holder.set(sourceKey, preview, ownerPanelShown)
    local stamp = now()
    local entry = {
      sourceKey = sourceKey,
      stamp = type(stamp) == "number" and stamp or 0,
      sender = preview.sender,
      text = preview.text,
      classTag = preview.classTag,
      detail = preview.detail,
      who = preview.who,
      pulse = preview.pulse == true and ownerPanelShown ~= true,
    }
    entry.onClick = function()
      askWhoFor(entry.who)
      clearIfCurrent(entry)
      -- safeCall is a pcall, so the flag resets even when the caller throws.
      runningClick = true
      safeCall(preview.onClick)
      runningClick = false
    end
    entry.onDismiss = function()
      clearIfCurrent(entry)
      safeCall(preview.onDismiss)
    end
    entry.onShown = function()
      safeCall(preview.onShown)
    end
    current = entry
    return entry
  end

  function holder.get()
    return current
  end

  -- True only while a card's onClick runs: a whisper that code starts asks no
  -- /who, since the game blocks SendWho once another addon's code has run.
  function holder.isRunningClick()
    return runningClick
  end

  function holder.keyOf()
    return current and current.sourceKey or nil
  end

  function holder.clear(sourceKey)
    if current == nil or (sourceKey ~= nil and current.sourceKey ~= sourceKey) then
      return false
    end
    current = nil
    return true
  end

  return holder
end

ns.BootstrapWindowRuntimeExternalPreview = ExternalPreview
return ExternalPreview
