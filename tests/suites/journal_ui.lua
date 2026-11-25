-- ============================================================================
-- RPQuest Test Suite: JournalTab UI & Lifecycle Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState
    local mockPinManager = T.mockPinManager

    RunTest("RPQuest Initialize via EVENT_ADD_ON_LOADED sets up Account-Wide SavedVars and JournalTab", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize()
        EVENT_MANAGER:FireEvent(EVENT_ADD_ON_LOADED, "RPQuest")

        AssertTrue(RPQuest.savedVars ~= nil, "Account-Wide SavedVars initialized")
        AssertTrue(RPQuest.JournalTab.isInitialized, "JournalTab initialized")
        AssertTrue(RPQuest.JournalTab.isTabAdded, "Custom Quests tab registered in QUEST_JOURNAL_KEYBOARD.tabs")

        -- Crear una misión desde la UI del Editor en la pestaña del Diario
        RPQuest.JournalTab:OpenTab()
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.editorPane:IsHidden(), false, "Editor pane is visible")

        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleName = "Señor Vampiro"
        mockState.mapId = 60
        mockState.zoneId = 200
        mockState.mapName = "Rivenspire"
        mockState.playerX = 0.25
        mockState.playerY = 0.75

        RPQuest:OnCaptureTargetKeybind()
        RPQuest.JournalTab.titleEdit:SetText("Cacería Nocturna")
        RPQuest.JournalTab.descEdit:SetText("Derrota al vampiro en las ruinas.")
        AssertEqual(RPQuest.JournalTab.countEdit, nil, "Manual countEdit must not exist in JournalTab")
        AssertEqual(RPQuest.JournalTab.btnSaveEditor:GetText(), "Guardar Borrador", "Spanish button label is Guardar Borrador")
        RPQuest.JournalTab.titleEdit:FireHandler("OnMouseDown")
        AssertTrue(RPQuest.JournalTab.titleEdit._focused, "Clicking titleEdit focuses it for keyboard input")
        RPQuest.JournalTab.descEdit:FireHandler("OnMouseDown")
        AssertTrue(RPQuest.JournalTab.descEdit._focused, "Clicking descEdit focuses it for keyboard input")
        RPQuest.JournalTab:OnSaveDraftClicked()

        local savedList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#savedList, 1, "Prepared quest saved from JournalTab")
        local preparedQuest = savedList[1]
        AssertEqual(preparedQuest.title, "Cacería Nocturna", "Saved title matches")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Prepared quest is not auto-activated on save")

        -- Probar la misión manualmente desde En Preparación
        RPQuest.JournalTab:OnToggleActiveClicked()
        local active = RPQuest.QuestRepository:GetActiveQuest()
        AssertTrue(active ~= nil and active.id == preparedQuest.id, "Prepared quest activated for local testing via JournalTab")

        -- ShareCodec sigue funcionando como capa interna de serialización para MailTransport
        local generatedCode = RPQuest.QuestRepository:ExportQuestToCode(preparedQuest.id)
        AssertTrue(string.sub(generatedCode, 1, 5) == "RPQ3:", "Internal ExportQuestToCode produces RPQ3 code")
        AssertEqual(RPQuest.JournalTab.importPane, nil, "Manual importPane removed")
        AssertEqual(RPQuest.JournalTab.shareEdit, nil, "Manual shareEdit removed")
        AssertEqual(RPQuest.JournalTab.mailInboxPane, nil, "Manual mailInboxPane removed")

        -- Verificar que ImportQuestFromCode + AcceptOfferedQuest emite banner CSA
        mockState.csaMessages = {}
        local offeredQ = RPQuest.QuestRepository:ImportQuestFromCode(generatedCode, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "test_import_901",
        })
        RPQuest.QuestRepository:AcceptOfferedQuest(offeredQ.id)
        RPQuest.Announcements:AnnounceQuestAccepted(offeredQ)
        AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 2, "Second quest imported via internal repository flow")
        AssertEqual(#mockState.csaMessages, 1, "Accepting quest emits one CENTER_SCREEN_ANNOUNCE banner")
        AssertEqual(mockState.csaMessages[1].category, CSA_CATEGORY_LARGE_TEXT, "Quest accepted CSA uses large text category")
        AssertEqual(mockState.csaMessages[1].sound, SOUNDS.QUEST_ACCEPTED, "Quest accepted CSA plays SOUNDS.QUEST_ACCEPTED")
        AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED, "Quest accepted CSA uses CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED")

        -- Verificar que salir de Edit mode seleccionando otra misión limpia editingQuestId
        RPQuest.JournalTab:OpenEditEditor(active.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, active.id, "Draft has editingQuestId while in Edit mode")
        RPQuest.JournalTab:SelectQuest(active.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "Selecting a quest in list clears orphaned editingQuestId")
    end)

    RunTest("Reticle inference: repeated same NPC (Imp x3) and multiple named NPCs + Save Draft button", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        AssertEqual(RPQuest.Locale:Get("BTN_SAVE"), "Save Draft", "English save button label is Save Draft")

        RPQuest.QuestRepository:Initialize({})
        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- Caso A: Apuntar a un Imp 3 veces -> objetivo inferido: Imp x3
        mockState.reticleName = "Imp"
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.TargetCapture:CaptureFromReticle()
        local draftImp = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftImp.targets, 1, "Same NPC merges into 1 target entry")
        AssertEqual(draftImp.targets[1].requiredCount, 3, "Imp captured 3 times requires 3 kills")
        AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftImp.targets), "Imp x3", "Formatted summary is Imp x3")

        local impQuest = RPQuest.QuestRepository:SaveDraft("Imp Hunt", "Clear the imps.")
        AssertEqual(impQuest.targets[1].requiredCount, 3, "Saved quest inferred requiredCount = 3 from reticle")

        -- Caso B: Apuntar a dos NPCs con nombre distinto -> ambos son objetivos exclusivos
        mockState.reticleName = "Lord Vane"
        RPQuest.TargetCapture:CaptureFromReticle()
        mockState.reticleName = "Lady Vane"
        local draftDuo = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftDuo.targets, 2, "Two distinct named NPCs create 2 target entries")
        AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftDuo.targets), "Lord Vane, Lady Vane", "Summary lists both named NPCs")

        local duoQuest = RPQuest.QuestRepository:SaveDraft("Twin Assassination", "Eliminate both targets.")
        AssertEqual(#duoQuest.targets, 2, "Saved quest has 2 distinct targets")
        RPQuest.QuestRepository:SetActiveQuest(duoQuest.id)

        -- Matar a Lord Vane 2 veces no debe completar a Lady Vane
        local r1, _, c1 = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertTrue(r1 and not c1, "Killing Lord Vane advances progress but does not complete quest")
        local rDup = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertEqual(rDup, false, "Killing already completed named target again is ignored")

        -- Matar a Lady Vane completa la misión
        local r2, _, c2 = RPQuest.QuestRepository:RecordTargetEliminated("Lady Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertTrue(r2 and c2, "Killing second named target completes the quest")

        -- Exportar e importar misión multi-objetivo conserva todos los objetivos
        local code = RPQuest.QuestRepository:ExportQuestToCode(duoQuest.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertEqual(#imported.targets, 2, "Imported multi-target quest preserves both targets")
        AssertEqual(imported.targets[1].name, "Lord Vane", "First imported target matches")
        AssertEqual(imported.targets[2].name, "Lady Vane", "Second imported target matches")

        -- Caso C: Capturar objetivos en mapas distintos reinicia la lista al nuevo mapa
        RPQuest.QuestRepository:ResetDraft()
        mockState.mapId = 32
        mockState.playerX = 0.20
        mockState.playerY = 0.20
        mockState.reticleName = "Guardia de Auridon"
        RPQuest.TargetCapture:CaptureFromReticle()

        mockState.mapId = 45
        mockState.playerX = 0.80
        mockState.playerY = 0.80
        mockState.reticleName = "Guardia de Deshaan"
        local draftMapSwitch = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftMapSwitch.targets, 1, "Capturing target in a new map resets targets from previous map")
        AssertEqual(draftMapSwitch.targets[1].name, "Guardia de Deshaan", "Only the new map target remains")
        AssertEqual(draftMapSwitch.targetX, 0.80, "Centroid X is strictly from the new map")
        AssertEqual(draftMapSwitch.targetY, 0.80, "Centroid Y is strictly from the new map")

        -- Caso D: ClearDraftTargets limpia también metadatos del mapa
        RPQuest.QuestRepository:ClearDraftTargets()
        AssertEqual(draftMapSwitch.mapId, 0, "ClearDraftTargets resets mapId to 0")
        AssertEqual(draftMapSwitch.zoneId, 0, "ClearDraftTargets resets zoneId to 0")
        AssertEqual(draftMapSwitch.mapName, "", "ClearDraftTargets resets mapName to empty")
    end)

    RunTest("Bugfixes: DeleteQuest resets dangling draft and JournalTab scrolls >14 rows", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()

        -- 1. DeleteQuest limpia editingQuestId si esa misión estaba en edición
        mockState.reticleExists = true
        mockState.reticleName = "Bandido"
        RPQuest.TargetCapture:CaptureFromReticle()
        local q1 = RPQuest.QuestRepository:SaveDraft("Misión Uno", "Desc", 0.05)
        RPQuest.JournalTab:OpenEditEditor(q1.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, q1.id, "Draft editing q1")
        RPQuest.QuestRepository:DeleteQuest(q1.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "DeleteQuest clears dangling editingQuestId")

        -- 2. JournalTab pagina/desplaza más allá de 14 filas
        for i = 1, 16 do
            RPQuest.TargetCapture:CaptureFromReticle()
            RPQuest.QuestRepository:SaveDraft("Quest #" .. tostring(i), "", 0.05)
        end
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnListNext:IsHidden(), false, "Scroll Next button shown when > 14 rows")
        AssertEqual(RPQuest.JournalTab.listOffset, 0, "Initial listOffset is 0")
        RPQuest.JournalTab:ScrollQuestList(2)
        AssertEqual(RPQuest.JournalTab.listOffset, 2, "ScrollQuestList advances offset")
        AssertEqual(RPQuest.JournalTab.rowBindings[1].questId, 3, "First visible row reflects scrolled offset")
    end)

    RunTest("12. Higiene UI: anclaje dinámico de botones, título único tras borrado y ciclo _dirty", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        mockState.reticleExists = true
        mockState.reticleName = "Bandido"

        -- 1. Título por defecto usa nextId y no colisiona tras borrar
        RPQuest.TargetCapture:CaptureFromReticle()
        local qa = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        RPQuest.TargetCapture:CaptureFromReticle()
        local qb = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        RPQuest.QuestRepository:DeleteQuest(qa.id)
        RPQuest.TargetCapture:CaptureFromReticle()
        local qc = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        AssertTrue(qb.title ~= qc.title, "Default title uses nextId and does not collide after deletion")

        -- 2. Detalle de misión preparada muestra botón de envío directo sin cajas de código manual
        RPQuest.JournalTab:SelectQuest(qc.id)
        AssertEqual(RPQuest.JournalTab.codeDivider, nil, "Manual codeDivider removed")
        AssertEqual(RPQuest.JournalTab.shareBg, nil, "Manual shareBg removed")
        AssertEqual(RPQuest.JournalTab.validateBg, nil, "Manual validateBg removed")
        AssertEqual(RPQuest.JournalTab.btnSendDirect:IsHidden(), false, "Direct mail send button visible for prepared quest")

        -- 3. _dirty se marca cuando panel está oculto y se limpia al abrir
        RPQuest.JournalTab.panel:SetHidden(true)
        RPQuest.QuestRepository:SetActiveQuest(qb.id)
        AssertEqual(RPQuest.JournalTab._dirty, true, "_dirty set while panel is hidden")
        RPQuest.JournalTab:OpenTab()
        AssertEqual(RPQuest.JournalTab._dirty, false, "_dirty cleared after OpenTab")
    end)

    RunTest("14. Mensaje de finalizacion editable y refresco de pin al editar radio y abrir mapa", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        RPQuest.WorldMapArea:Initialize()

        mockState.reticleExists = true
        mockState.reticleName = "Oveja"
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- 1. Crear misión con mensaje de finalización personalizado desde JournalTab
        RPQuest.JournalTab:OpenCreateEditor()
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.JournalTab.titleEdit:SetText("Gran Cacería")
        RPQuest.JournalTab.descEdit:SetText("Caza en el valle.")
        RPQuest.JournalTab.completionEdit:SetText("¡Has limpiado el valle!")
        RPQuest.JournalTab:OnSaveDraftClicked()

        local q = RPQuest.QuestRepository:GetAllQuests()[1]
        AssertEqual(q.completionMessage, "¡Has limpiado el valle!", "completionMessage saved from JournalTab")

        -- 2. ShareCodec preserva completionMessage
        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        local decoded = RPQuest.ShareCodec:DecodeQuest(code)
        AssertEqual(decoded.completionMessage, "¡Has limpiado el valle!", "ShareCodec preserves completionMessage")

        -- 3. AnnounceQuestCompleted usa completionMessage en lugar de un único objetivo
        local capturedSubText = nil
        local origCSA = CENTER_SCREEN_ANNOUNCE
        CENTER_SCREEN_ANNOUNCE = {
            CreateMessageParams = function()
                return {
                    SetText = function(_, _, sub) capturedSubText = sub end,
                    SetCSAType = function() end,
                }
            end,
            AddMessageWithParams = function() end,
        }
        RPQuest.Announcements:AnnounceQuestCompleted(q)
        AssertEqual(capturedSubText, "¡Has limpiado el valle!", "AnnounceQuestCompleted uses custom completionMessage")

        -- Sin mensaje personalizado -> subText es nil (no muestra un único objetivo parcial)
        RPQuest.Announcements:AnnounceQuestCompleted({ title = "Sin Msg", completionMessage = "", targets = { { name = "Tirusa", currentCount = 1, requiredCount = 1 } } })
        AssertEqual(capturedSubText, nil, "AnnounceQuestCompleted omits subText when completionMessage is empty")
        CENTER_SCREEN_ANNOUNCE = origCSA

        -- 4. Editar radio de área, desactivar/reactivar y mostrar escena del mapa refresca el pin con el nuevo radio
        RPQuest.JournalTab:OpenEditEditor(q.id)
        RPQuest.QuestRepository:UpdateDraftFields({ areaRadius = RPQuest.Constants.AREA_RADIUS.LARGE, recommendHideMapAreas = false })
        RPQuest.JournalTab:OnSaveDraftClicked()
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.QuestRepository:SetActiveQuest(q.id)

        -- Simular apertura del mapa mundial via WORLD_MAP_SCENE
        SCENE_MANAGER:Show("worldMap")
        AssertEqual(#mockPinManager._createdPins, 1, "WorldMapArea pin rendered after edit + reactivate + map open")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "WorldMapArea pin uses updated LARGE radius")
    end)

    RunTest("16. Marca del mapa visible en preparacion y actualizada al instante al editar tamano", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        RPQuest.WorldMapArea:Initialize()

        local mockPinManager = ZO_WorldMap_GetPinManager()
        mockPinManager._createdPins = {}

        mockState.reticleExists = true
        mockState.reticleName = "Nigromante"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- 1. En creación (sin guardar), capturar objetivo muestra el pin en el mapa y habilita [M] Show On Map en el editor
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.btnShowMapEditor == nil, true, "Standalone ShowMapEditor button removed")
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map keybind hidden before target capture")
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map keybind visible after target capture")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin rendered immediately during draft preparation")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Draft pin starts with MEDIUM radius")

        -- 2. Cambiar radio en el editor antes de guardar actualiza el pin al instante
        RPQuest.JournalTab.areaSizeComboBox:SelectItemByIndex(4)
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed on radius change")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "Draft pin immediately reflects LARGE radius")

        -- Guardar la misión preparada
        RPQuest.JournalTab.titleEdit:SetText("Ritual en Deshaan")
        RPQuest.JournalTab:OnSaveDraftClicked()
        local q = RPQuest.QuestRepository:GetAllQuests()[1]
        AssertEqual(q.targets[1].areaRadius, RPQuest.Constants.AREA_RADIUS.LARGE, "Saved quest target keeps LARGE radius")

        -- 3. Abrir Editar y cambiar radio a SMALL refleja el nuevo tamaño en el mapa al instante (sin guardar todavía)
        RPQuest.JournalTab:OpenEditEditor(q.id)
        RPQuest.JournalTab.areaSizeComboBox:SelectItemByIndex(2)
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed when editing quest radius")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "Edited draft pin immediately reflects SMALL radius")

        -- 4. Pulsar [M] Show On Map desde el editor abre el mapa mostrando el pin editado
        RPQuest.JournalTab.showOnMapDescriptor.callback()
        AssertEqual(#mockPinManager._createdPins, 1, "ShowQuestOnMap from editor renders pin")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "ShowQuestOnMap from editor uses current edited SMALL radius")
    end)

    RunTest("City/subzone map detection enlarges effective search area radius on Show on Map", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        RPQuest.WorldMapArea:Initialize()

        local mockPinManager = ZO_WorldMap_GetPinManager()
        mockPinManager._createdPins = {}

        mockState.reticleExists = true
        mockState.reticleName = "Guardia de la Ciudad"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 200
        mockState.zoneId = 381
        mockState.mapName = "Vulkhel Guard"
        mockState.mapType = MAPTYPE_SUBZONE
        mockState.playerX = 0.45
        mockState.playerY = 0.55

        RPQuest.JournalTab:OpenCreateEditor()
        local draft = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(draft.mapType, MAPTYPE_SUBZONE, "Captured draft stores MAPTYPE_SUBZONE")
        AssertEqual(draft.areaRadius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Draft keeps base MEDIUM selection for editor UI")

        local expectedSubzoneRadius = RPQuest.Constants.AREA_RADIUS.MEDIUM * RPQuest.Constants.AREA_SUBZONE_MULTIPLIER
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin rendered on subzone map")
        AssertTrue(math.abs(mockPinManager._createdPins[1].radius - expectedSubzoneRadius) < 0.0001, "Subzone pin uses enlarged effective radius")

        local dx = draft.targetX - draft.areaCenterX
        local dy = draft.targetY - draft.areaCenterY
        local dist = math.sqrt((dx * dx) + (dy * dy))
        AssertTrue(dist < expectedSubzoneRadius, "Target remains inside enlarged subzone search circle")

        -- Restaurar mapType a MAPTYPE_ZONE para evitar fuga de estado en tests siguientes
        mockState.mapType = MAPTYPE_ZONE
    end)

    RunTest("Editor Accordion Sections: default state, toggle layout, and auto-expand on edit", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenTab()
        RPQuest.JournalTab:OpenCreateEditor()

        local sections = RPQuest.JournalTab.editorSectionsByKey
        AssertTrue(sections ~= nil, "editorSectionsByKey initialized")
        AssertTrue(sections.header ~= nil, "Header section initialized")
        AssertEqual(sections.header.body:IsHidden(), false, "Header section starts expanded by default")
        AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed")
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed")
        AssertEqual(sections.dialogue.body:IsHidden(), true, "Dialogue section starts collapsed")
        AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed")

        local yTargetWhenHeaderExpanded = sections.target.divider._anchors[1].y
        RPQuest.JournalTab:ToggleEditorSection("header")
        AssertEqual(sections.header.isOpen, false, "Header section marks closed on toggle")
        AssertEqual(sections.header.timeline:IsPlaying(), true, "Header collapse timeline starts playing")
        sections.header.timeline:StepTo(0.5)
        AssertEqual(sections.header.openPercentage, 0.25, "Header uses ZO_EaseInQuadratic at 0.5 -> 0.25")
        AssertEqual(sections.header.body:GetAlpha(), 0.5, "Header body alpha interpolates to 0.5")
        local yTargetMidCollapse = sections.target.divider._anchors[1].y
        AssertTrue(yTargetMidCollapse < yTargetWhenHeaderExpanded, "Subsequent section Y offset decreases mid-collapse")
        sections.header.timeline:StepTo(0)
        AssertEqual(sections.header.timeline:IsPlaying(), false, "Header collapse timeline stops at 0")
        AssertEqual(sections.header.body:IsHidden(), true, "Header section hides at end of collapse")
        local yTargetWhenHeaderCollapsed = sections.target.divider._anchors[1].y
        AssertTrue(yTargetWhenHeaderCollapsed < yTargetMidCollapse, "Subsequent section Y offset decreases further when header accordion finishes collapsing")

        RPQuest.JournalTab:ToggleEditorSection("header")
        AssertEqual(sections.header.isOpen, true, "Header section marks open on second toggle")
        AssertEqual(sections.header.timeline:IsPlaying(), true, "Header expand timeline starts playing")
        sections.header.timeline:StepTo(0.5)
        AssertEqual(sections.header.openPercentage, 0.75, "Header uses ZO_EaseOutQuadratic at 0.5 -> 0.75")
        sections.header.timeline:StepTo(1)
        AssertEqual(sections.header.body:IsHidden(), false, "Header section visible after expand")
        AssertEqual(sections.target.divider._anchors[1].y, yTargetWhenHeaderExpanded, "Subsequent section Y offset restores when header accordion expands")

        -- Single-open (exclusive): opening discovery automatically collapses header
        local yDialogueBefore = sections.dialogue.divider._anchors[1].y
        RPQuest.JournalTab:ToggleEditorSection("discovery")
        AssertEqual(sections.header.isOpen, false, "Opening discovery collapses currently open header")
        AssertEqual(RPQuest.JournalTab.editorSectionsCollapsed.header, true, "Header marked collapsed in editorSectionsCollapsed")
        AssertEqual(sections.discovery.isOpen, true, "Discovery section opens")
        AssertEqual(RPQuest.JournalTab.editorSectionsCollapsed.discovery, false, "Discovery marked expanded in editorSectionsCollapsed")
        AssertEqual(sections.header.timeline:IsPlaying(), true, "Header collapse animation plays when discovery opens")
        AssertEqual(sections.discovery.timeline:IsPlaying(), true, "Discovery expand animation plays")

        sections.header.timeline:StepTo(0.5)
        sections.discovery.timeline:StepTo(0.5)
        AssertEqual(sections.discovery.body:IsHidden(), false, "Discovery body becomes visible during expand")
        AssertTrue(sections.discovery.divider._anchors[1].y >= sections.header.body:GetHeight(), "Discovery divider does not overlap header body mid-animation")

        sections.header.timeline:StepTo(0)
        sections.discovery.timeline:StepTo(1)
        AssertEqual(sections.header.body:IsHidden(), true, "Header body hides after exclusive collapse")
        AssertEqual(sections.discovery.body:IsHidden(), false, "Discovery body remains visible after expand")
        AssertEqual(sections.discovery.body:GetHeight(), sections.discovery.bodyHeight, "Discovery body reaches full height")
        local yDialogueAfter = sections.dialogue.divider._anchors[1].y
        AssertTrue(yDialogueAfter < yDialogueBefore, "Dialogue Y offset reflects smaller discovery body vs header body")

        -- Opening options collapses discovery, and reversing mid-animation flips directions cleanly
        RPQuest.JournalTab:ToggleEditorSection("options")
        AssertEqual(sections.discovery.isOpen, false, "Opening options collapses discovery")
        AssertEqual(sections.options.isOpen, true, "Options opens")
        sections.discovery.timeline:StepTo(0.5)
        sections.options.timeline:StepTo(0.5)
        RPQuest.JournalTab:ToggleEditorSection("discovery")
        AssertEqual(sections.discovery.isOpen, true, "Reversing mid-animation reopens discovery")
        AssertEqual(sections.discovery.timeline._direction, 1, "Discovery timeline direction flips forward")
        AssertEqual(sections.options.isOpen, false, "Reversing mid-animation collapses options")
        AssertEqual(sections.options.timeline._direction, -1, "Options timeline direction flips backward")
        sections.discovery.timeline:StepTo(1)
        sections.options.timeline:StepTo(0)
        AssertEqual(sections.options.body:IsHidden(), true, "Options body hides at 0")
        if RPQuest.JournalTab.editorScrollChild then
            local scrollHeightWithDiscovery = RPQuest.JournalTab.editorScrollChild:GetHeight()
            AssertTrue(scrollHeightWithDiscovery >= 474, "editorScrollChild height stays synchronized")
        end

        -- Collapsing the only open section leaves all sections collapsed
        RPQuest.JournalTab:ToggleEditorSection("discovery")
        sections.discovery.timeline:StepTo(0)
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section collapses on second toggle")

        -- Save a quest with options configured and verify OpenEditEditor keeps header expanded and other accordions collapsed by default
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.50,
            targetY = 0.50,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ stealthMode = "required" })
        local q = RPQuest.QuestRepository:SaveDraft("Misión Acordeón", "Prueba.", nil, "Listo.")
        AssertTrue(q ~= nil, "Quest saved for edit accordion test")

        RPQuest.JournalTab:OpenEditEditor(q.id)
        AssertEqual(sections.header.body:IsHidden(), false, "Header section starts expanded on edit")
        AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed on edit")
        AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed on edit")
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed on edit")
    end)

    RunTest("29. JournalTab:OpenTab defers SelectFragment during async scene transition from another scene", function()
        RPQuest.JournalTab:Initialize()

        local origIsShowing = SCENE_MANAGER.IsShowing
        local origShow = SCENE_MANAGER.Show
        local origSelectFragment = QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment
        local selectCalls = 0

        QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = function(tabsSelf, name)
            selectCalls = selectCalls + 1
            origSelectFragment(tabsSelf, name)
        end

        -- Simular transición asíncrona (ej. desde Notificaciones o Correo en SCENE_HIDING):
        -- SCENE_MANAGER:Show("questJournal") encola la escena pero IsShowing("questJournal") sigue false hasta SCENE_SHOWING.
        SCENE_MANAGER.IsShowing = function(_, sceneName)
            return false
        end
        SCENE_MANAGER.Show = function(_, sceneName)
            -- No cambia a SCENE_SHOWN de forma síncrona
        end

        RPQuest.JournalTab:OpenTab()
        AssertEqual(selectCalls, 0, "SelectFragment not called synchronously while previous scene is still hiding")
        AssertEqual(QUEST_JOURNAL_KEYBOARD.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "QuestJournal mode set before OnShowing")

        -- Cuando la escena previa termina de ocultarse, ESO dispara QUEST_JOURNAL_KEYBOARD:OnShowing()
        QUEST_JOURNAL_KEYBOARD:OnShowing()
        AssertEqual(selectCalls, 1, "SelectFragment called inside OnShowing once questJournal scene starts showing")

        -- Si questJournal ya estaba visible (p. ej. cambiando desde pestaña Quests), sí selecciona síncronamente
        SCENE_MANAGER.IsShowing = function(_, sceneName)
            return sceneName == "questJournal"
        end
        RPQuest.JournalTab:OpenTab()
        AssertEqual(selectCalls, 2, "SelectFragment called synchronously when questJournal is already showing")

        SCENE_MANAGER.IsShowing = origIsShowing
        SCENE_MANAGER.Show = origShow
        QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = origSelectFragment
    end)

    RunTest("37. OFFERED pending quest UI in JournalTab: Accept activates and Reject removes (Issue #143)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.JournalTab:Initialize()

        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Contrato Pendiente",
            description = "Acepta o rechaza.",
            mapId = mockState.mapId,
            zoneId = mockState.zoneId,
            mapName = "Auridon",
            targets = { { name = "Lobo", requiredCount = 1 } },
        })

        local offered, _, isDup = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_1",
        })
        AssertTrue(offered ~= nil, "Offered quest imported")
        AssertEqual(isDup, false, "First import is not duplicate")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Offered quest is not active yet")
        AssertEqual(RPQuest.QuestRepository:SetActiveQuest(offered.id), false, "Cannot set OFFERED quest active directly")

        -- Duplicate prevention by sourceMailId
        local dupQ, _, isDup2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_1",
        })
        AssertEqual(isDup2, true, "Second import with same sourceMailId detected as duplicate")
        AssertEqual(dupQ.id, offered.id, "Returns existing quest on duplicate")

        -- JournalTab shows Accept and Reject buttons for OFFERED quest
        RPQuest.JournalTab:SelectQuest(offered.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), false, "Accept button visible for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.btnRejectOffered:IsHidden(), false, "Reject button visible for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.btnActivate:IsHidden(), true, "Activate button hidden for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.visible(), false, "Abandon keybind hidden for OFFERED pending quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.enabled(), false, "Abandon keybind disabled for OFFERED pending quest")
        AssertEqual(RPQuest.JournalTab:ConfirmAbandonQuest(offered.id), false, "ConfirmAbandonQuest blocked for OFFERED pending quest")

        -- Accept activates quest
        local accepted = RPQuest.JournalTab:AcceptSelectedOfferedQuest()
        AssertEqual(accepted, true, "AcceptSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, offered.id, "Quest becomes active after Accept")
        AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), true, "Accept button hidden after Accept")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.visible(), true, "Abandon keybind visible after accepting quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.enabled(), true, "Abandon keybind enabled after accepting quest")

        -- Reject removes another offered quest
        local offered2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_2",
        })
        RPQuest.JournalTab:SelectQuest(offered2.id)
        local rejected = RPQuest.JournalTab:RejectSelectedOfferedQuest()
        AssertEqual(rejected, true, "RejectSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.QuestRepository:GetQuestById(offered2.id), nil, "Rejected quest removed from repository")
    end)

    RunTest("41. Show On Map keybind prompt visibility across quest selection, accept, activate, and modes (Issue #165)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab.panel:SetHidden(false)

        -- 1. No quest selected -> hidden
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden when no quest selected")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false when no quest selected")

        -- 2. Import and select offered quest -> visible
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local prepared = RPQuest.QuestRepository:SaveDraft("Misión Mapa", "Prueba Show On Map.")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local offered = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_map_1",
        })
        RPQuest.JournalTab:SelectQuest(offered.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible for selected offered quest")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true for selected offered quest")

        -- 3. Accept offered quest -> still visible immediately after accept
        local accepted = RPQuest.JournalTab:AcceptSelectedOfferedQuest()
        AssertEqual(accepted, true, "AcceptSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map remains visible after accepting quest")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible remains true after accepting quest")

        -- 4. Quest with recommendHideMapAreas=true -> still visible when selected in DETAIL mode
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Cultista",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.3,
            targetY = 0.3,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = true })
        local hiddenAreaQuest = RPQuest.QuestRepository:SaveDraft("Misión Sin Área", "Área oculta.")
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible even when recommendHideMapAreas is true")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true even when recommendHideMapAreas is true")

        -- 5. Callback invokes WorldMapArea:ShowQuestOnMap with selected quest
        local origShowQuestOnMap = RPQuest.WorldMapArea.ShowQuestOnMap
        local shownQuestId = nil
        RPQuest.WorldMapArea.ShowQuestOnMap = function(_, q)
            shownQuestId = q and q.id or nil
            return true
        end
        RPQuest.JournalTab.showOnMapDescriptor.callback()
        AssertEqual(shownQuestId, hiddenAreaQuest.id, "showOnMapDescriptor callback calls ShowQuestOnMap with selected quest")
        RPQuest.WorldMapArea.ShowQuestOnMap = origShowQuestOnMap

        -- 6. Editor mode -> hidden when draft has no coordinates, visible when draft has target or discovery
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:GetParent(), RPQuest.JournalTab.rightCol, "Show On Map keybind parented to rightCol so it remains visible in Editor mode")
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Editor mode when draft has no coordinates")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false in Editor mode when draft has no coordinates")

        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 381,
            worldX = 1000,
            worldY = 100,
            worldZ = 2000,
            mapId = 32,
            x = 0.42,
            y = 0.61,
            mapName = "Auridon",
        })
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible in Editor mode after adding discovery point")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true in Editor mode after adding discovery point")

        local origEditorShow = RPQuest.WorldMapArea.ShowQuestOnMap
        local shownEditorTarget = nil
        RPQuest.WorldMapArea.ShowQuestOnMap = function(_, target)
            shownEditorTarget = target
            return true
        end
        RPQuest.JournalTab.showOnMapDescriptor.callback()
        AssertEqual(shownEditorTarget, RPQuest.QuestRepository:GetDraft(), "showOnMapDescriptor callback in Editor mode passes live draft")
        RPQuest.WorldMapArea.ShowQuestOnMap = origEditorShow

        -- Text-only quest without coordinates in Detail mode -> hidden (vanilla behavior)
        RPQuest.QuestRepository:ClearDraftDiscoveries()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden again after clearing draft coordinates")
        RPQuest.JournalTab.titleEdit:SetText("Solo Texto")
        RPQuest.JournalTab:OnSaveDraftClicked()
        local textOnlyQuest = RPQuest.JournalTab.selectedQuestId and RPQuest.QuestRepository:GetQuestById(RPQuest.JournalTab.selectedQuestId)
        AssertEqual(textOnlyQuest ~= nil, true, "Text-only quest saved")
        RPQuest.JournalTab:SelectQuest(textOnlyQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Detail mode when quest has no coordinates")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false when quest has no coordinates")

        -- 7. Mail Send mode -> hidden
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:OpenMailSendView()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Mail Send mode")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false in Mail Send mode")

        -- Restore detail mode
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible again when returning to Detail mode")
    end)

    RunTest("Journal UI: Optional target editor toggle, detail label, manual Complete button, and master report", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenCreateEditor()

        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "MainTarget", mapId = 1, zoneId = 2, mapName = "Auridon", targetX = 0.5, targetY = 0.5 })
        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "OptionalTarget", mapId = 1, zoneId = 2, mapName = "Auridon", targetX = 0.5, targetY = 0.5 })
        RPQuest.JournalTab.selectedTargetIndex = 2
        RPQuest.JournalTab:RefreshEditorPane()

        AssertEqual(RPQuest.JournalTab.chkTargetOptional:IsHidden(), false, "chkTargetOptional visible when targets exist")
        AssertEqual(RPQuest.JournalTab.chkTargetOptional:IsEnabled(), true, "chkTargetOptional enabled when targets exist")
        RPQuest.JournalTab.chkTargetOptional:FireHandler("OnClicked")
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(draft.targets[2].optional, true, "Clicking chkTargetOptional toggles optional=true on selected target")

        local prepared = RPQuest.QuestRepository:SaveDraft("UI Optional Quest", "Desc")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master")
        RPQuest.QuestRepository:SetActiveQuest(imported.id)
        RPQuest.JournalTab:SelectQuest(imported.id)
        RPQuest.JournalTab:Refresh()

        local objText = RPQuest.JournalTab.detailObjText:GetText()
        AssertTrue(objText:find("Optional", 1, true) ~= nil, "Detail objectives label optional target with (Optional)")
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), true, "btnComplete hidden before mandatory target is done")

        RPQuest.QuestRepository:RecordTargetEliminated("MainTarget")
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), false, "btnComplete visible once mandatory target is done")

        RPQuest.JournalTab:OnCompleteQuestClicked()
        AssertEqual(imported.completed, true, "OnCompleteQuestClicked completes the quest")
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), true, "btnComplete hidden after quest is completed")

        -- Master report shows optional target completion status
        imported.completed = true
        local compCode = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
        local okVal, valRes = RPQuest.QuestRepository:ValidateResultCode(prepared.id, compCode)
        AssertEqual(okVal, true, "Prepared quest validates completion code")
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@Player", valRes)
        RPQuest.JournalTab:SelectQuest(prepared.id)
        RPQuest.JournalTab:Refresh()
        local statusText = RPQuest.JournalTab.detailStatus:GetText()
        AssertTrue(statusText:find("0/1", 1, true) ~= nil, "Prepared quest status shows 0/1 optional objectives completed")
    end)

    RunTest("Journal UI: Capture and clear target location in new draft and editing existing quest", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenTab()
        RPQuest.JournalTab:OpenCreateEditor()

        mockState.zoneId = 381
        mockState.worldX = 12000
        mockState.worldY = 100
        mockState.worldZ = 24000

        -- 1. New draft with a captured target
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Veiled Scout",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.JournalTab.selectedTargetIndex = 1
        RPQuest.JournalTab:RefreshEditorPane()

        local tab = RPQuest.JournalTab
        AssertEqual(tab.btnCaptureTargetLoc:IsHidden(), false, "btnCaptureTargetLoc visible when target exists")
        AssertTrue((tab.btnCaptureTargetLoc:GetText() or "") ~= "", "btnCaptureTargetLoc has label")
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), false, "btnClearTargetLoc visible before location capture")
        AssertEqual(tab.btnClearTargetLoc:IsEnabled(), false, "btnClearTargetLoc disabled before location capture")
        AssertEqual(tab.chkTargetLocRequired:IsHidden(), false, "chkTargetLocRequired visible before location capture")
        AssertEqual(tab.chkTargetLocRequired:IsEnabled(), false, "chkTargetLocRequired disabled before location capture")
        AssertEqual(tab.targetLocRadComboBox:IsEnabled(), false, "targetLocRadComboBox disabled before location capture")

        -- Capture location via button
        tab.btnCaptureTargetLoc:GetHandler("OnClicked")()
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(draft.targets[1]), true, "Target has captured location after btnCaptureTargetLoc")
        AssertEqual(tab.btnClearTargetLoc:IsEnabled(), true, "btnClearTargetLoc enabled immediately after capture")
        AssertEqual(tab.chkTargetLocRequired:IsEnabled(), true, "chkTargetLocRequired enabled immediately after capture")
        AssertEqual(tab.targetLocRadComboBox:IsEnabled(), true, "targetLocRadComboBox enabled immediately after capture")

        -- Toggle locationRequired = true, then clear location via btnClearTargetLoc
        tab.chkTargetLocRequired:FireHandler("OnClicked")
        AssertEqual(draft.targets[1].locationRequired, true, "chkTargetLocRequired sets locationRequired=true")

        tab.btnClearTargetLoc:GetHandler("OnClicked")()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(draft.targets[1]), false, "HasTargetLocation false after btnClearTargetLoc")
        AssertEqual(draft.targets[1].zoneId, nil, "zoneId cleared to nil")
        AssertEqual(draft.targets[1].worldX, nil, "worldX cleared to nil")
        AssertEqual(draft.targets[1].worldZ, nil, "worldZ cleared to nil")
        AssertEqual(draft.targets[1].radius, nil, "radius cleared to nil")
        AssertEqual(draft.targets[1].locationRequired, false, "locationRequired reset to false")
        AssertEqual(tab.btnClearTargetLoc:IsEnabled(), false, "btnClearTargetLoc disabled immediately after clear")
        AssertEqual(tab.chkTargetLocRequired:IsEnabled(), false, "chkTargetLocRequired disabled immediately after clear")
        AssertEqual(tab.targetLocRadComboBox:IsEnabled(), false, "targetLocRadComboBox disabled immediately after clear")

        -- Save new draft and verify cleared state persists
        local savedNew = RPQuest.QuestRepository:SaveDraft("Cleared Loc New Quest", "Desc")
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(savedNew.targets[1]), false, "Saved new quest has no target location")
        AssertEqual(savedNew.targets[1].locationRequired, false, "Saved new quest has locationRequired=false")

        -- 2. Existing quest with captured location -> edit -> clear -> save
        RPQuest.JournalTab:OpenCreateEditor()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Veiled Captain",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 15000, 25000, 1500)
        RPQuest.QuestRepository:UpdateDraftTarget(1, { locationRequired = true })
        local existingQuest = RPQuest.QuestRepository:SaveDraft("Existing Loc Quest", "Desc")
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(existingQuest.targets[1]), true, "Existing quest saved with target location")
        AssertEqual(existingQuest.targets[1].locationRequired, true, "Existing quest saved with locationRequired=true")

        tab:OpenEditEditor(existingQuest.id)
        AssertEqual(tab.btnClearTargetLoc:IsEnabled(), true, "btnClearTargetLoc enabled when editing quest with target location")
        AssertEqual(ZO_CheckButton_IsChecked(tab.chkTargetLocRequired), true, "chkTargetLocRequired checked when editing required loc")

        tab.btnClearTargetLoc:GetHandler("OnClicked")()
        local editDraft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(editDraft.targets[1]), false, "Edit draft target location cleared")
        AssertEqual(tab.btnClearTargetLoc:IsEnabled(), false, "btnClearTargetLoc disabled after clearing in edit mode")
        AssertEqual(tab.chkTargetLocRequired:IsEnabled(), false, "chkTargetLocRequired disabled after clearing in edit mode")

        local updatedQuest = RPQuest.QuestRepository:SaveDraft()
        AssertEqual(updatedQuest.id, existingQuest.id, "Editing updates the existing quest record")
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(updatedQuest.targets[1]), false, "Updated quest persists cleared target location")
        AssertEqual(updatedQuest.targets[1].zoneId, nil, "Updated quest target zoneId is nil")
        AssertEqual(updatedQuest.targets[1].worldX, nil, "Updated quest target worldX is nil")
        AssertEqual(updatedQuest.targets[1].worldZ, nil, "Updated quest target worldZ is nil")
        AssertEqual(updatedQuest.targets[1].locationRequired, false, "Updated quest target locationRequired is false")
    end)

    RunTest("22. Accordion Animation: ZO_TreeOpenAnimation expand/collapse, easing, mid-animation reversal, and hidden snap", function()
        local roles = RPQuest.Constants.QUEST_ROLE
        RPQuest.QuestRepository:Initialize({
            quests = {
                { id = 1, title = "Active A", description = "", role = roles.RECEIVED, completed = false },
                { id = 2, title = "Active B", description = "", role = roles.RECEIVED, completed = false },
                { id = 3, title = "Prep A", description = "", role = roles.PREPARED, completed = false },
                { id = 4, title = "Sent A", description = "", role = roles.PREPARED, sentTo = "@Dest", completed = false },
            },
        })
        RPQuest.JournalTab:Initialize()
        local tab = RPQuest.JournalTab
        tab.collapsedSections = { pending = true, missions = false, completed = true, preparing = true, sent = true }
        tab.panel:SetHidden(true)
        tab:Refresh()
        tab.panel:SetHidden(false)

        local secMissions = tab.accordionSections.missions
        local secPreparing = tab.accordionSections.preparing
        local secSent = tab.accordionSections.sent

        -- Initial state: missions open (height = 60, alpha = 1), preparing/sent collapsed (height = 0, hidden)
        AssertEqual(secMissions.openPercentage, 1, "Missions starts at openPercentage = 1")
        AssertEqual(secMissions.childContainer:GetHeight(), 60, "Missions childContainer height = 2 * 30")
        AssertEqual(secMissions.childContainer:GetAlpha(), 1, "Missions childContainer alpha = 1")
        AssertEqual(secPreparing.childContainer:IsHidden(), true, "Preparing childContainer starts hidden")

        -- 1. Toggle Preparing while visible -> Missions collapses with EaseIn, Preparing expands with EaseOut
        tab:ToggleSection("preparing")
        AssertEqual(secMissions.timeline:IsPlaying(), true, "Missions collapse timeline starts playing")
        AssertEqual(secPreparing.timeline:IsPlaying(), true, "Preparing expand timeline starts playing")

        -- Step halfway through the 300ms animation (rawProgress = 0.5)
        secMissions.timeline:StepTo(0.5)
        secPreparing.timeline:StepTo(0.5)
        AssertEqual(secMissions.openPercentage, 0.25, "Missions uses ZO_EaseInQuadratic at 0.5 -> 0.25")
        AssertEqual(secMissions.childContainer:GetHeight(), 15, "Missions height interpolates to 15 (0.25 * 60)")
        AssertEqual(secMissions.childContainer:GetAlpha(), 0.5, "Missions alpha interpolates to 0.5")
        AssertEqual(secPreparing.openPercentage, 0.75, "Preparing uses ZO_EaseOutQuadratic at 0.5 -> 0.75")
        AssertEqual(secPreparing.childContainer:GetHeight(), 23, "Preparing height interpolates to round(0.75 * 30) = 23")
        AssertEqual(secPreparing.childContainer:GetAlpha(), 0.5, "Preparing alpha interpolates to 0.5")

        -- Check dynamic Y-anchor of Sent header shifts smoothly during animation
        local _, _, _, _, _, sentYMid = secSent.headerBtn:GetAnchor(1)
        -- missions header (30) + missions children (15) + preparing header (30) + preparing children (23) = 98
        AssertEqual(sentYMid, 98, "Sent header Y-anchor tracks animated heights of sections above")

        -- Finish animations
        secMissions.timeline:StepTo(0)
        secPreparing.timeline:StepTo(1)
        AssertEqual(secMissions.timeline:IsPlaying(), false, "Missions timeline stops at 0")
        AssertEqual(secMissions.childContainer:IsHidden(), true, "Missions childContainer hides at 0")
        AssertEqual(secPreparing.timeline:IsPlaying(), false, "Preparing timeline stops at 1")
        AssertEqual(secPreparing.childContainer:GetHeight(), 30, "Preparing height reaches full 30")
        AssertEqual(secPreparing.childContainer:GetAlpha(), 1, "Preparing alpha reaches 1")

        -- 2. Reversing mid-animation when toggling Sent while Preparing is still animating
        tab:ToggleSection("sent")
        AssertEqual(secPreparing.timeline:IsPlaying(), true, "Preparing starts collapsing")
        AssertEqual(secSent.timeline:IsPlaying(), true, "Sent starts expanding")
        secPreparing.timeline:StepTo(0.5)
        secSent.timeline:StepTo(0.5)
        -- Reverse back to Preparing mid-flight
        tab:ToggleSection("preparing")
        AssertEqual(secPreparing.isOpen, true, "Preparing reverses back to open mid-animation")
        AssertEqual(secPreparing.timeline._direction, 1, "Preparing timeline direction flips forward")
        AssertEqual(secSent.isOpen, false, "Sent reverses back to closed mid-animation")
        AssertEqual(secSent.timeline._direction, -1, "Sent timeline direction flips backward")
        secPreparing.timeline:StepTo(1)
        secSent.timeline:StepTo(0)

        -- 3. Hidden panel snaps immediately without playing timelines
        tab.panel:SetHidden(true)
        tab:ToggleSection("missions")
        AssertEqual(secMissions.timeline:IsPlaying(), false, "Hidden panel snaps Missions without playing timeline")
        AssertEqual(secMissions.openPercentage, 1, "Hidden panel snaps Missions openPercentage to 1")
        AssertEqual(secPreparing.openPercentage, 0, "Hidden panel snaps Preparing openPercentage to 0")
        AssertEqual(secPreparing.childContainer:IsHidden(), true, "Hidden panel hides collapsed childContainer")
        tab.panel:SetHidden(false)
    end)

    RunTest("JournalDetailPane shows Copy button only for Preparing and Sent quests", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(repo:GetDefaults())
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab.panel:SetHidden(false)

        local prep = repo:BuildQuestRecord(10, "Prep Copy UI", "Desc", {
            { name = "Target A", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 1 }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        local sent = repo:BuildQuestRecord(11, "Sent Copy UI", "Desc", {
            { name = "Target B", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 1, sentTo = "@Friend", sentAt = 12345 }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        local rec = repo:BuildQuestRecord(12, "Received UI", "Desc", {
            { name = "Target C", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 1 }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(repo.savedVars.quests, prep)
        table.insert(repo.savedVars.quests, sent)
        table.insert(repo.savedVars.quests, rec)
        repo._questById[10] = prep
        repo._questById[11] = sent
        repo._questById[12] = rec

        tab:SelectQuest(12)
        AssertEqual(tab.btnCopy:IsHidden(), true, "Copy button hidden for received quest")

        tab:SelectQuest(10)
        AssertEqual(tab.btnCopy:IsHidden(), false, "Copy button visible for Preparing quest")

        tab:SelectQuest(11)
        AssertEqual(tab.btnCopy:IsHidden(), false, "Copy button visible for Sent quest")

        local copied = tab:DuplicateSelectedQuest()
        AssertTrue(copied ~= nil, "DuplicateSelectedQuest creates copy from Sent quest")
        AssertEqual(repo:GetQuestLifecycle(copied), "draft", "Copied quest is in Preparing")
        AssertEqual(repo:GetQuestResolution(copied), nil, "Copied quest has no resolution")
        AssertEqual(tab.selectedQuestId, copied.id, "UI selects the newly copied quest")
    end)

    RunTest("Test Quest simulates full lifecycle (start, progress, fail, complete, stop/reset) without sending mail", function()
        local repo = RPQuest.QuestRepository
        local defaults = repo:GetDefaults()
        defaults.settings.autoSendCompletionMail = true
        repo:Initialize(defaults)
        RPQuest.CombatTracker:Initialize()
        RPQuest.DiscoveryTracker:Initialize()
        RPQuest.DialogueInjector:Initialize()
        RPQuest.MailTransport:Initialize()
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab.panel:SetHidden(false)

        local origSentMail = RPQuest.MailTransport.SendCompletionReport
        local sentMailCount = 0
        RPQuest.MailTransport.SendCompletionReport = function()
            sentMailCount = sentMailCount + 1
            return true
        end

        mockState.zoneId = 41
        mockState.mapId = 100
        mockState.mapX = 0.50
        mockState.mapY = 0.50
        mockState.worldZoneId = 41
        mockState.worldX = 1000
        mockState.worldZ = 2000

        local prep = repo:BuildQuestRecord(50, "Prueba Completa", "Simulación E2E", {
            {
                name = "Bandido",
                currentCount = 0,
                requiredCount = 1,
                customMessageInLocation = "Bandido abatido",
                locationRequired = true,
                worldZoneId = 41,
                worldX = 1000,
                worldZ = 2000,
                locationRadius = 2500,
            },
        }, {
            mapId = 100,
            zoneId = 41,
            areaCenterX = 0.50,
            areaCenterY = 0.50,
            areaRadius = 0.10,
            clue = "Habla con el informante",
            completionMessage = "¡Prueba completada con éxito!",
            senderDisplayName = "@AuthorGM",
            discoveries = {
                { zoneId = 41, worldX = 1500, worldZ = 2500, radius = 1500, message = "Pista descubierta", discovered = false },
            },
            dialogues = {
                { npcName = "Informante", zoneId = 41, clue = "Pregunta por el campamento", response = "Están al norte." },
            },
        }, RPQuest.Constants.QUEST_ROLE.PREPARED)

        table.insert(repo.savedVars.quests, prep)
        repo._questById[50] = prep
        tab:SelectQuest(50)

        -- 1. Click Test Quest -> activates quest, enables trackers, emits AnnounceQuestAccepted
        mockState.csaMessages = {}
        tab:OnToggleActiveClicked()
        AssertEqual(repo:GetActiveQuest().id, 50, "Test Quest activates prepared quest")
        AssertEqual(RPQuest.CombatTracker._isRegistered, true, "CombatTracker registered in Test Quest mode")
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, true, "DiscoveryTracker polling in Test Quest mode")
        AssertEqual(#mockState.csaMessages, 1, "Test Quest emits initial Quest Accepted CSA banner")
        AssertEqual(mockState.csaMessages[1].sound, SOUNDS.QUEST_ACCEPTED, "Test Quest plays SOUNDS.QUEST_ACCEPTED")
        AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED, "Test Quest uses QUEST_ADDED CSA type")

        local dlgMatch = repo:FindDialogueForActiveQuest("Informante", 41)
        AssertTrue(dlgMatch ~= nil and dlgMatch.clue == "Pregunta por el campamento", "DialogueInjector finds dialogue in Test Quest mode")

        -- 2. Fail condition (kill Bandido outside required target location) -> triggers failure state & banner
        mockState.worldX = 99999
        mockState.worldZ = 99999
        mockState.csaMessages = {}
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", "", 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Bandido", 0, 1, 0, 0, false, 1, 5001, 1)
        AssertEqual(prep.failed, true, "Prepared quest marked failed when failing condition in Test Quest mode")
        AssertEqual(repo:GetActiveQuest(), nil, "Failed prepared quest is no longer active")
        AssertEqual(#mockState.csaMessages, 1, "Failure emits Quest Failed CSA banner")
        AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_PROGRESSION_CHANGED, "Failure uses progression changed CSA")

        -- 3. Click Test Quest again after failure -> resets failed state, reactivates, and emits Quest Accepted
        mockState.csaMessages = {}
        tab:OnToggleActiveClicked()
        AssertEqual(prep.failed, false, "Clicking Test Quest after failure resets failed flag")
        AssertEqual(repo:GetActiveQuest().id, 50, "Prepared quest reactivated after failure")
        AssertEqual(#mockState.csaMessages, 1, "Restarting Test Quest after failure emits Quest Accepted CSA")

        -- 4. Progress target + discovery -> shows intermediate messages and completes without sending mail
        mockState.worldX = 1000
        mockState.worldZ = 2000
        mockState.csaMessages = {}
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", "", 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Bandido", 0, 1, 0, 0, false, 1, 5002, 1)
        AssertEqual(prep.targets[1].currentCount, 1, "Target progress recorded in Test Quest mode")
        AssertEqual(prep.completed, false, "Quest waits for pending discovery before completing")
        AssertEqual(#mockState.csaMessages, 2, "Progress + custom target message emitted")

        RPQuest.DiscoveryTracker:EvaluatePlayerPosition(41, 1500, 0, 2500)
        AssertEqual(prep.discoveries[1].discovered, true, "Discovery recorded in Test Quest mode")
        AssertEqual(prep.completed, true, "Prepared quest completes when all objectives are met")
        AssertEqual(repo:GetActiveQuest(), nil, "Completed prepared quest clears activeQuestId")
        AssertEqual(#mockState.csaMessages, 4, "Discovery + Quest Completed CSA banners emitted")
        AssertEqual(mockState.csaMessages[4].sound, SOUNDS.QUEST_COMPLETED, "Final banner plays SOUNDS.QUEST_COMPLETED")
        AssertEqual(mockState.csaMessages[4].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED, "Final banner uses QUEST_COMPLETED CSA type")
        AssertEqual(sentMailCount, 0, "Completing quest in Test Quest mode does NOT send external mail")

        -- 5. Start Test Quest again, make partial progress, then Stop Testing -> cleanly clears state without stale CSA
        tab:OnToggleActiveClicked()
        RPQuest.DiscoveryTracker:EvaluatePlayerPosition(41, 1500, 0, 2500)
        AssertEqual(prep.discoveries[1].discovered, true, "Partial discovery recorded before Stop Testing")

        mockState.csaMessages = {}
        tab:OnToggleActiveClicked() -- BTN_STOP_TEST
        AssertEqual(repo:GetActiveQuest(), nil, "Stop Testing clears active quest")
        AssertEqual(prep.discoveries[1].discovered, false, "Stop Testing resets partial discovery state")
        AssertEqual(prep.targets[1].currentCount, 0, "Stop Testing resets partial target state")
        AssertEqual(prep.completed, false, "Stop Testing clears completed flag")
        AssertEqual(prep.failed, false, "Stop Testing clears failed flag")
        AssertEqual(RPQuest.CombatTracker._isRegistered, false, "Stop Testing unregisters CombatTracker")
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, false, "Stop Testing stops DiscoveryTracker polling")
        AssertEqual(#mockState.csaMessages, 0, "Stop Testing emits no stale CSA announcements")

        RPQuest.MailTransport.SendCompletionReport = origSentMail
    end)

    RunTest("JournalDetailPane shows Migrate button and blocks Edit/Send/Test on outdated PREPARED quest", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local prep = repo:BuildQuestRecord(1, "Old Quest", "Desc", {
            { name = "Imp", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2 }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        prep.needsMigration = true
        prep.migrationReason = "Outdated stealth field"
        table.insert(repo.savedVars.quests, prep)
        repo._questById[prep.id] = prep

        local tab = RPQuest.JournalTab
        tab:SelectQuest(prep.id)

        AssertEqual(tab.btnMigrate:IsHidden(), false, "Migrate button visible for outdated PREPARED quest")
        AssertEqual(tab.btnActivate:IsHidden(), true, "Test button hidden for outdated PREPARED quest")
        AssertEqual(tab.btnEdit:IsHidden(), true, "Edit button hidden for outdated PREPARED quest")
        AssertEqual(tab.btnCopy:IsHidden(), true, "Copy button hidden for outdated PREPARED quest")
        AssertEqual(tab.btnSendDirect:IsHidden(), true, "Send button hidden for outdated PREPARED quest")
        AssertTrue(tab.detailStatus:GetText():find("Outdated stealth field", 1, true) ~= nil, "Migration reason shown in status")
        AssertEqual(tab:SendSelectedPreparedQuest(), false, "SendSelectedPreparedQuest blocked when needsMigration")

        local migrated = tab:MigrateSelectedQuest()
        AssertTrue(migrated ~= nil, "MigrateSelectedQuest creates new quest")
        AssertEqual(tab.viewMode, tab.VIEW_MODE.EDITOR, "MigrateSelectedQuest opens editor on migrated copy")
        AssertEqual(repo:GetDraft().editingQuestId, migrated.id, "Editor loads migrated copy")
        AssertTrue(migrated.needsMigration == nil, "Migrated copy clears needsMigration")
    end)

    RunTest("JournalEditorPane dropdown & JournalDetailPane stealth mode rendering", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local tab = RPQuest.JournalTab
        tab:Initialize()

        local combo = tab.stealthComboBox
        AssertTrue(combo ~= nil, "Stealth combo box created")
        AssertEqual(combo:GetNumItems(), 3, "Stealth combo box has 3 options (Disabled, Optional, Required)")

        -- Select Required via dropdown callback
        local items = combo:GetItems()
        combo:SelectItem(items[3], false)
        AssertEqual(repo:GetDraft().stealthMode, "required", "Selecting item 3 updates draft stealthMode to required")

        -- RefreshEditorPane syncs dropdown without overwriting draft
        repo:UpdateDraftFields({ stealthMode = "optional" })
        tab:RefreshEditorPane()
        AssertEqual(combo:GetSelectedItemData().stealthMode, "optional", "RefreshEditorPane syncs dropdown to optional")

        -- Detail pane distinguishes Optional vs Required vs Required+Failed
        local qOpt = repo:BuildQuestRecord(10, "Opt Quest", "D", {
            { name = "G", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "optional" }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(repo.savedVars.quests, qOpt)
        repo._questById[10] = qOpt
        tab:SelectQuest(10)
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "Detail pane shows MISSION DETAILS when stealth is optional")
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_OPTIONAL_UNDETECTED"), 1, true) ~= nil, "Detail pane shows Optional Undetected")

        local qReq = repo:BuildQuestRecord(11, "Req Quest", "D", {
            { name = "G", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "required" }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        qReq.wasDetected = true
        qReq.failed = true
        table.insert(repo.savedVars.quests, qReq)
        repo._questById[11] = qReq
        tab:SelectQuest(11)
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_REQUIRED_FAILED"), 1, true) ~= nil, "Detail pane shows Required Failed")
    end)

    RunTest("Issue #253: + New creates localized Preparing draft, auto-preserves edits, removes Cancel, and allows Abandon", function()
        -- 1. English: + New creates "New Quest" immediately in Preparing, allows duplicates, expands Preparing, selects it
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab:OpenTab()

        AssertEqual(tab.btnCancelEditor, nil, "Cancel button removed from editor footer")

        tab:OpenCreateEditor()
        local prepared = repo:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#prepared, 1, "First + New immediately creates 1 quest in Preparing")
        local q1 = prepared[1]
        AssertEqual(q1.title, "New Quest", "EN default title is 'New Quest' without numeric suffix")
        AssertEqual(tab.selectedQuestId, q1.id, "Newly created quest is selected in left tree")
        AssertEqual(tab.collapsedSections.preparing, false, "Preparing accordion expands automatically")
        AssertEqual(tab.viewMode, tab.VIEW_MODE.EDITOR, "Editor opens immediately")
        AssertEqual(tab.titleEdit:GetText(), "New Quest", "Editor title input prefilled with 'New Quest'")

        -- [X] Abandon is available for newly created Preparing draft in Editor mode
        AssertEqual(tab.abandonQuestDescriptor.visible(), true, "Abandon keybind visible in Editor mode for Preparing draft")
        AssertEqual(tab.abandonQuestDescriptor.enabled(), true, "Abandon keybind enabled in Editor mode for Preparing draft")

        -- 2. Edit fields + dialogue + discovery without clicking Save Draft, then switch via + New -> auto-preserved!
        tab.titleEdit:SetText("Moonlit Contract")
        tab.titleEdit:FireHandler("OnTextChanged")
        tab.descEdit:SetText("Meet at the docks.")
        tab.descEdit:FireHandler("OnTextChanged")
        tab.recipientEdit:SetText("@GuildMate")
        tab.recipientEdit:FireHandler("OnTextChanged")
        tab.completionEdit:SetText("Well done.")
        tab.completionEdit:FireHandler("OnTextChanged")
        repo:AddDraftDialogue("Razum-dar", 381, "Check the crates.", "Any news?")
        repo:AddDraftDiscoveryPoint({ zoneId = 381, worldX = 1000, worldY = 50, worldZ = 2000, mapId = 32, message = "Hidden note" })

        -- Second + New creates another "New Quest" (duplicates allowed) and auto-preserves q1
        tab:OpenCreateEditor()
        prepared = repo:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#prepared, 2, "Second + New creates second quest in Preparing")
        local q2 = prepared[2]
        AssertEqual(q2.title, "New Quest", "Second draft also gets 'New Quest' without numbering")
        AssertEqual(tab.selectedQuestId, q2.id, "Second draft selected")

        -- Verify q1 preserved all edits
        local q1Reloaded = repo:GetQuestById(q1.id)
        AssertEqual(q1Reloaded.title, "Moonlit Contract", "Auto-preserved title on + New switch")
        AssertEqual(q1Reloaded.description, "Meet at the docks.", "Auto-preserved description on + New switch")
        AssertEqual(q1Reloaded.recipientAccount, "@GuildMate", "Auto-preserved recipient on + New switch")
        AssertEqual(q1Reloaded.completionMessage, "Well done.", "Auto-preserved completionMessage on + New switch")
        AssertEqual(#q1Reloaded.dialogues, 1, "Auto-preserved dialogue on + New switch")
        AssertEqual(#q1Reloaded.discoveries, 1, "Auto-preserved discovery on + New switch")

        -- Third + New creates duplicate "New Quest" alongside q2
        tab:OpenCreateEditor()
        prepared = repo:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#prepared, 3, "Third + New creates third quest")
        local q3 = prepared[3]
        AssertEqual(q3.title, "New Quest", "Duplicate 'New Quest' title allowed")

        -- 3. Edit q3 and close/hide journal -> auto-preserved without Save Draft
        tab.titleEdit:SetText("Closed Journal Draft")
        tab.descEdit:SetText("Saved on close.")
        tab.panel:FireHandler("OnHide")
        local q3Reloaded = repo:GetQuestById(q3.id)
        AssertEqual(q3Reloaded.title, "Closed Journal Draft", "Auto-preserved title on journal OnHide")
        AssertEqual(q3Reloaded.description, "Saved on close.", "Auto-preserved description on journal OnHide")

        -- 4. Switch to q1 via SelectQuest while editing q3 -> auto-preserves q3 edits
        tab.descEdit:SetText("Updated before SelectQuest.")
        tab:SelectQuest(q1.id)
        AssertEqual(repo:GetQuestById(q3.id).description, "Updated before SelectQuest.", "Auto-preserved edits on SelectQuest")
        AssertEqual(tab.viewMode, tab.VIEW_MODE.DETAIL, "SelectQuest switches to Detail mode")

        -- 5. Abandoning a Preparing draft from Editor mode deletes it and returns to Detail mode
        tab:OpenEditEditor(q2.id)
        AssertEqual(tab.viewMode, tab.VIEW_MODE.EDITOR, "Opened q2 in Editor mode")
        AssertEqual(tab:ConfirmAbandonQuest(q2.id), true, "ConfirmAbandonQuest opens dialog for Preparing draft")
        local dlg = ESO_Dialogs["RPQUEST_ABANDON_QUEST"]
        dlg.buttons[1].callback({ data = { questId = q2.id } })
        AssertEqual(repo:GetQuestById(q2.id), nil, "Confirmed Abandon deletes Preparing draft")
        AssertEqual(tab.viewMode, tab.VIEW_MODE.DETAIL, "Deleting active editor draft returns to Detail mode")

        -- 6. Spanish locale: + New creates "Nueva Misión"
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")
        tab:OpenCreateEditor()
        local qEs = repo:GetQuestById(tab.selectedQuestId)
        AssertEqual(qEs.title, "Nueva Misión", "ES default title is 'Nueva Misión' without numeric suffix")
    end)

    RunTest("Issue #270: JournalTab allows OnSaveDraftClicked without objectives and alerts on Test/Send", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local repo = RPQuest.QuestRepository
        repo:Initialize({})
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        local tab = RPQuest.JournalTab
        tab:OpenCreateEditor()
        tab.titleEdit:SetText("Empty Objective Draft")
        tab.descEdit:SetText("Story only so far.")
        tab.completionEdit:SetText("All done.")
        tab.recipientEdit:SetText("@Friend")

        mockState.csaMessages = {}
        tab:OnSaveDraftClicked()

        local prepared = repo:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#prepared, 1, "Objective-less draft saved via OnSaveDraftClicked")
        local q = prepared[1]
        AssertEqual(q.title, "Empty Objective Draft", "Saved draft title matches")
        AssertEqual(q.description, "Story only so far.", "Saved draft description matches")
        AssertEqual(q.completionMessage, "All done.", "Saved draft completionMessage matches")
        AssertEqual(q.recipientAccount, "@Friend", "Saved draft recipient matches")

        tab:SelectQuest(q.id)
        mockState.alerts = {}
        tab:OnToggleActiveClicked()
        AssertEqual(repo:GetActiveQuest(), nil, "Test Quest does not activate objective-less draft")
        AssertTrue(#(mockState.alerts or {}) > 0, "Test Quest shows localized alert for missing objective")

        mockState.alerts = {}
        local sent = tab:SendSelectedPreparedQuest()
        AssertEqual(sent, false, "SendSelectedPreparedQuest rejects objective-less draft")
        AssertTrue(#(mockState.alerts or {}) > 0, "Send shows localized alert for missing objective")
    end)

    RunTest("Issue #275: JournalTab always keeps one visible accordion section with quests expanded", function()
        local roles = RPQuest.Constants.QUEST_ROLE
        local repo = RPQuest.QuestRepository
        repo:Initialize({
            quests = {
                { id = 101, title = "Draft Only", description = "Desc", role = roles.PREPARED, completed = false },
                { id = 102, title = "Sent Only", description = "Desc", role = roles.PREPARED, sentTo = "@Dest", completed = false },
            },
        })
        RPQuest.JournalTab:Initialize()
        local tab = RPQuest.JournalTab
        -- Default state has missions = false, preparing/sent = true, but missions is empty
        tab.viewMode = tab.VIEW_MODE.DETAIL
        tab.collapsedSections = { pending = true, missions = false, completed = true, preparing = true, sent = true }
        tab.selectedQuestId = nil
        tab.panel:SetHidden(false)
        tab:Refresh()

        -- Right pane falls back to allQuests[1] (preparing), so preparing must auto-expand
        AssertEqual(tab.selectedQuestId, 101, "Detail view selects fallback quest 101")
        AssertEqual(tab.collapsedSections.preparing, false, "Preparing auto-expands when missions is empty")
        AssertEqual(tab.collapsedSections.missions, true, "Empty missions section collapses when preparing auto-expands")
        AssertEqual(tab.accordionSections.preparing.isOpen, true, "Preparing accordion UI is open")
        AssertEqual(tab.accordionSections.sent.isOpen, false, "Sent accordion UI starts closed")

        -- Clicking already-open Preparing does NOT collapse it
        tab:ToggleSection("preparing")
        AssertEqual(tab.collapsedSections.preparing, false, "ToggleSection on open preparing keeps it expanded")
        AssertEqual(tab.accordionSections.preparing.isOpen, true, "Preparing accordion UI remains open")

        -- Switching to Sent expands Sent and collapses Preparing; clicking Sent again does NOT collapse it
        tab:ToggleSection("sent")
        AssertEqual(tab.collapsedSections.sent, false, "Sent expands on toggle")
        AssertEqual(tab.collapsedSections.preparing, true, "Preparing collapses when Sent expands")
        tab:SelectQuest(nil)
        tab:ToggleSection("sent")
        AssertEqual(tab.collapsedSections.sent, false, "Sent stays expanded even without selected quest")

        -- RefreshQuestList with nil selectedQuestId and activeQuest in sent expands sent
        tab.collapsedSections = { pending = true, missions = false, completed = true, preparing = true, sent = true }
        tab.selectedQuestId = nil
        tab:RefreshQuestList(repo:GetAllQuests(), repo:GetQuestById(102))
        AssertEqual(tab.collapsedSections.sent, false, "RefreshQuestList expands activeQuest section when no section with quests is open")

        -- Deleting the last quest in the currently expanded section (sent) auto-expands remaining section (preparing)
        repo:DeleteQuest(102)
        AssertEqual(tab.collapsedSections.preparing, false, "Deleting last quest in sent auto-expands preparing")
        AssertEqual(tab.accordionSections.preparing.isOpen, true, "Preparing accordion UI opens after sent becomes empty")
    end)

    RunTest("Issue #276: JournalTab persists lastSectionKey and lastSelectedQuestId across sessions with safe fallbacks", function()
        local roles = RPQuest.Constants.QUEST_ROLE
        local repo = RPQuest.QuestRepository
        local savedVars = {
            quests = {
                { id = 201, title = "Active Mission", description = "D1", role = roles.RECEIVED, completed = false },
                { id = 202, title = "Completed A", description = "D2", role = roles.RECEIVED, completed = true },
                { id = 203, title = "Completed B", description = "D3", role = roles.RECEIVED, completed = true },
                { id = 204, title = "Prepared Draft", description = "D4", role = roles.PREPARED, completed = false },
            },
        }
        repo:Initialize(savedVars)
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab.panel:SetHidden(false)
        tab.viewMode = tab.VIEW_MODE.DETAIL

        -- Switch to "completed" and select quest 203
        tab:ToggleSection("completed")
        tab:SelectQuest(203)

        local uiState = repo:GetJournalUiState()
        AssertEqual(uiState.lastSectionKey, "completed", "ToggleSection persists lastSectionKey in SavedVars")
        AssertEqual(uiState.lastSelectedQuestId, 203, "SelectQuest persists lastSelectedQuestId in SavedVars")

        -- 1. Simulate /reloadui / new session with the same SavedVars
        tab.collapsedSections = nil
        tab.selectedQuestId = nil
        repo:Initialize(savedVars)
        tab:RestoreUiState()
        tab:Refresh()

        AssertEqual(tab.collapsedSections.completed, false, "Completed section restored as expanded after reinit")
        AssertEqual(tab.collapsedSections.missions, true, "Missions section restored as collapsed after reinit")
        AssertEqual(tab.selectedQuestId, 203, "Selected quest 203 restored after reinit")

        -- 2. Simulate previous selected quest 203 removed while "completed" still has 202 (and no activeQuest)
        table.remove(savedVars.quests, 3) -- remove id 203
        tab.collapsedSections = nil
        tab.selectedQuestId = nil
        repo:Initialize(savedVars)
        AssertEqual(repo:GetJournalUiState().lastSelectedQuestId, nil, "Missing lastSelectedQuestId cleared on repo init")
        tab:RestoreUiState()
        tab:Refresh()

        AssertEqual(tab.collapsedSections.completed, false, "Completed section remains expanded when it still has quests")
        AssertEqual(tab.selectedQuestId, 202, "Fallback selects remaining quest 202 in open section")

        -- 3. Simulate all quests in "completed" removed -> fallback honors #275 invariant
        table.remove(savedVars.quests, 2) -- remove id 202
        savedVars.activeQuestId = 201
        tab.collapsedSections = nil
        tab.selectedQuestId = nil
        repo:Initialize(savedVars)
        tab:RestoreUiState()
        tab:Refresh()

        AssertEqual(tab.selectedQuestId, 201, "Fallback selects activeQuest 201 when previous quest is gone")
        AssertEqual(tab.collapsedSections.missions, false, "Fallback expands section of activeQuest when previous section is empty")
        AssertEqual(tab.collapsedSections.completed, true, "Empty completed section collapses on fallback")
        AssertEqual(repo:GetJournalUiState().lastSectionKey, "missions", "Fallback updates persisted lastSectionKey")
    end)

    RunTest("JournalDetailPane: Master recommendation notice, independent per-quest map toggles, and Show on Map", function()
        local repo = RPQuest.QuestRepository
        local tab = RPQuest.JournalTab
        local savedVars = repo:GetDefaults()
        repo:Initialize(savedVars)
        tab.Initialize = tab.Initialize or function() end
        tab:Initialize()
        tab.panel:SetHidden(false)

        -- Prepare Quest A (recommendHideMapAreas = true, NO target location)
        repo:ResetDraft()
        repo:SetDraftCapturedTarget({
            targetName = "Bandit Scout",
            mapId = 45,
            zoneId = 104,
            mapName = "Glenumbra",
            targetX = 0.35,
            targetY = 0.45,
        })
        repo:UpdateDraftFields({ recommendHideMapAreas = true })
        local prepA = repo:SaveDraft("Quest A", "No target location.")
        local codeA = repo:ExportQuestToCode(prepA.id)

        -- Prepare Quest B (recommendHideMapAreas = false, WITH target location)
        repo:ResetDraft()
        repo:SetDraftCapturedTarget({
            targetName = "Necromancer",
            mapId = 45,
            zoneId = 104,
            mapName = "Glenumbra",
            targetX = 0.65,
            targetY = 0.55,
        })
        repo:CaptureDraftTargetLocation(1, 104, 65000, 55000, 1500)
        repo:UpdateDraftFields({ recommendHideMapAreas = false })
        local prepB = repo:SaveDraft("Quest B", "With target location.")
        local codeB = repo:ExportQuestToCode(prepB.id)

        -- 1. Inactive prepared quest: MAP MARKERS segment hidden in Master view
        tab:SelectQuest(prepA.id)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), true, "Player-facing MISSION DETAILS block hidden in Master summary view")
        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), true, "MAP MARKERS header hidden on inactive prepared quest")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), true, "Search row hidden on inactive prepared quest")
        AssertEqual(tab.mapMarkerLocationRow:IsHidden(), true, "Location row hidden on inactive prepared quest")
        AssertEqual(tab.mapMarkerDiscoveryRow:IsHidden(), true, "Discovery row hidden on inactive prepared quest")

        -- 2. Testing prepared quest (active): switches to player view with MISSION DETAILS + TASKS + MAP MARKERS (applicable rows only)
        repo:SetActiveQuest(prepA.id)
        tab:SelectQuest(prepA.id)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "MISSION DETAILS block shown when testing prepared quest with recommendHideMapAreas=true")
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("DETAIL_MAP_MARKERS_NOT_RECOMMENDED"), 1, true) ~= nil, "MISSION DETAILS shows not recommended line")
        AssertEqual(tab.detailObjHeader:GetText(), RPQuest.Locale:Get("LABEL_OBJECTIVE_HEADER"), "TASKS header shown when testing prepared quest")
        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), false, "MAP MARKERS header visible when testing prepared quest")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), false, "Search Areas row visible when testing prepared quest")
        AssertEqual(tab.mapMarkerLocationRow:IsHidden(), true, "Location row hidden when no target has captured location")
        AssertEqual(tab.mapMarkerDiscoveryRow:IsHidden(), true, "Discovery row hidden when quest has no discovery points")

        -- Verify vertical anchoring avoids overlap
        local _, _, mapHdrRelTo = tab.detailMapMarkersHeader:GetAnchor(1)
        AssertEqual(mapHdrRelTo, tab.detailObjText, "MAP MARKERS header anchored below detailObjText")
        local _, _, actRelTo = tab.btnActivate:GetAnchor(1)
        AssertEqual(actRelTo, tab.mapMarkerSearchRow, "Action buttons anchored below last visible MAP MARKERS row")

        -- Stop testing prepared quest
        repo:SetActiveQuest(nil)

        -- 3. Offered quest: MAP MARKERS hidden, MISSION DETAILS shows recommendation
        local offeredA = repo:ImportQuestFromCode(codeA, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_279_a",
        })
        tab:SelectQuest(offeredA.id)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "MISSION DETAILS shown on offered quest with recommendHideMapAreas=true")
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("DETAIL_MAP_MARKERS_NOT_RECOMMENDED"), 1, true) ~= nil, "Offered quest shows not recommended line in MISSION DETAILS")
        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), true, "MAP MARKERS hidden on offered quest")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), true, "Search row hidden on offered quest")

        -- 4. Accepted (received) Quest A: MISSION DETAILS shown, Search row visible (Off by default), Location/Discovery hidden, Show on Map enabled
        repo:AcceptOfferedQuest(offeredA.id)
        tab:SelectQuest(offeredA.id)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "MISSION DETAILS shown on received Quest A")
        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), false, "MAP MARKERS shown on received Quest A")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), false, "Search Areas row visible on received Quest A")
        AssertEqual(tab.mapMarkerLocationRow:IsHidden(), true, "Location row hidden on Quest A (no captured location)")
        AssertEqual(tab.mapMarkerDiscoveryRow:IsHidden(), true, "Discovery row hidden on Quest A (no discovery points)")
        AssertEqual(ZO_CheckButton_IsChecked(tab.mapMarkerSearchRow._chk), false, "Search Areas checkbox off by default")
        AssertEqual(tab.mapMarkerSearchRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_OFF"), "Search Areas status label is Off by default")
        AssertEqual(tab.showOnMapKeybindButton:IsHidden(), false, "Show on Map visible even with all toggles off")
        AssertEqual(tab.showOnMapDescriptor.enabled(), true, "Show on Map enabled even with all toggles off")

        -- 5. Received Quest B (recommendHideMapAreas=false, stealthMode=disabled, WITH captured location)
        local recB = repo:ImportQuestFromCode(codeB, "@Master")
        tab:SelectQuest(recB.id)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), true, "MISSION DETAILS block completely hidden when recommendHideMapAreas=false and stealthMode=disabled")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), false, "Search Areas row visible on Quest B")
        AssertEqual(tab.mapMarkerLocationRow:IsHidden(), false, "Location row visible when target has captured location")
        AssertEqual(ZO_CheckButton_IsChecked(tab.mapMarkerLocationRow._chk), false, "Location checkbox off by default")
        AssertEqual(tab.mapMarkerLocationRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_OFF"), "Location status label is Off by default")

        -- Toggle showSearchAreas -> persists on recB, refreshes WorldMapArea pins, leaves showLocationAreas off
        local origRefreshPins = RPQuest.WorldMapArea.RefreshPins
        local refreshCount = 0
        RPQuest.WorldMapArea.RefreshPins = function()
            refreshCount = refreshCount + 1
        end

        ZO_CheckButton_OnClicked(tab.mapMarkerSearchRow._chk)
        AssertEqual(recB.showSearchAreas, true, "showSearchAreas persisted on Quest B")
        AssertEqual(recB.showLocationAreas, nil, "showLocationAreas remains off when showSearchAreas toggled")
        AssertEqual(tab.mapMarkerSearchRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_SHOW"), "Search Areas status label updated to Show")
        AssertEqual(refreshCount >= 1, true, "WorldMapArea:RefreshPins called immediately on showSearchAreas toggle")
        AssertEqual(offeredA.showSearchAreas, nil, "Per-quest toggle on Quest B does not affect Quest A")

        -- Toggle showLocationAreas -> persists on recB, refreshes WorldMapArea pins
        local prevCount = refreshCount
        ZO_CheckButton_OnClicked(tab.mapMarkerLocationRow._chk)
        AssertEqual(recB.showLocationAreas, true, "showLocationAreas persisted on Quest B")
        AssertEqual(tab.mapMarkerLocationRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_SHOW"), "Location status label updated to Show")
        AssertEqual(refreshCount > prevCount, true, "WorldMapArea:RefreshPins called immediately on showLocationAreas toggle")

        -- Reload from SavedVars -> toggles remain persisted per quest
        repo:Initialize(savedVars)
        local reloadedB = repo:GetQuestById(recB.id)
        AssertEqual(reloadedB.showSearchAreas, true, "showSearchAreas survives SavedVars reload")
        AssertEqual(reloadedB.showLocationAreas, true, "showLocationAreas survives SavedVars reload")

        RPQuest.WorldMapArea.RefreshPins = origRefreshPins
    end)

    RunTest("JournalEditorPane: Target dropdown, per-target areaSize, 3-state elimination messages, and Options recommendHideMapAreas", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenCreateEditor()

        local tab = RPQuest.JournalTab
        local draft = RPQuest.QuestRepository:GetDraft()

        -- 1. Options accordion: chkHideMapArea defaults to true on new draft and toggles recommendHideMapAreas
        AssertEqual(ZO_CheckButton_IsChecked(tab.chkHideMapArea), true, "chkHideMapArea checked by default on new draft")
        tab.chkHideMapArea:FireHandler("OnClicked")
        AssertEqual(draft.recommendHideMapAreas, false, "chkHideMapArea unchecks recommendHideMapAreas")
        tab.chkHideMapArea:FireHandler("OnClicked")
        AssertEqual(draft.recommendHideMapAreas, true, "chkHideMapArea re-checks recommendHideMapAreas")

        -- 2. Empty state: target dropdown and delete icons disabled
        AssertEqual(tab.targetComboBox:IsEnabled(), false, "targetComboBox disabled when no targets")
        AssertEqual(tab.btnRemoveTarget:IsEnabled(), false, "btnRemoveTarget disabled when no targets")
        AssertEqual(tab.btnClearTargets:IsEnabled(), false, "btnClearTargets disabled when no targets")
        AssertEqual(tab.areaSizeComboBox:IsEnabled(), false, "areaSizeComboBox disabled when no targets")
        AssertEqual(tab.targetCustomEdit._disabled, true, "targetCustomEdit disabled when no targets")

        -- 3. Capture two targets; dropdown lists both without city name
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit Alpha", mapId = 32, zoneId = 381, mapName = "Daggerfall", targetX = 0.4, targetY = 0.4,
        })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit Beta", mapId = 32, zoneId = 381, mapName = "Daggerfall", targetX = 0.6, targetY = 0.6,
        })
        tab:RefreshEditorPane()
        AssertEqual(tab.targetComboBox:GetNumItems(), 2, "targetComboBox lists both captured targets")
        AssertEqual(tab.targetComboBox:GetItems()[1].name, "Bandit Alpha", "Target dropdown item omits city name")
        AssertEqual(tab.btnRemoveTarget:IsEnabled(), true, "btnRemoveTarget enabled when targets exist")
        AssertEqual(tab.btnClearTargets:IsEnabled(), true, "btnClearTargets enabled when targets exist")

        -- 4. Selecting target 1 and changing areaSizeComboBox updates only target 1 (5 tiers)
        AssertEqual(tab.areaSizeComboBox:GetNumItems(), 5, "areaSizeComboBox has 5 tiers (Tiny..Huge)")
        AssertEqual(tab.targetLocRadComboBox:GetNumItems(), 5, "targetLocRadComboBox has 5 tiers (Tiny..Huge)")
        tab.targetComboBox:SelectItemByIndex(1)
        AssertEqual(tab.selectedTargetIndex, 1, "Selecting target 1 updates selectedTargetIndex")
        tab.areaSizeComboBox:SelectItemByIndex(1) -- TINY
        AssertEqual(draft.targets[1].areaRadius, RPQuest.Constants.AREA_RADIUS.TINY, "Target 1 areaRadius updated to TINY")
        tab.areaSizeComboBox:SelectItemByIndex(5) -- HUGE
        AssertEqual(draft.targets[1].areaRadius, RPQuest.Constants.AREA_RADIUS.HUGE, "Target 1 areaRadius updated to HUGE")
        tab.areaSizeComboBox:SelectItemByIndex(2) -- SMALL
        AssertEqual(draft.targets[1].areaRadius, RPQuest.Constants.AREA_RADIUS.SMALL, "Target 1 areaRadius updated to SMALL")
        AssertEqual(draft.targets[2].areaRadius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Target 2 areaRadius remains MEDIUM")

        -- 5. 3-state elimination messages: without required location, only 'elimination' is enabled
        local msgItems = tab.targetMsgComboBox:GetItems()
        AssertEqual(#msgItems, 3, "targetMsgComboBox has 3 message states")
        AssertEqual(msgItems[1].enabled, true, "elimination state enabled when locationRequired=false")
        AssertEqual(msgItems[2].enabled, false, "in_location state disabled when locationRequired=false")
        AssertEqual(msgItems[3].enabled, false, "outside_location state disabled when locationRequired=false")
        AssertEqual(tab.targetCustomEdit._disabled, false, "targetCustomEdit enabled for elimination message")
        tab.targetCustomEdit:SetText("General kill msg")
        tab.targetCustomEdit:FireHandler("OnTextChanged")
        AssertEqual(draft.targets[1].customMessage, "General kill msg", "Editbox writes to customMessage")

        -- 6. Capture location & set Required -> 'in_location' and 'outside_location' enabled, 'elimination' disabled
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1500)
        tab:RefreshEditorPane()
        tab.chkTargetLocRequired:FireHandler("OnClicked")
        AssertEqual(draft.targets[1].locationRequired, true, "chkTargetLocRequired sets locationRequired=true")
        msgItems = tab.targetMsgComboBox:GetItems()
        AssertEqual(msgItems[1].enabled, false, "elimination state disabled when locationRequired=true")
        AssertEqual(msgItems[2].enabled, true, "in_location state enabled when locationRequired=true")
        AssertEqual(msgItems[3].enabled, true, "outside_location state enabled when locationRequired=true")
        AssertEqual(tab.selectedTargetMsgState, "in_location", "Auto-switches to in_location when locationRequired=true")
        tab.targetCustomEdit:SetText("In location msg")
        tab.targetCustomEdit:FireHandler("OnTextChanged")
        AssertEqual(draft.targets[1].customMessageInLocation, "In location msg", "Editbox writes to customMessageInLocation")

        tab.targetMsgComboBox:SelectItemByIndex(3) -- outside_location
        AssertEqual(tab.selectedTargetMsgState, "outside_location", "Switched to outside_location state")
        tab.targetCustomEdit:SetText("Outside location msg")
        tab.targetCustomEdit:FireHandler("OnTextChanged")
        AssertEqual(draft.targets[1].customMessageOutsideLocation, "Outside location msg", "Editbox writes to customMessageOutsideLocation")

        -- 7. Delete selected target via btnRemoveTarget, then delete all via btnClearTargets
        tab.btnRemoveTarget:GetHandler("OnClicked")()
        AssertEqual(#draft.targets, 1, "btnRemoveTarget deletes only selected target")
        AssertEqual(draft.targets[1].name, "Bandit Beta", "Remaining target is Bandit Beta")
        tab.btnClearTargets:GetHandler("OnClicked")()
        AssertEqual(#draft.targets, 0, "btnClearTargets deletes all targets")
    end)

    RunTest("Editor and detail UI controls have non-clipping widths and non-overlapping layout", function()
        local tab = RPQuest.JournalTab
        tab:OpenCreateEditor()

        local lastW = tab.lblLastNpc:GetWidth()
        local selW = tab.lblSelectedNpc:GetWidth()
        AssertTrue(lastW >= 500 and lastW <= 510, "lblLastNpc has full available width")
        AssertTrue(selW >= 500 and selW <= 510, "lblSelectedNpc has full available width")

        local _, _, _, _, _, lastY = tab.lblLastNpc:GetAnchor(1)
        local _, _, _, _, _, selY = tab.lblSelectedNpc:GetAnchor(1)
        AssertTrue(selY >= lastY + 22, "lblSelectedNpc is placed on a separate row below lblLastNpc")

        local dialogueSec = tab.editorSectionsByKey and tab.editorSectionsByKey["dialogue"]
        AssertTrue(dialogueSec ~= nil and dialogueSec.bodyHeight >= 264, "dialogue section bodyHeight accommodates separate NPC rows")

        AssertEqual(tab.stealthDropdown:GetWidth(), 510, "stealthDropdown widened to 510px")
        AssertEqual(tab.mapMarkerSearchRow:GetWidth(), 495, "mapMarkerSearchRow has 495px width")
        AssertEqual(tab.mapMarkerLocationRow:GetWidth(), 495, "mapMarkerLocationRow has 495px width")
        AssertEqual(tab.mapMarkerDiscoveryRow:GetWidth(), 495, "mapMarkerDiscoveryRow has 495px width")

        local discRow = {
            tab.btnCaptureDiscovery,
            tab.discoveryDropdown,
            tab.btnRemoveDiscovery,
            tab.btnClearDiscoveries,
        }
        AssertEqual(tab.btnDiscPrev, nil, "Legacy btnDiscPrev removed")
        AssertEqual(tab.btnDiscNext, nil, "Legacy btnDiscNext removed")
        AssertEqual(tab.lblDiscIndex, nil, "Legacy lblDiscIndex removed")
        AssertEqual(tab.btnDiscRemove, nil, "Legacy btnDiscRemove removed")
        AssertEqual(tab.lblCapturedDiscoveries, nil, "Redundant lblCapturedDiscoveries removed")
        AssertEqual(tab.btnCaptureDiscovery:GetWidth(), 28, "btnCaptureDiscovery is 28x28 icon")
        AssertEqual(tab.btnRemoveDiscovery:GetWidth(), 28, "btnRemoveDiscovery is 28x28 icon")
        AssertEqual(tab.btnClearDiscoveries:GetWidth(), 28, "btnClearDiscoveries is 28x28 icon")
        AssertTrue(tab.discoveryDropdown:GetWidth() >= 400, "discoveryDropdown widened to ~404px")
        local discSec = tab.editorSectionsByKey and tab.editorSectionsByKey["discovery"]
        AssertTrue(discSec ~= nil and discSec.bodyHeight >= 156, "discovery section bodyHeight accommodates 2-line discoveryMsgEdit")
        local prevRight = -1
        for i, ctrl in ipairs(discRow) do
            local _, _, _, _, x = ctrl:GetAnchor(1)
            local w = ctrl:GetWidth()
            AssertTrue(x > prevRight, string.format("Discovery row control %d does not overlap previous control", i))
            prevRight = x + w
            AssertTrue(prevRight <= 510, string.format("Discovery row control %d fits within 510px", i))
        end
    end)

    RunTest("JournalEditorPane: Mission Settings accordion order, dividers, spacing, and section badge", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenCreateEditor()

        local tab = RPQuest.JournalTab
        local expectedOrder = { "header", "options", "target", "discovery", "dialogue" }
        AssertEqual(#tab.editorSections, #expectedOrder, "Editor has 5 accordion sections")
        for i, expectedKey in ipairs(expectedOrder) do
            AssertEqual(tab.editorSections[i].key, expectedKey, string.format("Accordion section %d is %s", i, expectedKey))
        end

        AssertEqual(RPQuest.Locale:Get("LABEL_OPTIONS_SECTION"), "Mission Settings", "LABEL_OPTIONS_SECTION reads Mission Settings")

        local optionsSec = tab.editorSectionsByKey["options"]
        AssertTrue(optionsSec ~= nil and optionsSec.bodyHeight >= 186, "options section bodyHeight accommodates dividers and spacing")
        AssertTrue(tab.optionsDivider1 ~= nil, "optionsDivider1 created")
        AssertTrue(tab.optionsDivider2 ~= nil, "optionsDivider2 created")

        local _, _, _, _, _, compY = tab.completionBg:GetAnchor(1)
        local compBottom = compY + tab.completionBg:GetHeight()
        local _, _, _, _, _, div1Y = tab.optionsDivider1:GetAnchor(1)
        local _, _, _, _, _, stealthLblY = tab.lblStealthMode:GetAnchor(1)
        local _, _, _, _, _, stealthY = tab.stealthDropdown:GetAnchor(1)
        local stealthBottom = stealthY + tab.stealthDropdown:GetHeight()
        local _, _, _, _, _, div2Y = tab.optionsDivider2:GetAnchor(1)
        local _, _, _, _, _, chkHideY = tab.chkHideMapArea:GetAnchor(1)

        AssertTrue(div1Y > compBottom, "optionsDivider1 sits below completionBg without overlap")
        AssertTrue(stealthLblY > div1Y + tab.optionsDivider1:GetHeight(), "lblStealthMode sits below optionsDivider1")
        AssertTrue(div2Y > stealthBottom, "optionsDivider2 sits below stealthDropdown without overlap")
        AssertTrue(chkHideY > div2Y + tab.optionsDivider2:GetHeight(), "chkHideMapArea sits below optionsDivider2")
        AssertTrue(chkHideY + 24 <= optionsSec.bodyHeight, "chkHideMapArea fits within optionsSec.bodyHeight")

        local function HasBadge()
            return optionsSec.headerBtn:GetText():find("%[%*%]") ~= nil
        end

        AssertEqual(HasBadge(), false, "Default Mission Settings draft has no [*] badge")

        RPQuest.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = false })
        tab:RefreshEditorPane()
        AssertEqual(HasBadge(), true, "Mission Settings shows [*] badge when recommendHideMapAreas is false")

        RPQuest.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = true, stealthMode = "optional" })
        tab:RefreshEditorPane()
        AssertEqual(HasBadge(), true, "Mission Settings shows [*] badge when stealthMode is non-disabled")

        RPQuest.QuestRepository:UpdateDraftFields({ stealthMode = "disabled", completionMessage = "Well done!" })
        tab:RefreshEditorPane()
        AssertEqual(HasBadge(), true, "Mission Settings shows [*] badge when completionMessage is non-empty")

        RPQuest.QuestRepository:UpdateDraftFields({ completionMessage = "" })
        tab:RefreshEditorPane()
        AssertEqual(HasBadge(), false, "Mission Settings clears [*] badge when restored to defaults")
    end)

    RunTest("Issue #293: Detail header padding, MISSION DETAILS vs TASKS, stealth & map markers in Master view", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local tab = RPQuest.JournalTab
        tab:Initialize()

        -- 1. Header vertical spacing/padding & multi-line status scroll height
        local _, _, _, _, _, statusY = tab.detailStatus:GetAnchor(1)
        local _, _, _, _, _, fromY = tab.detailFrom:GetAnchor(1)
        local _, _, _, _, _, toY = tab.detailTo:GetAnchor(1)
        local _, _, _, _, _, locY = tab.detailLocation:GetAnchor(1)
        local _, _, _, _, _, descY = tab.detailDescBody:GetAnchor(1)
        AssertTrue(statusY >= 8, "detailStatus has >= 8px top padding")
        AssertTrue(fromY >= 6, "detailFrom has >= 6px top padding")
        AssertTrue(toY >= 6, "detailTo has >= 6px top padding")
        AssertTrue(locY >= 10, "detailLocation has >= 10px top padding")
        AssertTrue(descY >= 12, "detailDescBody has >= 12px top padding")

        local prevScrollChild = tab.detailScrollChild
        local scrollH = 0
        tab.detailScrollChild = {
            SetDimensions = function(_, _, h) scrollH = h end,
            GetHeight = function() return scrollH end,
        }

        local qSingle = repo:BuildQuestRecord(101, "Single Status", "Desc", {
            { name = "Bandit", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "disabled", recommendHideMapAreas = true }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        table.insert(repo.savedVars.quests, qSingle)
        repo._questById[101] = qSingle
        tab:SelectQuest(101)
        tab:Refresh()
        local singleScrollH = tab.detailScrollChild:GetHeight()

        local qMulti = repo:BuildQuestRecord(102, "Multi Status", "Desc", {
            { name = "Bandit", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "disabled", recommendHideMapAreas = false }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        qMulti.needsMigration = true
        qMulti.migrationReason = "Line 2 reason\nLine 3 reason"
        table.insert(repo.savedVars.quests, qMulti)
        repo._questById[102] = qMulti
        tab:SelectQuest(102)
        tab:Refresh()
        local multiScrollH = tab.detailScrollChild:GetHeight()
        AssertTrue(multiScrollH > singleScrollH, "detailScrollChild height expands for multi-line status")
        tab.detailScrollChild = prevScrollChild

        -- 2. Master MISSION DETAILS vs Player TASKS + Stealth & Map marker lines
        tab:SelectQuest(101)
        tab:Refresh()
        AssertEqual(tab.detailObjHeader:GetText(), RPQuest.Locale:Get("LABEL_MISSION_DETAILS_HEADER"), "Master quest uses MISSION DETAILS header")
        local masterText101 = tab.detailObjText:GetText()
        AssertTrue(masterText101:find(RPQuest.Locale:Get("MASTER_STEALTH_DISABLED"), 1, true) ~= nil, "Master draft with disabled stealth shows Stealth: Disabled")
        AssertTrue(masterText101:find("Recommend hiding", 1, true) ~= nil, "Master quest with recommendHideMapAreas=true shows Recommend hiding")
        AssertEqual(tab.detailMissionHeader:IsHidden(), true, "Player MISSION DETAILS header hidden on Master quest")

        -- Draft with Optional & Required stealth + recommendHideMapAreas=false
        local qOptDraft = repo:BuildQuestRecord(103, "Opt Draft", "Desc", {
            { name = "Guard", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "optional", recommendHideMapAreas = false }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        table.insert(repo.savedVars.quests, qOptDraft)
        repo._questById[103] = qOptDraft
        tab:SelectQuest(103)
        tab:Refresh()
        local optDraftText = tab.detailObjText:GetText()
        AssertTrue(optDraftText:find(RPQuest.Locale:Get("MASTER_STEALTH_OPTIONAL"), 1, true) ~= nil, "Master draft with optional stealth shows configured Optional wording")
        AssertTrue(optDraftText:find("Show recommended", 1, true) ~= nil, "Master quest with recommendHideMapAreas=false shows Show recommended")

        local qReqDraft = repo:BuildQuestRecord(104, "Req Draft", "Desc", {
            { name = "Guard", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "required", recommendHideMapAreas = true }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        table.insert(repo.savedVars.quests, qReqDraft)
        repo._questById[104] = qReqDraft
        tab:SelectQuest(104)
        tab:Refresh()
        AssertTrue(tab.detailObjText:GetText():find(RPQuest.Locale:Get("MASTER_STEALTH_REQUIRED"), 1, true) ~= nil, "Master draft with required stealth shows configured Required wording")

        -- 3. Testing a Master quest switches to player view (MISSION DETAILS + TASKS) without Master-only summary lines
        repo:SetActiveQuest(103)
        qOptDraft.wasDetected = true
        tab:SelectQuest(103)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "Testing Master quest shows MISSION DETAILS block")
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_OPTIONAL_DETECTED"), 1, true) ~= nil, "Testing Master quest preserves live detection status in MISSION DETAILS")
        AssertEqual(tab.detailObjHeader:GetText(), RPQuest.Locale:Get("LABEL_OBJECTIVE_HEADER"), "Testing Master quest uses TASKS header")
        repo:SetActiveQuest(nil)

        -- Sent + Failed Master quest preserves reported detection status
        qReqDraft.lifecycle = RPQuest.Constants.QUEST_LIFECYCLE.SENT
        qReqDraft.resolution = "failed"
        qReqDraft.lastResult = {
            senderDisplayName = "@Player",
            wasDetected = true,
        }
        tab:SelectQuest(104)
        tab:Refresh()
        AssertTrue(tab.detailObjText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_REQUIRED_FAILED"), 1, true) ~= nil, "Sent+Failed Master quest preserves reported detection status")

        -- 4. Player (received) quest uses TASKS header and shows map markers line inside MISSION DETAILS when recommendHideMapAreas=true
        local qRec = repo:BuildQuestRecord(105, "Received Quest", "Desc", {
            { name = "Guard", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "disabled", recommendHideMapAreas = true }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(repo.savedVars.quests, qRec)
        repo._questById[105] = qRec
        tab:SelectQuest(105)
        tab:Refresh()
        AssertEqual(tab.detailObjHeader:GetText(), RPQuest.Locale:Get("LABEL_OBJECTIVE_HEADER"), "Received quest keeps TASKS header")
        AssertEqual(tab.detailMissionHeader:IsHidden(), false, "Received quest shows MISSION DETAILS block")
        AssertTrue(tab.detailMissionText:GetText():find(RPQuest.Locale:Get("DETAIL_MAP_MARKERS_NOT_RECOMMENDED"), 1, true) ~= nil, "Received quest shows not recommended inside MISSION DETAILS")
        AssertEqual(tab.detailObjText:GetText():find("Recommend hiding", 1, true), nil, "Received quest does not show Master map recommendation line")
    end)

    RunTest("Discovery area dropdown, required message indicator, and Save/Test/Send blocking (#294)", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        local repo = RPQuest.QuestRepository
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab:OpenCreateEditor()

        AssertEqual(RPQuest.JournalWidgets.FormatSelected, nil, "Dead code JournalWidgets.FormatSelected removed")
        AssertEqual(tab.btnDiscRadSmall, nil, "Legacy btnDiscRadSmall removed")
        AssertTrue(tab.discRadComboBox ~= nil, "discRadComboBox exists")
        AssertTrue(tab.lblDiscoveryMsg ~= nil, "lblDiscoveryMsg exists")
        AssertEqual(tab.lblDiscoveryMsg:GetText(), RPQuest.Locale:Get("LABEL_DISCOVERY_MSG"), "Default discovery label shown when 0 points")

        -- 1. Empty state: discovery inputs, dropdown, and icons are disabled (0.45 alpha for icons)
        AssertEqual(tab.discoveryMsgEdit._disabled, true, "discoveryMsgEdit is disabled when 0 discovery points exist")
        AssertEqual(tab.discRadComboBox:IsEnabled(), false, "discRadComboBox is disabled when 0 discovery points exist")
        AssertEqual(tab.discoveryComboBox:IsEnabled(), false, "discoveryComboBox is disabled when 0 discovery points exist")
        AssertEqual(tab.discoveryComboBox:GetSelectedItem(), RPQuest.Locale:Get("DISCOVERY_NOT_CAPTURED"), "discoveryComboBox shows empty placeholder")
        AssertEqual(tab.btnRemoveDiscovery:IsHidden(), false, "btnRemoveDiscovery stays visible when 0 points exist")
        AssertEqual(tab.btnClearDiscoveries:IsHidden(), false, "btnClearDiscoveries stays visible when 0 points exist")
        AssertEqual(tab.btnRemoveDiscovery:GetAlpha(), 0.45, "btnRemoveDiscovery is dimmed (0.45 alpha) when 0 points exist")
        AssertEqual(tab.btnClearDiscoveries:GetAlpha(), 0.45, "btnClearDiscoveries is dimmed (0.45 alpha) when 0 points exist")

        -- 2. Capture discovery point without message -> no DEFAULT_DISCOVERY_MSG, warning state active, controls enabled
        mockState.zoneId = 381
        mockState.worldX = 1000
        mockState.worldZ = 2000
        local _, count = RPQuest.TargetCapture:CaptureDiscoveryPoint("")
        AssertEqual(count, 1, "Discovery point captured without auto-fill")
        tab.selectedDiscoveryIndex = 1
        tab:RefreshEditorPane()

        AssertEqual(tab.discoveryMsgEdit._disabled, false, "discoveryMsgEdit is enabled once >= 1 discovery point exists")
        AssertEqual(tab.discRadComboBox:IsEnabled(), true, "discRadComboBox is enabled once >= 1 discovery point exists")
        AssertEqual(tab.discoveryComboBox:IsEnabled(), true, "discoveryComboBox is enabled once >= 1 discovery point exists")
        AssertEqual(tab.btnRemoveDiscovery:GetAlpha(), 1, "btnRemoveDiscovery is full alpha when >= 1 point exists")
        AssertEqual(tab.btnClearDiscoveries:GetAlpha(), 1, "btnClearDiscoveries is full alpha when >= 1 point exists")

        local draft = repo:GetDraft()
        AssertEqual(draft.discoveries[1].message, "", "Discovery point message stays empty without generic fallback")
        AssertEqual(tab.discoveryMsgEdit._hasWarning, true, "discoveryMsgEdit marks warning state when message is empty")
        AssertEqual(tab.lblDiscoveryMsg:GetText(), RPQuest.Locale:Get("LABEL_DISCOVERY_MSG_MISSING"), "Label highlights missing required message")
        local discHeaderText = tab.editorSectionsByKey.discovery.headerBtn:GetText()
        AssertTrue(discHeaderText:find("[1/10 !]", 1, true) ~= nil, "Discovery accordion badge shows [1/10 !] alert")

        -- Changing discRadComboBox with selected point updates point radius (5 tiers)
        AssertEqual(tab.discRadComboBox:GetNumItems(), 5, "discRadComboBox has 5 tiers (Tiny..Huge)")
        tab.discRadComboBox:SelectItemByIndex(1)
        AssertEqual(draft.discoveries[1].radius, RPQuest.Constants.DISCOVERY_RADIUS.TINY, "discRadComboBox updates selected discovery point radius to Tiny")
        tab.discRadComboBox:SelectItemByIndex(5)
        AssertEqual(draft.discoveries[1].radius, RPQuest.Constants.DISCOVERY_RADIUS.HUGE, "discRadComboBox updates selected discovery point radius to Huge")
        tab.discRadComboBox:SelectItemByIndex(2)
        AssertEqual(draft.discoveries[1].radius, RPQuest.Constants.DISCOVERY_RADIUS.SMALL, "discRadComboBox updates selected discovery point radius to Small")
        tab.discRadComboBox:SelectItemByIndex(4)
        AssertEqual(draft.discoveries[1].radius, RPQuest.Constants.DISCOVERY_RADIUS.LARGE, "discRadComboBox updates selected discovery point radius to Large")
        tab.discRadComboBox:SelectItemByIndex(3)
        AssertEqual(draft.discoveries[1].radius, RPQuest.Constants.DISCOVERY_RADIUS.MEDIUM, "discRadComboBox updates selected discovery point radius to Medium")

        -- 3. Save Draft, Test Quest, and Send Quest are blocked while discovery message is empty/whitespace
        tab.discoveryMsgEdit:SetText("   ")
        tab.discoveryMsgEdit:FireHandler("OnTextChanged")
        local saved, saveErr = repo:SaveDraft("Discovery Quest", "Desc")
        AssertEqual(saved, nil, "SaveDraft blocked when discovery message is whitespace-only")
        AssertEqual(saveErr, RPQuest.Locale:Get("ERR_DISCOVERY_MISSING_MSG"), "SaveDraft returns ERR_DISCOVERY_MISSING_MSG")

        -- Save via OnSaveDraftClicked also alerts and does not clear inputs
        mockState.csaMessages = {}
        tab:OnSaveDraftClicked()
        AssertEqual(repo:GetDraft().discoveries[1] ~= nil, true, "OnSaveDraftClicked keeps draft open when blocked")

        -- Test Quest & Send Quest blocked on a prepared quest with empty discovery message
        local qid = draft.editingQuestId
        local prep = repo:GetQuestById(qid)
        prep.discoveries = { { zoneId = 381, worldX = 1000, worldZ = 2000, radius = 1500, message = "  ", discovered = false } }
        local activated, testErrKey = repo:SetActiveQuest(qid)
        AssertEqual(activated, false, "SetActiveQuest blocked when discovery message is empty")
        AssertEqual(testErrKey, "ERR_DISCOVERY_MISSING_MSG", "SetActiveQuest returns ERR_DISCOVERY_MISSING_MSG")
        local resetOk, resetErrKey = repo:ResetQuest(qid)
        AssertEqual(resetOk, false, "ResetQuest(activate) blocked when discovery message is empty")
        AssertEqual(resetErrKey, "ERR_DISCOVERY_MISSING_MSG", "ResetQuest returns ERR_DISCOVERY_MISSING_MSG")

        RPQuest.MailTransport._isSending = false
        local sentOk, sendErrKey = RPQuest.MailTransport:SendQuestToRecipients(prep, "@GuildMate", "")
        AssertEqual(sentOk, false, "SendQuestToRecipients blocked when discovery message is empty")
        AssertEqual(sendErrKey, "ERR_DISCOVERY_MISSING_MSG", "SendQuestToRecipients returns ERR_DISCOVERY_MISSING_MSG")

        -- 4. Fill in valid discovery message -> clears warning and allows Save, Test, and Send
        tab.discoveryMsgEdit:SetText("You spot fresh footprints in the mud.")
        tab.discoveryMsgEdit:FireHandler("OnTextChanged")
        AssertEqual(tab.discoveryMsgEdit._hasWarning, false, "discoveryMsgEdit clears warning when message is filled")
        AssertEqual(tab.lblDiscoveryMsg:GetText(), RPQuest.Locale:Get("LABEL_DISCOVERY_MSG_REQUIRED"), "Label shows required-ok state")
        local discHeaderOk = tab.editorSectionsByKey.discovery.headerBtn:GetText()
        AssertTrue(discHeaderOk:find("[1/10]", 1, true) ~= nil and discHeaderOk:find("!", 1, true) == nil, "Discovery accordion badge clears alert")

        tab.recipientEdit:SetText("@GuildMate")
        tab.recipientEdit:FireHandler("OnTextChanged")
        local savedOk, savedOkErr = repo:SaveDraft("Discovery Quest", "Desc")
        AssertTrue(savedOk ~= nil and savedOkErr == nil, "SaveDraft succeeds with valid discovery message")
        local testOk = repo:ResetQuest(savedOk.id)
        AssertEqual(testOk, true, "ResetQuest/Test Quest succeeds with valid discovery message")
        repo:SetActiveQuest(nil)
    end)

    RunTest("Discovery dropdown formatting, selection, 1-click remove and clear (#296)", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        local repo = RPQuest.QuestRepository
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab:OpenCreateEditor()

        mockState.zoneId = 381
        mockState.worldX = 1000
        mockState.worldZ = 2000
        RPQuest.TargetCapture:CaptureDiscoveryPoint("Welcome to RPQuest! This is a very long discovery message.")
        mockState.worldX = 1500
        RPQuest.TargetCapture:CaptureDiscoveryPoint("Short clue")
        tab:RefreshEditorPane()

        local items = tab.discoveryComboBox:GetItems()
        AssertEqual(#items, 2, "discoveryComboBox lists both discovery points")
        AssertTrue(items[1].name:find("^#1 %- Welcome to RPQuest!") ~= nil, "First item uses #<index> - <truncated> format")
        AssertTrue(items[1].name:find("%.%.%.$") ~= nil, "Long discovery message is truncated with ellipsis")
        AssertEqual(items[2].name, "#2 - Short clue", "Second item shows full short message")

        -- Select #1 via dropdown
        tab.discoveryComboBox:SelectItemByIndex(1)
        AssertEqual(tab.selectedDiscoveryIndex, 1, "Selecting dropdown item 1 updates selectedDiscoveryIndex")
        AssertEqual(tab.discoveryMsgEdit:GetText(), "Welcome to RPQuest! This is a very long discovery message.", "Selecting #1 syncs discoveryMsgEdit")

        -- 1-click remove selected (#1)
        tab.btnRemoveDiscovery:FireHandler("OnClicked")
        local draft = repo:GetDraft()
        AssertEqual(#(draft.discoveries or {}), 1, "btnRemoveDiscovery removes selected point on 1 click")
        AssertEqual(draft.discoveries[1].message, "Short clue", "Remaining discovery point is the second one")

        -- 1-click clear all
        tab.btnClearDiscoveries:FireHandler("OnClicked")
        AssertEqual(#(repo:GetDraft().discoveries or {}), 0, "btnClearDiscoveries clears all points on 1 click")
        AssertEqual(tab.discoveryMsgEdit._disabled, true, "discoveryMsgEdit returns to disabled empty state after clear")
        AssertEqual(tab.discRadComboBox:IsEnabled(), false, "discRadComboBox returns to disabled empty state after clear")
        AssertEqual(tab.btnRemoveDiscovery:GetAlpha(), 0.45, "btnRemoveDiscovery returns to 0.45 alpha after clear")
        AssertEqual(tab.btnClearDiscoveries:GetAlpha(), 0.45, "btnClearDiscoveries returns to 0.45 alpha after clear")
    end)

    RunTest("Issue #298 & #307: JournalDetailPane MAP MARKERS Discovery row visibility, state, and persistence", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local savedVars = RPQuest.QuestRepository:GetDefaults()
        local repo = RPQuest.QuestRepository
        repo:Initialize(savedVars)
        local tab = RPQuest.JournalTab
        tab:Initialize()

        -- 1. Received quest WITHOUT discovery points -> Discovery row hidden, Search Areas row visible
        repo:ResetDraft()
        repo:SetDraftCapturedTarget({
            targetName = "Bandit",
            mapId = 45,
            zoneId = 104,
            targetX = 0.4,
            targetY = 0.4,
            areaRadius = 0.07,
        })
        local prepNoDisc = repo:SaveDraft("No Discovery", "Fight only.")
        local codeNoDisc = RPQuest.ShareCodec:EncodeQuest(prepNoDisc)
        local recNoDisc = repo:ImportQuestFromCode(codeNoDisc)
        tab:SelectQuest(recNoDisc.id)
        tab:Refresh()

        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), false, "MAP MARKERS header visible when Search Areas applies")
        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), false, "Search Areas row visible")
        AssertEqual(tab.mapMarkerDiscoveryRow:IsHidden(), true, "Discovery row hidden when quest has no discoveries")

        -- 2. Received quest WITH discovery points -> Discovery row visible, off by default, toggles & persists
        repo:ResetDraft()
        repo:UpdateDraftFields({ mapId = 45, zoneId = 104 })
        repo:AddDraftDiscoveryPoint({
            zoneId = 104,
            worldX = 25000,
            worldY = 0,
            worldZ = 25000,
            mapId = 45,
            x = 0.25,
            y = 0.25,
            radius = 1500,
            message = "Hidden note.",
        })
        local prepWithDisc = repo:SaveDraft("With Discovery", "Explore.")
        local codeWithDisc = RPQuest.ShareCodec:EncodeQuest(prepWithDisc)
        local recWithDisc = repo:ImportQuestFromCode(codeWithDisc)
        tab:SelectQuest(recWithDisc.id)
        tab:Refresh()

        AssertEqual(tab.mapMarkerSearchRow:IsHidden(), true, "Search Areas row hidden when discovery-only quest has no search area")
        AssertEqual(tab.mapMarkerLocationRow:IsHidden(), true, "Location row hidden when discovery-only quest has no target location")
        AssertEqual(tab.mapMarkerDiscoveryRow:IsHidden(), false, "Discovery row visible when quest has discoveries")
        AssertEqual(ZO_CheckButton_IsChecked(tab.mapMarkerDiscoveryRow._chk), false, "Discovery checkbox off by default")
        AssertEqual(tab.mapMarkerDiscoveryRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_OFF"), "Discovery status label is Off by default")

        local origRefreshPins = RPQuest.WorldMapArea.RefreshPins
        local refreshCount = 0
        RPQuest.WorldMapArea.RefreshPins = function()
            refreshCount = refreshCount + 1
        end

        ZO_CheckButton_OnClicked(tab.mapMarkerDiscoveryRow._chk)
        AssertEqual(recWithDisc.showDiscoveryAreas, true, "showDiscoveryAreas persisted on quest")
        AssertEqual(tab.mapMarkerDiscoveryRow._chk._labelText, RPQuest.Locale:Get("MAP_MARKER_STATE_SHOW"), "Discovery status label updated to Show")
        AssertEqual(refreshCount >= 1, true, "WorldMapArea:RefreshPins called on discovery toggle")

        repo:Initialize(savedVars)
        local reloaded = repo:GetQuestById(recWithDisc.id)
        AssertEqual(reloaded.showDiscoveryAreas, true, "showDiscoveryAreas survives SavedVars reload")

        RPQuest.WorldMapArea.RefreshPins = origRefreshPins
    end)

    RunTest("Issue #307: multiline textarea scrollbars, mouse wheel, and empty MAP MARKERS hiding", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        local repo = RPQuest.QuestRepository
        local tab = RPQuest.JournalTab
        tab:Initialize()
        tab:OpenCreateEditor()

        -- Multiline fields have vertical scrollbars hidden when no overflow and shown on overflow
        for _, edit in ipairs({ tab.descEdit, tab.discoveryMsgEdit, tab.dlgResponseEdit }) do
            AssertTrue(edit._scrollbar ~= nil, "Multiline edit has vertical scrollbar")
            AssertEqual(edit._scrollbar:IsHidden(), true, "Scrollbar hidden when content does not overflow")
            edit._scrollExtents = 3
            edit:FireHandler("OnTextChanged")
            AssertEqual(edit._scrollbar:IsHidden(), false, "Scrollbar shown when content overflows")
            edit:FireHandler("OnMouseWheel", -1, 0, 0, false)
            AssertEqual(edit:GetTopLineIndex(), 2, "Mouse wheel down scrolls multiline editbox")
            edit._scrollExtents = 0
            edit:FireHandler("OnTextChanged")
            AssertEqual(edit._scrollbar:IsHidden(), true, "Scrollbar hides again when overflow clears")
        end

        -- Quest with no search area, no location, no discoveries hides MAP MARKERS block completely
        local bareQuest = repo:BuildQuestRecord(307, "Bare", "Desc", {
            { name = "Guard", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "disabled", recommendHideMapAreas = false }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(repo.savedVars.quests, bareQuest)
        repo._questById[307] = bareQuest
        tab:SelectQuest(307)
        tab:Refresh()
        AssertEqual(tab.detailMissionHeader:IsHidden(), true, "MISSION DETAILS hidden when both stealth and map rec are absent")
        AssertEqual(tab.detailMapMarkersHeader:IsHidden(), true, "MAP MARKERS block hidden when no marker rows apply")
    end)

    RunTest("Issue #309: asynchronous questJournal reopen from map preserves RPQuest tab over Rumors fallback", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local tab = RPQuest.JournalTab
        tab:Initialize()

        local qj = QUEST_JOURNAL_KEYBOARD
        local origOnShowing = qj.OnShowing
        local origSelectFragment = qj.tabs.SelectFragment
        local origSceneShow = SCENE_MANAGER.Show
        local origIsShowing = SCENE_MANAGER.IsShowing

        local selectedFragments = {}
        local isJournalShowing = false

        -- Simulate native ZO_QuestJournal_Keyboard:OnShowing() selecting Rumors when mode ~= QUESTS (1)
        -- and overwriting qj.mode = 2 (RUMORS) before RPQuest's ZO_PostHook runs.
        qj.OnShowing = function(self)
            if self.mode == 1 then
                self.tabs:SelectFragment("Quests")
            else
                self.mode = 2
                self.tabs:SelectFragment("Rumors")
            end
        end
        tab.isInitialized = false
        tab.isTabAdded = false
        tab:Initialize()

        qj.tabs.SelectFragment = function(self, name)
            table.insert(selectedFragments, name)
            return origSelectFragment(self, name)
        end

        SCENE_MANAGER.IsShowing = function(_, name)
            if name == "questJournal" then
                return isJournalShowing
            end
            return origIsShowing(SCENE_MANAGER, name)
        end
        -- Simulate async transition from worldMap: questJournal is not showing yet when Show() returns
        SCENE_MANAGER.Show = function(_, name)
            if name == "questJournal" then
                isJournalShowing = false
            else
                return origSceneShow(SCENE_MANAGER, name)
            end
        end

        -- 1. Open RPQuest tab asynchronously (e.g. from worldMap): OnShowing runs later
        tab:OpenTab()
        AssertEqual(#selectedFragments, 0, "SelectFragment deferred during async transition")

        isJournalShowing = true
        qj:OnShowing()
        AssertEqual(qj.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "qj.mode restored to RPQuest tab descriptor after OnShowing")
        AssertEqual(selectedFragments[#selectedFragments], tab.tabCategoryName, "RPQuest tab selected on first try instead of Rumors")

        -- 2. Native Quests and Rumors tabs remain unaffected when opening outside RPQuest
        selectedFragments = {}
        qj:SetMode(1)
        qj:OnShowing()
        AssertEqual(qj.mode, 1, "Native Quests mode preserved")
        AssertEqual(selectedFragments[#selectedFragments], "Quests", "Native Quests fragment selected")

        selectedFragments = {}
        qj:SetMode(2)
        qj:OnShowing()
        AssertEqual(qj.mode, 2, "Native Rumors mode preserved")
        AssertEqual(selectedFragments[#selectedFragments], "Rumors", "Native Rumors fragment selected")

        qj.OnShowing = origOnShowing
        qj.tabs.SelectFragment = origSelectFragment
        SCENE_MANAGER.Show = origSceneShow
        SCENE_MANAGER.IsShowing = origIsShowing
    end)

    RunTest("All 3 radius selectors expose 5 localized tiers across all 7 languages and preserve legacy ShareCodec radii", function()
        local locales = { "en", "es", "de", "fr", "jp", "ru", "zh" }
        local keys = { "BTN_RADIUS_TINY", "BTN_RADIUS_SMALL", "BTN_RADIUS_MEDIUM", "BTN_RADIUS_LARGE", "BTN_RADIUS_HUGE" }
        for _, lang in ipairs(locales) do
            RPQuest.Locale:Initialize(lang)
            for _, key in ipairs(keys) do
                local val = RPQuest.Locale:Get(key)
                AssertTrue(type(val) == "string" and val ~= "" and val ~= key, string.format("Locale %s defines %s", lang, key))
            end
        end
        RPQuest.Locale:Initialize("en")

        local tab = RPQuest.JournalTab
        AssertEqual(tab.areaSizeComboBox:GetNumItems(), 5, "Target Search Area selector has 5 tiers")
        AssertEqual(tab.targetLocRadComboBox:GetNumItems(), 5, "Target Location selector has 5 tiers")
        AssertEqual(tab.discRadComboBox:GetNumItems(), 5, "Discovery Point selector has 5 tiers")

        -- Legacy radii (0.125, 0.195, 1500, 3000) round-trip cleanly through ShareCodec without migration
        local legacyQuest = {
            id = "legacy-radius-test",
            title = "Legacy Radii",
            description = "Desc",
            mapId = 32,
            zoneId = 381,
            mapName = "Daggerfall",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.5,
            areaCenterY = 0.5,
            areaRadius = 0.125,
            targets = {
                { name = "Bandit", requiredCount = 1, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.195, zoneId = 381, worldX = 10000, worldZ = 20000, radius = 3000 },
            },
            discoveries = {
                { zoneId = 381, worldX = 12000, worldY = 0, worldZ = 22000, mapId = 32, x = 0.4, y = 0.4, radius = 1500, message = "Legacy spot" },
            },
        }
        local encoded = RPQuest.ShareCodec:EncodeQuest(legacyQuest)
        AssertTrue(type(encoded) == "string" and encoded ~= "", "Legacy quest encodes via ShareCodec")
        local decoded = RPQuest.ShareCodec:DecodeQuest(encoded)
        AssertTrue(decoded ~= nil, "Legacy quest decodes via ShareCodec")
        AssertTrue(math.abs(decoded.targets[1].areaRadius - 0.195) < 0.001, "Legacy target areaRadius 0.195 preserved")
        AssertEqual(decoded.targets[1].radius, 3000, "Legacy target location radius 3000 preserved")
        AssertEqual(decoded.discoveries[1].radius, 1500, "Legacy discovery radius 1500 preserved")
    end)

    RunTest("Issue #319: [J] always opens vanilla Quests tab while RPQuest keybind and map-return preserve RPQuest", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(nil)
        local tab = RPQuest.JournalTab
        tab:Initialize()

        local qj = QUEST_JOURNAL_KEYBOARD
        local origOnShowing = qj.OnShowing
        local origOnHiding = qj.OnHiding
        local origSelectFragment = qj.tabs.SelectFragment
        local origSceneShow = SCENE_MANAGER.Show
        local origIsShowing = SCENE_MANAGER.IsShowing

        local selectedFragments = {}
        local isJournalShowing = false

        qj.OnShowing = function(self)
            if self.mode == ZO_QUEST_JOURNAL_MODE.QUESTS then
                self.tabs:SelectFragment("Quests")
            else
                self.mode = ZO_QUEST_JOURNAL_MODE.RUMORS
                self.tabs:SelectFragment("Rumors")
            end
        end
        qj.OnHiding = function(self)
            isJournalShowing = false
        end
        tab.isInitialized = false
        tab.isTabAdded = false
        tab:Initialize()

        qj.tabs.SelectFragment = function(self, name)
            table.insert(selectedFragments, name)
            return origSelectFragment(self, name)
        end

        SCENE_MANAGER.IsShowing = function(_, name)
            if name == "questJournal" then
                return isJournalShowing
            end
            return origIsShowing(SCENE_MANAGER, name)
        end
        SCENE_MANAGER.Show = function(_, name)
            if name == "questJournal" then
                isJournalShowing = true
                qj:OnShowing()
            else
                return origSceneShow(SCENE_MANAGER, name)
            end
        end

        -- 1. Open via RPQuest keybind -> opens RPQuest tab
        selectedFragments = {}
        RPQuest:OnToggleJournalKeybind()
        AssertEqual(qj.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "RPQuest keybind sets RPQuest mode")
        AssertEqual(selectedFragments[#selectedFragments], tab.tabCategoryName, "RPQuest keybind selects RPQuest tab")

        -- 2. Close journal (OnHiding) and press [J] -> opens vanilla Quests tab
        qj:OnHiding()
        AssertEqual(qj.mode, ZO_QUEST_JOURNAL_MODE.QUESTS, "OnHiding resets RPQuest mode to vanilla Quests")
        selectedFragments = {}
        SCENE_MANAGER:Show("questJournal")
        AssertEqual(qj.mode, ZO_QUEST_JOURNAL_MODE.QUESTS, "Pressing [J] keeps vanilla Quests mode")
        AssertEqual(selectedFragments[#selectedFragments], "Quests", "Pressing [J] selects vanilla Quests tab")

        -- 3. Even if qj.mode remained tabDescriptor without OnHiding, [J] still resets to vanilla Quests
        qj:SetMode(RPQuest.Constants.UI.TAB_DESCRIPTOR)
        selectedFragments = {}
        SCENE_MANAGER:Show("questJournal")
        AssertEqual(qj.mode, ZO_QUEST_JOURNAL_MODE.QUESTS, "[J] resets dangling RPQuest mode to vanilla Quests")
        AssertEqual(selectedFragments[#selectedFragments], "Quests", "[J] opens vanilla Quests tab instead of RPQuest")

        -- 4. Async return from Show on Map (OpenTab while questJournal is not yet showing) preserves RPQuest tab
        SCENE_MANAGER.Show = function(_, name)
            if name == "questJournal" then
                isJournalShowing = false
            else
                return origSceneShow(SCENE_MANAGER, name)
            end
        end
        selectedFragments = {}
        isJournalShowing = false
        tab:OpenTab()
        AssertEqual(#selectedFragments, 0, "Async map-return defers SelectFragment until OnShowing")
        isJournalShowing = true
        qj:OnShowing()
        AssertEqual(qj.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "Async map-return preserves RPQuest mode")
        AssertEqual(selectedFragments[#selectedFragments], tab.tabCategoryName, "Async map-return selects RPQuest tab")

        -- 5. Closing after map-return and pressing [J] again opens vanilla Quests
        qj:OnHiding()
        selectedFragments = {}
        isJournalShowing = true
        qj:OnShowing()
        AssertEqual(qj.mode, ZO_QUEST_JOURNAL_MODE.QUESTS, "Subsequent [J] after map-return opens vanilla Quests")
        AssertEqual(selectedFragments[#selectedFragments], "Quests", "Subsequent [J] selects Quests fragment")

        qj.OnShowing = origOnShowing
        qj.OnHiding = origOnHiding
        qj.tabs.SelectFragment = origSelectFragment
        SCENE_MANAGER.Show = origSceneShow
        SCENE_MANAGER.IsShowing = origIsShowing
    end)

end
