-- Factory wrappers that mimic live-client template differences:
--   missing(factory, template)        -> CreateFrame raises for `template`
--                                        (flavor without that template)
--   stripped(factory, template, keys) -> frames built from `template` lack the
--                                        listed child keys (live template has
--                                        fewer children than the fake)
--   withText(factory, template, keys)     -> frames built from `template` get
--                                        the listed keys as shown FontStrings
--                                        (live template text the fake lacks)

local TemplateFactory = {}

function TemplateFactory.missing(factory, missingTemplate)
  return {
    CreateFrame = function(frameType, name, parent, template)
      if template == missingTemplate then
        error("CreateFrame(): Couldn't find inherited node \"" .. tostring(template) .. '"')
      end
      return factory.CreateFrame(frameType, name, parent, template)
    end,
  }
end

function TemplateFactory.stripped(factory, strippedTemplate, keys)
  return {
    CreateFrame = function(frameType, name, parent, template)
      local frame = factory.CreateFrame(frameType, name, parent, template)
      if template == strippedTemplate then
        for _, key in ipairs(keys) do
          frame[key] = nil
        end
      end
      return frame
    end,
  }
end

function TemplateFactory.withText(factory, textTemplate, keys)
  return {
    CreateFrame = function(frameType, name, parent, template)
      local frame = factory.CreateFrame(frameType, name, parent, template)
      if template == textTemplate then
        for _, key in ipairs(keys) do
          frame[key] = frame:CreateFontString(nil, "ARTWORK")
          frame[key]:Show()
        end
      end
      return frame
    end,
  }
end

return TemplateFactory
