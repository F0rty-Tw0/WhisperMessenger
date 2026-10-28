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
  local current = nil
  local holder = {}

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
      pulse = preview.pulse == true and ownerPanelShown ~= true,
    }
    entry.onClick = function()
      clearIfCurrent(entry)
      safeCall(preview.onClick)
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
