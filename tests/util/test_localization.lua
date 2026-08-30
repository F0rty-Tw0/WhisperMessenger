local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  Localization.Configure({
    language = "auto",
    getLocale = function()
      return "enUS"
    end,
  })
  assert(Localization.GetConfiguredLanguage() == "auto", "default configured language should be auto")
  assert(Localization.GetEffectiveLanguage() == "enUS", "enUS locale should resolve English")
  assert(Localization.Text("General Settings") == "General Settings", "English should return the source key")

  Localization.Configure({
    language = "auto",
    getLocale = function()
      return "ruRU"
    end,
  })
  assert(Localization.GetEffectiveLanguage() == "ruRU", "ruRU locale should auto-detect Russian")
  assert(Localization.Text("General Settings") == "Общие настройки", "Russian catalog should translate General Settings")

  Localization.Configure({ language = "enUS" })
  assert(Localization.GetEffectiveLanguage() == "enUS", "explicit enUS should override ruRU auto-detection")
  assert(Localization.Text("General Settings") == "General Settings", "explicit English should return source key")

  Localization.Configure({
    language = "bogus",
    getLocale = function()
      return "ruRU"
    end,
  })
  assert(Localization.GetConfiguredLanguage() == "auto", "invalid language should normalize to auto")
  assert(Localization.GetEffectiveLanguage() == "ruRU", "invalid explicit language should fall back to supported auto-detected locale")

  local currentTranslations = {
    deDE = "Aktuell",
    esES = "Actual",
    esMX = "Actual",
    frFR = "Actuel",
    itIT = "Attuale",
    koKR = "현재",
    ptBR = "Atual",
    ruRU = "Текущая",
    zhCN = "当前",
    zhTW = "目前",
  }

  for language, expected in pairs(currentTranslations) do
    Localization.Configure({ language = language })
    assert(Localization.Text("Current") == expected, language .. " catalog should translate Current")
  end

  local windowScaleTranslations = {
    deDE = "Fensterskalierung",
    esES = "Escala de ventana",
    esMX = "Escala de ventana",
    frFR = "Échelle de la fenêtre",
    itIT = "Scala finestra",
    koKR = "창 크기 비율",
    ptBR = "Escala da janela",
    ruRU = "Масштаб окна",
    zhCN = "窗口缩放",
    zhTW = "視窗縮放",
  }

  for language, expected in pairs(windowScaleTranslations) do
    Localization.Configure({ language = language })
    assert(Localization.Text("Window Scale") == expected, language .. " catalog should translate Window Scale")
  end

  Localization.Configure({ language = "enUS" })
  assert(Localization.Text("Window Scale") == "Window Scale", "English should use Window Scale source key")

  local historicalGroupChatTranslations = {
    deDE = "Historischer Gruppenchat — nur lesbar.",
    esES = "Chat de grupo histórico — solo lectura.",
    esMX = "Chat de grupo histórico — solo lectura.",
    frFR = "Chat de groupe historique — lecture seule.",
    itIT = "Chat di gruppo storico — sola lettura.",
    koKR = "이전 그룹 채팅 — 읽기 전용.",
    ptBR = "Chat de grupo histórico — somente leitura.",
    ruRU = "Исторический групповой чат — только чтение.",
    zhCN = "历史群组聊天 — 只读。",
    zhTW = "歷史群組聊天 — 唯讀。",
  }

  for language, expected in pairs(historicalGroupChatTranslations) do
    Localization.Configure({ language = language })
    assert(Localization.Text("Historical group chat — read-only.") == expected, language .. " catalog should translate historical group chat")
  end
end
