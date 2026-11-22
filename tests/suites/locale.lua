-- ============================================================================
-- RPQuest Test Suite: Locale & Localization Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    RunTest("Locale automatic detection and Spanish strings", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize()
        AssertEqual(RPQuest.Locale:GetLanguage(), "es", "Language should be es")
        AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ Nueva", "Spanish button label")
        AssertEqual(RPQuest.Locale:Get("OBJECTIVE_KILL_FORMAT", "Bandido", 1, 3), "• Eliminar a Bandido: 1 / 3", "Formatted Spanish objective")
    end)

    RunTest("Locale switch to English and fallback on unsupported language", function()
        mockState.language = "fr"
        RPQuest.Locale:Initialize()
        AssertEqual(RPQuest.Locale:GetLanguage(), "en", "Unsupported language falls back to en")
        AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ New", "English button label")
    end)

    RunTest("36. Locale fallback to English for unsupported client languages and direct formatting", function()
        local origLang = mockState.language
        mockState.language = "de"
        RPQuest.Locale.activeLang = nil
        RPQuest.Locale:Initialize()
        AssertEqual(RPQuest.Locale:GetLanguage(), "en", "Unsupported client language 'de' falls back to 'en'")
        AssertEqual(RPQuest.Locale:Get("SECTION_ACTIVE_QUESTS", 3), "QUESTS (3)", "Locale:Get formats placeholders directly")
        mockState.language = origLang
        RPQuest.Locale:Initialize(origLang)
    end)

end
