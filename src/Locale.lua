-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Locale = {}
local Locale = Addon.Locale

local DEFAULT_LANG = "en"

function Locale:DetectClientLanguage()
    if GetCVar then
        local lang = GetCVar("language.2") or GetCVar("Language.2")
        if type(lang) == "string" and lang ~= "" then
            lang = lang:lower()
            if Addon.Locales and Addon.Locales[lang] then
                return lang
            end
        end
    end
    return DEFAULT_LANG
end

function Locale:Initialize(overrideLang)
    local lang = overrideLang or self:DetectClientLanguage()
    if not (Addon.Locales and Addon.Locales[lang]) then
        lang = DEFAULT_LANG
    end
    self.activeLang = lang

    if not self._stringsRegistered and ZO_CreateStringId then
        ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_RPQUEST", self:Get("SI_KEYBINDINGS_CATEGORY_RPQUEST"))
        ZO_CreateStringId("SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET", self:Get("SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET"))
        ZO_CreateStringId("SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL", self:Get("SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL"))
        self._stringsRegistered = true
    end
end

function Locale:GetLanguage()
    if not self.activeLang then
        self.activeLang = self:DetectClientLanguage()
    end
    return self.activeLang
end

function Locale:Get(key, ...)
    local lang = self:GetLanguage()
    local dict = (Addon.Locales and Addon.Locales[lang]) or {}
    local fallbackDict = (Addon.Locales and Addon.Locales[DEFAULT_LANG]) or {}

    local template = dict[key] or fallbackDict[key] or tostring(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, template, ...)
        if ok then
            return formatted
        end
    end
    return template
end
