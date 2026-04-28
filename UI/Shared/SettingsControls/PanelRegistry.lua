local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Panel registry --------------------------------------------------------------
--
-- Owns the lifecycle wiring shared by every settings panel:
--   * reset         — on the panel's "Reset to Defaults" button
--   * refreshTheme  — when the active theme/preset changes
--   * refreshLayout — when the panel width changes
--
-- A panel binds each control once with its widget type, config key, and
-- default value; the registry then iterates them. Adding a new control no
-- longer requires touching three or four sibling code paths — it just gets
-- picked up by every iterator that already exists.
--
-- Bind options:
--   type        — "toggle" | "slider" | "selector" | "optionButton" | "custom"
--   key         — config key passed to onChange on reset (omit for non-resetting)
--   default     — default value used by reset (omit for non-resetting)
--   reset       — function(control, onChange) override for non-standard resets
--                 (e.g. profanity filter writes a CVar instead of onChange)

local PanelRegistry = {}

local function defaultReset(item, onChange)
  if item.key == nil or item.default == nil then
    return
  end
  local control = item.control
  if item.type == "slider" then
    -- Slider:SetValue triggers OnValueChanged, which in turn invokes the
    -- per-row onChange callback registered in CreateSliderRow. Calling
    -- onChange manually here would double-fire it.
    if control.slider and control.slider.SetValue then
      control.slider:SetValue(item.default)
    end
    return
  end
  if item.type == "toggle" then
    control.setValue(item.default)
  elseif item.type == "selector" then
    control.setSelected(item.default)
  end
  if onChange then
    onChange(item.key, item.default)
  end
end

-- New(builders) — builders is { toggleColors, selectorColors, optionButtonColors }
-- each a function(activeTheme) returning the color table for that widget type.
-- Passed in instead of imported to keep this module free of circular deps.
function PanelRegistry.New(builders)
  builders = builders or {}
  local registry = { items = {} }

  function registry:bind(control, opts)
    opts = opts or {}
    self.items[#self.items + 1] = {
      control = control,
      type = opts.type or "custom",
      key = opts.key,
      default = opts.default,
      reset = opts.reset,
    }
    return control
  end

  function registry:reset(onChange)
    for _, item in ipairs(self.items) do
      if item.reset then
        item.reset(item.control, onChange)
      else
        defaultReset(item, onChange)
      end
    end
  end

  function registry:refreshTheme(activeTheme)
    local toggleColors = builders.toggleColors and builders.toggleColors(activeTheme) or nil
    local selectorColors = builders.selectorColors and builders.selectorColors(activeTheme) or nil
    local optionButtonColors = builders.optionButtonColors and builders.optionButtonColors(activeTheme) or nil
    for _, item in ipairs(self.items) do
      local control = item.control
      if item.type == "toggle" then
        if control.applyThemeColors and toggleColors then
          control.applyThemeColors(toggleColors)
        end
      elseif item.type == "slider" then
        if control.applyTheme then
          control.applyTheme(activeTheme)
        end
      elseif item.type == "selector" then
        if control.applyTheme and selectorColors then
          control.applyTheme(activeTheme, selectorColors)
        end
      elseif item.type == "optionButton" then
        if control.applyThemeColors and optionButtonColors then
          control.applyThemeColors(optionButtonColors)
        end
      end
    end
  end

  function registry:refreshLayout(width)
    for _, item in ipairs(self.items) do
      local control = item.control
      if type(control.setWidth) == "function" then
        control.setWidth(width)
      end
    end
  end

  return registry
end

ns.SettingsControlsPanelRegistry = PanelRegistry
return PanelRegistry
