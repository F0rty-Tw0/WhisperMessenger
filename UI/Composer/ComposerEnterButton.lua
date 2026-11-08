local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The button the open-chat key clicks while the composer holds it. In combat
-- the game ignores a key bound to a plain button and opens its own chat box,
-- so the button comes from the secure action template. It has no action type,
-- so its secure click does nothing; the composer's handler hooks that click.
--
-- The template makes the button and its parents protected, so it sits under
-- UIParent: under the window it would lock the window in place in combat.
-- A protected button can't be set up in combat; build it outside one.
--
-- Registered for key down only: the binding clicks on the way down and up,
-- and a second click on release would leak the key into the composer. The
-- game's "cast on key down" setting only decides when the secure action runs,
-- and this button has none.
local ComposerEnterButton = {}

ComposerEnterButton.NAME = "WhisperMessengerComposerEnterButton"

local SECURE_TEMPLATE = "SecureActionButtonTemplate"

-- Every flavor has had the template since 2.0; a client that can't say is
-- assumed to have it.
local function hasSecureTemplate()
  local xmlUtil = _G.C_XMLUtil
  if type(xmlUtil) ~= "table" or type(xmlUtil.GetTemplateInfo) ~= "function" then
    return true
  end
  local ok, info = pcall(xmlUtil.GetTemplateInfo, SECURE_TEMPLATE)
  return ok and info ~= nil
end

-- onPress(button, mouseButton, down) runs on each click of the key.
function ComposerEnterButton.Create(createFrame, onPress)
  local template = hasSecureTemplate() and SECURE_TEMPLATE or nil
  local button = createFrame("Button", ComposerEnterButton.NAME, _G.UIParent, template)
  if not button then
    return nil
  end
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("AnyDown")
  end
  button:HookScript("OnClick", onPress)
  return button
end

ns.ComposerEnterButton = ComposerEnterButton

return ComposerEnterButton
