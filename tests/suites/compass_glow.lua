-- ============================================================================
-- RPQuest Test Suite: CompassAreaGlow
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    local function SetupCompassMocks()
        ZO_Compass:SetHidden(false)
        ZO_Compass:SetDimensions(480, 40)

        local origCreateFromVirtual = WINDOW_MANAGER.CreateControlFromVirtual
        local origApplyTemplate = ApplyTemplateToControl
        local origGamepadFn = IsInGamepadPreferredMode
        local appliedTemplates = {}
        local gamepadMode = false

        IsInGamepadPreferredMode = function()
            return gamepadMode
        end

        ApplyTemplateToControl = function(ctrl, templateName)
            table.insert(appliedTemplates, { ctrl = ctrl, templateName = templateName })
            if origApplyTemplate then
                origApplyTemplate(ctrl, templateName)
            end
        end

        WINDOW_MANAGER.CreateControlFromVirtual = function(self, name, parent, templateName, optionalId)
            local ctrl = origCreateFromVirtual(self, name, parent, templateName, optionalId)
            if templateName == "ZO_CompassAreaTexture" then
                ctrl.left = WINDOW_MANAGER:CreateControl(name .. "Left", ctrl, CT_TEXTURE)
                ctrl.right = WINDOW_MANAGER:CreateControl(name .. "Right", ctrl, CT_TEXTURE)
                ctrl.center = WINDOW_MANAGER:CreateControl(name .. "Center", ctrl, CT_TEXTURE)
                ctrl.GetNamedChild = function(_, childSuffix)
                    if childSuffix == "Left" then return ctrl.left end
                    if childSuffix == "Right" then return ctrl.right end
                    if childSuffix == "Center" then return ctrl.center end
                    return nil
                end
            end
            return ctrl
        end

        local origCreateTimeline = ANIMATION_MANAGER.CreateTimelineFromVirtual
        ANIMATION_MANAGER.CreateTimelineFromVirtual = function(self, templateName, animatedControl)
            local tl = origCreateTimeline(self, templateName, animatedControl)
            tl._handlers = {}
            tl.SetHandler = function(t, eventName, fn)
                t._handlers[eventName] = fn
            end
            local origStop = tl.Stop
            tl.Stop = function(t)
                origStop(t)
                if t._handlers.OnStop then
                    t._handlers.OnStop(t)
                end
            end
            return tl
        end

        -- Reset CompassAreaGlow singleton state for clean test isolation
        RPQuest.CompassAreaGlow.isInitialized = false
        RPQuest.CompassAreaGlow.areaTexture = nil
        RPQuest.CompassAreaGlow._isInside = false
        RPQuest.CompassAreaGlow._isPolling = false

        return {
            appliedTemplates = appliedTemplates,
            setGamepad = function(val) gamepadMode = val end,
            restore = function()
                WINDOW_MANAGER.CreateControlFromVirtual = origCreateFromVirtual
                ApplyTemplateToControl = origApplyTemplate
                IsInGamepadPreferredMode = origGamepadFn
                ANIMATION_MANAGER.CreateTimelineFromVirtual = origCreateTimeline
            end,
        }
    end

    local function RegisterTestQuest(quest)
        quest.id = quest.id or ("test_glow_" .. tostring(math.random(100000, 999999)))
        quest.status = quest.status or RPQuest.Constants.QUEST_STATUS.ACTIVE
        quest.lifecycle = quest.lifecycle or RPQuest.Constants.QUEST_LIFECYCLE.RECEIVED
        quest.resolution = quest.resolution or RPQuest.Constants.QUEST_RESOLUTION.ACCEPTED
        table.insert(RPQuest.QuestRepository.savedVars.quests, quest)
        local ok, err = RPQuest.QuestRepository:SetActiveQuest(quest.id)
        AssertTrue(ok, "SetActiveQuest must succeed: " .. tostring(err))
        return quest
    end

    RunTest("CompassAreaGlow: enter/exit transitions on target search area and exact location regardless of map toggles", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        RPQuest.QuestRepository:Initialize({})
        local env = SetupCompassMocks()

        RegisterTestQuest({
            title = "Glow Test Quest",
            mapId = 45,
            zoneId = 104,
            showSearchAreas = false,
            showLocationAreas = false,
            targets = {
                {
                    name = "Bandit Boss",
                    requiredCount = 1,
                    currentCount = 0,
                    worldX = 50000,
                    worldZ = 50000,
                    zoneId = 104,
                    radius = 1000,
                    areaCenterX = 0.25,
                    areaCenterY = 0.25,
                    areaRadius = 0.04,
                },
            },
        })

        -- Start outside both search area and exact location
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.playerX = 0.80
        mockState.playerY = 0.80
        mockState.worldX = 10000
        mockState.worldZ = 10000

        RPQuest.CompassAreaGlow:Initialize()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "Glow must be hidden when outside target areas")

        -- Enter search area (even with showSearchAreas = false)
        mockState.playerX = 0.26
        mockState.playerY = 0.25
        RPQuest.CompassAreaGlow:EvaluateCurrentPosition()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "Glow must show when inside search area")
        AssertTrue(RPQuest.CompassAreaGlow.areaTexture.animationIn:IsPlaying(), "CompassAreaTextureAnimationIn must play on enter")

        -- Verify distinctive RPQuest gold/amber tint applied
        local r, g, b = RPQuest.CompassAreaGlow.areaTexture.center:GetColor()
        local expectedColor = RPQuest.Constants.UI.COMPASS_AREA_GLOW_COLOR
        AssertEqual(r, expectedColor.r, "Center texture red tint matches RPQuest gold/amber")
        AssertEqual(g, expectedColor.g, "Center texture green tint matches RPQuest gold/amber")
        AssertEqual(b, expectedColor.b, "Center texture blue tint matches RPQuest gold/amber")

        -- Leave search area -> animationOut plays
        mockState.playerX = 0.80
        mockState.playerY = 0.80
        RPQuest.CompassAreaGlow:EvaluateCurrentPosition()
        AssertTrue(RPQuest.CompassAreaGlow.areaTexture.animationOut:IsPlaying(), "CompassAreaTextureAnimationOut must play on exit")
        RPQuest.CompassAreaGlow.areaTexture.animationOut:Stop()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "Glow must be hidden after animationOut completes")

        -- Enter exact target location (even outside search area and with showLocationAreas = false)
        mockState.worldX = 50200
        mockState.worldZ = 50200
        RPQuest.CompassAreaGlow:EvaluateCurrentPosition()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "Glow must show when inside exact target location")

        env.restore()
    end)

    RunTest("CompassAreaGlow: completed targets ignored, quest completion/deactivation hides glow, discoveries excluded", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        RPQuest.QuestRepository:Initialize({})
        local env = SetupCompassMocks()

        -- Standing inside completed target's area must NOT activate glow
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.playerX = 0.20
        mockState.playerY = 0.20
        mockState.worldX = 10000
        mockState.worldZ = 10000

        local q = RegisterTestQuest({
            title = "Multi Target & Discovery Quest",
            mapId = 45,
            zoneId = 104,
            targets = {
                {
                    name = "Completed Target",
                    requiredCount = 1,
                    currentCount = 1,
                    worldX = 10000,
                    worldZ = 10000,
                    zoneId = 104,
                    radius = 2000,
                    areaCenterX = 0.20,
                    areaCenterY = 0.20,
                    areaRadius = 0.05,
                },
                {
                    name = "Pending Target",
                    requiredCount = 1,
                    currentCount = 0,
                    worldX = 50000,
                    worldZ = 50000,
                    zoneId = 104,
                    radius = 1500,
                    areaCenterX = 0.70,
                    areaCenterY = 0.70,
                    areaRadius = 0.04,
                },
            },
            discoveries = {
                {
                    label = "Secret Spot",
                    message = "You found a hidden clue.",
                    worldX = 30000,
                    worldZ = 30000,
                    zoneId = 104,
                    radius = 3000,
                    discovered = false,
                },
            },
        })

        RPQuest.CompassAreaGlow:Initialize()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "Completed target area must not trigger glow")

        -- Standing inside hidden discovery point must NOT activate glow
        mockState.playerX = 0.40
        mockState.playerY = 0.40
        mockState.worldX = 30000
        mockState.worldZ = 30000
        RPQuest.CompassAreaGlow:EvaluateCurrentPosition()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "Hidden discovery point must not trigger glow")

        -- Standing inside pending target's area MUST activate glow
        mockState.playerX = 0.70
        mockState.playerY = 0.70
        RPQuest.CompassAreaGlow:EvaluateCurrentPosition()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "Pending target area must trigger glow")

        -- Deactivating active quest must trigger animationOut and hide glow
        RPQuest.QuestRepository:SetActiveQuest(nil)
        AssertTrue(RPQuest.CompassAreaGlow.areaTexture.animationOut:IsPlaying(), "Deactivating quest must play animationOut")
        RPQuest.CompassAreaGlow.areaTexture.animationOut:Stop()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "Glow must be hidden when no quest is active")

        -- Re-activate and complete target -> glow must hide
        RPQuest.QuestRepository:SetActiveQuest(q.id)
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "Glow restores when quest re-activated inside area")
        q.targets[2].currentCount = 1
        RPQuest.CompassAreaGlow:UpdatePollingState()
        AssertTrue(RPQuest.CompassAreaGlow.areaTexture.animationOut:IsPlaying(), "Completing all targets must play animationOut")

        env.restore()
    end)

    RunTest("CompassAreaGlow: supports dynamic keyboard/gamepad switching and respects ZO_Compass visibility", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        RPQuest.QuestRepository:Initialize({})
        local env = SetupCompassMocks()

        RegisterTestQuest({
            title = "Gamepad & Visibility Quest",
            mapId = 45,
            zoneId = 104,
            targets = {
                {
                    name = "Target",
                    requiredCount = 1,
                    currentCount = 0,
                    areaCenterX = 0.50,
                    areaCenterY = 0.50,
                    areaRadius = 0.05,
                },
            },
        })
        mockState.mapId = 45
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        RPQuest.CompassAreaGlow:Initialize()
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "Glow visible initially")
        AssertEqual(env.appliedTemplates[#env.appliedTemplates].templateName, "ZO_CompassAreaTexture_Keyboard_Template", "Starts in keyboard template")

        -- Switch to Gamepad mode
        env.setGamepad(true)
        RPQuest.CompassAreaGlow:ApplyPlatformStyle()
        AssertEqual(env.appliedTemplates[#env.appliedTemplates].templateName, "ZO_CompassAreaTexture_Gamepad_Template", "Switches to gamepad template")
        AssertTrue(string.find(RPQuest.CompassAreaGlow.areaTexture.center._texture, "Gamepad/gp_", 1, true) ~= nil, "Applies gamepad texture path")

        -- Hide ZO_Compass (e.g. menu/map/boss bar) -> IsGlowVisible respects ZO_Compass visibility
        ZO_Compass:SetHidden(true)
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), false, "IsGlowVisible must be false when ZO_Compass is hidden")

        ZO_Compass:SetHidden(false)
        AssertEqual(RPQuest.CompassAreaGlow:IsGlowVisible(), true, "IsGlowVisible restores when ZO_Compass is visible")

        env.restore()
    end)
end
