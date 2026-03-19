local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Composer = {}
local registeredLinkHooks = false
local linkedInputs = {}

local function loadModule(name, key)
  if ns[key] then return ns[key] end
  local ok, loaded = pcall(require, name)
  if ok then return loaded end
  error(key .. " module not available")
end
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

local function canInsertLink(input)
  if input == nil or type(input.Insert) ~= "function" then
    return false
  end

  if type(input.HasFocus) == "function" and not input:HasFocus() then
    return false
  end

  if type(input.IsShown) == "function" and not input:IsShown() then
    return false
  end

  return true
end

local function tryInsertLink(link)
  if link == nil then
    return false
  end

  for _, input in ipairs(linkedInputs) do
    if canInsertLink(input) then
      input:Insert(link)
      return true
    end
  end

  return false
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  _G.hooksecurefunc("HandleModifiedItemClick", function(link)
    tryInsertLink(link)
  end)
  _G.hooksecurefunc("SetItemRef", function(link, text)
    tryInsertLink(text or link)
  end)

  registeredLinkHooks = true
end

function Composer.Create(factory, parent, selectedContact, onSend, onEscape)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  -- Pane background
  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  local bc = Theme.COLORS.bg_composer
  if paneBg.SetColorTexture then
    paneBg:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
  end

  -- Input background texture (sits behind the EditBox)
  local inputBg = pane:CreateTexture(nil, "BACKGROUND")
  local inputW = parentWidth - 80
  local inputH = Theme.LAYOUT.COMPOSER_INPUT_HEIGHT
  local inputX, inputY = 12, 8
  inputBg:SetSize(inputW, inputH)
  inputBg:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  local ic = Theme.COLORS.bg_input
  if inputBg.SetColorTexture then
    inputBg:SetColorTexture(ic[1], ic[2], ic[3], ic[4])
  end

  -- Plain EditBox (no template)
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  input:SetSize(inputW, inputH)
  input:SetText("")

  local fontObj = _G.ChatFontNormal or "ChatFontNormal"
  if input.SetFontObject then
    input:SetFontObject(fontObj)
  end
  if input.SetTextInsets then
    input:SetTextInsets(8, 8, 4, 4)
  end
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end
  if input.SetAltArrowKeyMode then
    input:SetAltArrowKeyMode(false)
  end
  if input.SetHyperlinksEnabled then
    input:SetHyperlinksEnabled(true)
  end

  -- Placeholder text
  local placeholder = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", 8, 0)
  placeholder:SetText("Type a message...")
  local tc = Theme.COLORS.text_secondary
  if placeholder.SetTextColor then
    placeholder:SetTextColor(tc[1], tc[2], tc[3], tc[4])
  end
  placeholder:Show()

  table.insert(linkedInputs, 1, input)
  registerLinkHooks()

  -- Send button (no template, custom styled)
  local btnSize = Theme.LAYOUT.SEND_BUTTON_SIZE
  local sendButton = factory.CreateFrame("Button", nil, pane)
  sendButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -12, 8)
  sendButton:SetSize(btnSize, btnSize)

  -- Send button background texture
  local sendBg = sendButton:CreateTexture(nil, "BACKGROUND")
  sendBg:SetAllPoints(sendButton)
  local sc = Theme.COLORS.send_button
  if sendBg.SetColorTexture then
    sendBg:SetColorTexture(sc[1], sc[2], sc[3], sc[4])
  end
  sendButton.bg = sendBg

  -- Send button label ">"
  local sendLabel = sendButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  sendLabel:SetAllPoints(sendButton)
  sendLabel:SetJustifyH("CENTER")
  sendLabel:SetJustifyV("MIDDLE")
  sendLabel:SetText(">")
  if sendLabel.SetTextColor then
    sendLabel:SetTextColor(1, 1, 1, 1)
  end

  -- Send button hover / disabled state handling
  if sendButton.SetScript then
    sendButton:SetScript("OnEnter", function()
      if sendButton.disabled then return end
      local hc = Theme.COLORS.send_button_hover
      if sendBg.SetColorTexture then
        sendBg:SetColorTexture(hc[1], hc[2], hc[3], hc[4])
      end
    end)
    sendButton:SetScript("OnLeave", function()
      if sendButton.disabled then
        local dc = Theme.COLORS.send_button_disabled
        if sendBg.SetColorTexture then
          sendBg:SetColorTexture(dc[1], dc[2], dc[3], dc[4])
        end
      else
        local nc = Theme.COLORS.send_button
        if sendBg.SetColorTexture then
          sendBg:SetColorTexture(nc[1], nc[2], nc[3], nc[4])
        end
      end
    end)
  end

  sendButton.disabled = selectedContact == nil

  -- Apply initial disabled visual if needed
  if sendButton.disabled then
    local dc = Theme.COLORS.send_button_disabled
    if sendBg.SetColorTexture then
      sendBg:SetColorTexture(dc[1], dc[2], dc[3], dc[4])
    end
  end

  local function submitMessage()
    if sendButton.disabled then
      return
    end

    local text = input.GetText and input:GetText() or input.text
    if text == nil or text == "" then
      return
    end

    onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      displayName = selectedContact.displayName,
      channel = selectedContact.channel,
      bnetAccountID = selectedContact.bnetAccountID,
      guid = selectedContact.guid,
      gameAccountName = selectedContact.gameAccountName,
      text = text,
    })

    input:SetText("")
  end

  sendButton:SetScript("OnClick", submitMessage)

  input:SetScript("OnTextChanged", function()
    local text = input.GetText and input:GetText() or input.text or ""
    if text == "" then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end)

  input:SetScript("OnEnterPressed", function()
    submitMessage()
  end)
  input:SetScript("OnEscapePressed", function()
    if onEscape then
      onEscape()
      return
    end
    if input.ClearFocus then
      input:ClearFocus()
    end
  end)

  return {
    frame = pane,
    input = input,
    sendButton = sendButton,
  }
end

ns.Composer = Composer

return Composer
