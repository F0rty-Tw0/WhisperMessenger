local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local RuntimeBindings = {}

local function buildComposerTextSetter(getWindow)
  return function(text)
    local window = getWindow()
    if window and window.composer and window.composer.input and window.composer.input.SetText then
      window.composer.input:SetText(text or "")
    end
  end
end

function RuntimeBindings.Apply(options)
  options = options or {}

  local runtime = options.runtime or {}
  local controller = options.controller or {}
  local icon = options.icon
  local getWindow = options.getWindow or function()
    return nil
  end
  local getIcon = options.getIcon or function()
    return icon
  end
  local isWindowVisible = options.isWindowVisible or function()
    return false
  end
  local setDiagnostics = options.setDiagnostics or function() end
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local ensureWindow = options.ensureWindow or function() end
  local refreshWindow = options.refreshWindow or function() end
  local selectConversation = options.selectConversation or function() end
  local setWindowVisible = options.setWindowVisible or function() end
  local toggle = options.toggle or function() end

  local setComposerText = buildComposerTextSetter(getWindow)

  controller.getWindow = getWindow
  controller.getIcon = getIcon
  controller.isWindowVisible = isWindowVisible
  controller.setDiagnostics = function(nextDiagnostics)
    setDiagnostics(nextDiagnostics or {})
  end
  controller.buildContacts = buildContacts
  controller.ensureWindow = ensureWindow
  controller.refreshWindow = refreshWindow
  controller.selectConversation = selectConversation
  controller.setWindowVisible = setWindowVisible
  controller.setComposerText = setComposerText
  controller.toggle = toggle

  runtime.isConversationOpen = function(conversationKey)
    return controller.isWindowVisible() and runtime.activeConversationKey == conversationKey
  end

  runtime.icon = icon
  runtime.toggle = controller.toggle
  runtime.refreshWindow = controller.refreshWindow
  runtime.ensureWindow = controller.ensureWindow
  runtime.setWindowVisible = controller.setWindowVisible
  runtime.setComposerText = controller.setComposerText

  return {
    setComposerText = setComposerText,
  }
end

ns.BootstrapWindowRuntimeRuntimeBindings = RuntimeBindings

return RuntimeBindings
