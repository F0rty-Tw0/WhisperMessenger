local Diagnostics = require("WhisperMessenger.Core.Bootstrap.Diagnostics")

return function()
  local savedRequire = require
  local savedLoadedContactEnricher = package.loaded["WhisperMessenger.Model.ContactEnricher"]
  local traces = {}
  local contactEnricherLoadCount = 0
  local conversationKey = "me::WOW::arthas-area52"

  require = function(name)
    if name == "WhisperMessenger.Model.ContactEnricher" then
      contactEnricherLoadCount = contactEnricherLoadCount + 1
      return {
        EnrichContactsAvailability = function(contacts)
          contacts[1].availability = {
            status = "Online",
            canWhisper = true,
          }
        end,
      }
    end

    return savedRequire(name)
  end
  package.loaded["WhisperMessenger.Model.ContactEnricher"] = nil

  local diagnostics = Diagnostics.Create({
    runtime = {
      store = {
        conversations = {
          [conversationKey] = {
            displayName = "Arthas-Area52",
            channel = "WOW",
            guid = "Player-3676-0ABCDEF0",
            factionName = "Alliance",
          },
        },
      },
      availabilityByGUID = {},
      localFaction = "Alliance",
    },
    trace = function(message)
      traces[#traces + 1] = message
    end,
    presenceCache = {
      GetPresence = function()
        return "guild-presence"
      end,
      IsStale = function()
        return false
      end,
      RefreshPresence = function()
        return "fresh-presence"
      end,
    },
    addonName = "WhisperMessenger",
  })

  assert(contactEnricherLoadCount == 0, "Create should not eagerly load ContactEnricher")

  diagnostics.debugContact(conversationKey)

  assert(contactEnricherLoadCount == 1, "debugContact should lazy-load ContactEnricher when first used")
  assert(#traces > 0, "debugContact should still emit trace output")

  require = savedRequire
  package.loaded["WhisperMessenger.Model.ContactEnricher"] = savedLoadedContactEnricher
end
