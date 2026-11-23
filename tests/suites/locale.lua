-- ============================================================================
-- RPQuest Test Suite: Locale & Localization Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    local OFFICIAL_LOCALES = { "en", "de", "es", "fr", "jp", "ru", "zh" }

    local function ExtractFormatSpecifiers(str)
        local cleaned = str:gsub("%%%%", "")
        local specs = {}
        for spec in cleaned:gmatch("%%[+-#0 ]*%d*%.?%d*[a-zA-Z]") do
            table.insert(specs, spec)
        end
        return table.concat(specs, "|")
    end

    RunTest("Locale automatic detection for all 7 official ESO languages", function()
        local origLang = mockState.language
        for _, lang in ipairs(OFFICIAL_LOCALES) do
            mockState.language = lang
            RPQuest.Locale.activeLang = nil
            RPQuest.Locale:Initialize()
            AssertEqual(RPQuest.Locale:GetLanguage(), lang, "Language should be detected as " .. lang)
            AssertTrue(type(RPQuest.Locale:Get("BTN_NEW_QUEST")) == "string" and RPQuest.Locale:Get("BTN_NEW_QUEST") ~= "", "BTN_NEW_QUEST should be non-empty for " .. lang)
        end
        mockState.language = "es"
        RPQuest.Locale:Initialize()
        AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ Nueva", "Spanish button label")
        AssertEqual(RPQuest.Locale:Get("OBJECTIVE_KILL_FORMAT", "Bandido", 1, 3), "• Eliminar a Bandido: 1 / 3", "Formatted Spanish objective")
        mockState.language = origLang
        RPQuest.Locale:Initialize(origLang)
    end)

    RunTest("Locale fallback to English for unknown client languages and direct formatting", function()
        local origLang = mockState.language
        for _, unknownLang in ipairs({ "pt", "ko", "it", "" }) do
            mockState.language = unknownLang
            RPQuest.Locale.activeLang = nil
            RPQuest.Locale:Initialize()
            AssertEqual(RPQuest.Locale:GetLanguage(), "en", "Unknown language '" .. unknownLang .. "' falls back to 'en'")
            AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ New", "English button label on fallback")
        end
        AssertEqual(RPQuest.Locale:Get("SECTION_ACTIVE_QUESTS", 3), "QUESTS (3)", "Locale:Get formats placeholders directly")
        mockState.language = origLang
        RPQuest.Locale:Initialize(origLang)
    end)

    RunTest("All 7 locales have 100% key parity and matching string.format specifiers", function()
        local baseDict = RPQuest.Locales["en"]
        AssertTrue(type(baseDict) == "table", "Base English locale table must exist")

        for _, lang in ipairs(OFFICIAL_LOCALES) do
            local dict = RPQuest.Locales[lang]
            AssertTrue(type(dict) == "table", "Locale table must exist for " .. lang)

            for key, baseVal in pairs(baseDict) do
                local val = dict[key]
                AssertTrue(type(val) == "string" and val ~= "", string.format("Missing or empty key '%s' in locale '%s'", key, lang))
                local baseSpecs = ExtractFormatSpecifiers(baseVal)
                local langSpecs = ExtractFormatSpecifiers(val)
                AssertEqual(langSpecs, baseSpecs, string.format("Format specifier mismatch for '%s' in locale '%s'", key, lang))
            end

            for key in pairs(dict) do
                AssertTrue(baseDict[key] ~= nil, string.format("Extra key '%s' in locale '%s' not present in 'en'", key, lang))
            end
        end
    end)

end
