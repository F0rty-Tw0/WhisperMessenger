local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Resolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")
local StylingCommon = ns.ChatBubbleContextMenuManualCopyPopupUIStylingCommon
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.StylingCommon")
local ButtonStyling = ns.ChatBubbleContextMenuManualCopyPopupUIButtonStyling
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.ButtonStyling")

local Styling = {}
local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

-- Blizzard's `InputBoxTemplate` ships three border textures (Left / Middle /
-- Right). In some Retail clients they are not returned by `frame:GetRegions()`
-- — the `suppressFrameTextures` pass alone cannot reach them, and the
-- thick default-WoW outline keeps showing through our flat rounded
-- background. We hide them explicitly via `parentKey` and via the named
-- globals, snapshot the originals, and restore on popup close.
local INPUT_TEMPLATE_TEXTURE_KEYS = { "Left", "Middle", "Right" }

local function collectInputTemplateTextures(editBox)
  local found = {}
  for _, key in ipairs(INPUT_TEMPLATE_TEXTURE_KEYS) do
    local viaKey = editBox[key]
    if type(viaKey) == "table" then
      found[#found + 1] = viaKey
    end
    if type(editBox.GetName) == "function" then
      local name = editBox:GetName()
      if type(name) == "string" and name ~= "" then
        local viaGlobal = _G[name .. key]
        if type(viaGlobal) == "table" and viaGlobal ~= viaKey then
          found[#found + 1] = viaGlobal
        end
      end
    end
  end
  return found
end

local function suppressInputTemplateTextures(editBox)
  if type(editBox) ~= "table" then
    return
  end
  if editBox._wmManualCopyTemplateSnapshots ~= nil then
    return
  end
  local snapshots = {}
  for _, tex in ipairs(collectInputTemplateTextures(editBox)) do
    local snap = { region = tex }
    if type(tex.IsShown) == "function" then
      snap.shown = tex:IsShown() == true
    else
      snap.shown = tex.shown == true
    end
    if type(tex.GetAlpha) == "function" then
      snap.alpha = tex:GetAlpha()
    else
      snap.alpha = tex.alpha
    end
    if type(tex.SetAlpha) == "function" then
      tex:SetAlpha(0)
    end
    if type(tex.Hide) == "function" then
      tex:Hide()
    end
    snapshots[#snapshots + 1] = snap
  end
  editBox._wmManualCopyTemplateSnapshots = snapshots
end

local function restoreInputTemplateTextures(editBox)
  if type(editBox) ~= "table" then
    return
  end
  local snapshots = editBox._wmManualCopyTemplateSnapshots
  if type(snapshots) ~= "table" then
    return
  end
  for _, snap in ipairs(snapshots) do
    local tex = snap.region
    if type(tex) == "table" then
      if snap.alpha ~= nil and type(tex.SetAlpha) == "function" then
        tex:SetAlpha(snap.alpha)
      end
      if snap.shown and type(tex.Show) == "function" then
        tex:Show()
      elseif not snap.shown and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end
  end
  editBox._wmManualCopyTemplateSnapshots = nil
end

local function restoreManualCopyEditBox(editBox)
  if type(editBox) ~= "table" then
    return
  end

  StylingCommon.setPartsShown(editBox._wmManualCopyBackground, false)
  StylingCommon.restoreSuppressedFrameTextures(editBox, "_wmManualCopySuppressedRegions")
  restoreInputTemplateTextures(editBox)
  if editBox._wmManualCopyBgLayerDisabled and type(editBox.EnableDrawLayer) == "function" then
    editBox:EnableDrawLayer("BACKGROUND")
    editBox._wmManualCopyBgLayerDisabled = false
  end
  editBox._wmManualCopyStyleActive = false

  local insets = editBox._wmManualCopyOriginalTextInsets
  if editBox._wmManualCopyOriginalTextColor ~= nil then
    StylingCommon.applyTextColor(editBox, editBox._wmManualCopyOriginalTextColor)
  end
  if insets and editBox.SetTextInsets then
    editBox:SetTextInsets(insets[1] or 0, insets[2] or 0, insets[3] or 0, insets[4] or 0)
  end
end

local function styleManualCopyEditBox(editBox)
  if type(editBox) ~= "table" then
    return
  end

  if
    editBox._wmManualCopyBackground == nil
    and type(editBox.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    -- Build at "ARTWORK" so we can DisableDrawLayer("BACKGROUND") to nuke
    -- the InputBoxTemplate's Left / Middle / Right border textures (which
    -- some Retail clients keep rendering even after we Hide() them).
    editBox._wmManualCopyBackground = UIHelpers.createRoundedBackground(editBox, 6, "ARTWORK")
    StylingCommon.setPartsShown(editBox._wmManualCopyBackground, false)
  end

  if editBox._wmManualCopyStyleActive ~= true then
    local skipSet = StylingCommon.collectTextureParts(editBox._wmManualCopyBackground, {})
    StylingCommon.suppressFrameTextures(editBox, "_wmManualCopySuppressedRegions", skipSet)
    suppressInputTemplateTextures(editBox)
    if type(editBox.DisableDrawLayer) == "function" then
      editBox:DisableDrawLayer("BACKGROUND")
      editBox._wmManualCopyBgLayerDisabled = true
    end

    editBox._wmManualCopyOriginalTextColor = StylingCommon.captureTextColor(editBox)
    if type(editBox.GetTextInsets) == "function" then
      local left, right, top, bottom = editBox:GetTextInsets()
      editBox._wmManualCopyOriginalTextInsets = { left, right, top, bottom }
    elseif type(editBox.textInsets) == "table" then
      editBox._wmManualCopyOriginalTextInsets = {
        editBox.textInsets[1],
        editBox.textInsets[2],
        editBox.textInsets[3],
        editBox.textInsets[4],
      }
    else
      editBox._wmManualCopyOriginalTextInsets = nil
    end
  end
  editBox._wmManualCopyStyleActive = true

  if editBox.SetTextColor and Theme.COLORS.text_primary then
    local color = Theme.COLORS.text_primary
    editBox:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
  if editBox._wmManualCopyBackground and editBox._wmManualCopyBackground.setColor and Theme.COLORS.bg_input then
    editBox._wmManualCopyBackground.setColor(Theme.COLORS.bg_input)
    StylingCommon.setPartsShown(editBox._wmManualCopyBackground, true)
  end
  if editBox.SetTextInsets then
    editBox:SetTextInsets(10, 10, 6, 6)
  end
end

function Styling.restoreManualCopyDialog(dialog, dialogName)
  if type(dialog) ~= "table" then
    return
  end
  if dialog._wmManualCopyRestoring == true then
    return
  end
  dialog._wmManualCopyRestoring = true

  StylingCommon.setPartsShown(dialog._wmRoundedBackground, false)
  StylingCommon.setPartsShown(dialog._wmManualCopyBorder, false)
  dialog._wmManualCopyStyleActive = false

  -- Do not restore popup font objects here: touching StaticPopup font objects
  -- caused live-client SetFontObject stack overflows in OnHide cleanup paths.
  local textRegion = dialog.text
  if textRegion then
    if dialog._wmManualCopyOriginalTextColor ~= nil then
      StylingCommon.applyTextColor(textRegion, dialog._wmManualCopyOriginalTextColor)
    end
  end

  local resolvedDialogName = dialogName or MANUAL_COPY_DIALOG_NAME
  restoreManualCopyEditBox(Resolvers.resolvePopupEditBox(dialog, resolvedDialogName))
  ButtonStyling.restoreManualCopyButton(Resolvers.resolvePopupButton(dialog, 1))
  dialog._wmManualCopyRestoring = false
end

function Styling.styleManualCopyDialog(dialog, dialogName)
  if type(dialog) ~= "table" then
    return
  end

  if
    dialog._wmRoundedBackground == nil
    and type(dialog.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    dialog._wmRoundedBackground = UIHelpers.createRoundedBackground(dialog, 10)
    StylingCommon.setPartsShown(dialog._wmRoundedBackground, false)
  end
  if dialog._wmManualCopyBorder == nil and type(UIHelpers.createBorderBox) == "function" then
    dialog._wmManualCopyBorder = UIHelpers.createBorderBox(dialog, Theme.COLORS.divider, 1, "BORDER")
    StylingCommon.setPartsShown(dialog._wmManualCopyBorder, false)
  end

  if dialog._wmRoundedBackground and dialog._wmRoundedBackground.setColor then
    dialog._wmRoundedBackground.setColor(Theme.COLORS.bg_primary)
    StylingCommon.setPartsShown(dialog._wmRoundedBackground, true)
  end
  if dialog._wmManualCopyBorder and Theme.COLORS.divider then
    UIHelpers.applyBorderBoxColor(dialog._wmManualCopyBorder, Theme.COLORS.divider)
    StylingCommon.setPartsShown(dialog._wmManualCopyBorder, true)
  end

  -- Keep popup font objects unchanged; theme the dialog through colors only.
  -- This avoids SetFontObject recursion/crash behavior seen in production.
  local textRegion = dialog.text
  if textRegion and dialog._wmManualCopyStyleActive ~= true then
    dialog._wmManualCopyOriginalTextColor = StylingCommon.captureTextColor(textRegion)
  end
  dialog._wmManualCopyStyleActive = true
  if textRegion then
    StylingCommon.applyTextColor(textRegion, Theme.COLORS.text_primary)
  end

  local resolvedDialogName = dialogName or MANUAL_COPY_DIALOG_NAME
  styleManualCopyEditBox(Resolvers.resolvePopupEditBox(dialog, resolvedDialogName))
  ButtonStyling.styleManualCopyButton(Resolvers.resolvePopupButton(dialog, 1))
end

ns.ChatBubbleContextMenuManualCopyPopupUIStyling = Styling

return Styling
