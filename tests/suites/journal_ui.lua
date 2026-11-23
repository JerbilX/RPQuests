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
        RPQuest.QuestRepository:UpdateDraftFields({ areaRadius = RPQuest.Constants.AREA_RADIUS.LARGE })
        RPQuest.JournalTab:OnSaveDraftClicked()
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

        -- 1. En creación (sin guardar), capturar objetivo muestra el pin en el mapa y habilita Ver en Mapa en el editor
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), true, "ShowMapEditor hidden before target capture")
        RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), false, "ShowMapEditor visible after target capture")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin rendered immediately during draft preparation")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Draft pin starts with MEDIUM radius")

        -- 2. Cambiar radio en el editor antes de guardar actualiza el pin al instante
        RPQuest.JournalTab.btnRadiusLarge:FireHandler("OnClicked")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed on radius change")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "Draft pin immediately reflects LARGE radius")

        -- Guardar la misión preparada
        RPQuest.JournalTab.titleEdit:SetText("Ritual en Deshaan")
        RPQuest.JournalTab:OnSaveDraftClicked()
        local q = RPQuest.QuestRepository:GetAllQuests()[1]
        AssertEqual(q.areaRadius, RPQuest.Constants.AREA_RADIUS.LARGE, "Saved quest keeps LARGE radius")

        -- 3. Abrir Editar y cambiar radio a SMALL refleja el nuevo tamaño en el mapa al instante (sin guardar todavía)
        RPQuest.JournalTab:OpenEditEditor(q.id)
        RPQuest.JournalTab.btnRadiusSmall:FireHandler("OnClicked")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed when editing quest radius")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "Edited draft pin immediately reflects SMALL radius")

        -- 4. Pulsar Ver en Mapa desde el editor abre el mapa mostrando el pin editado
        RPQuest.JournalTab.btnShowMapEditor:FireHandler("OnClicked")
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

        -- 4. Quest with hideMapArea=true -> still visible when selected in DETAIL mode
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Cultista",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.3,
            targetY = 0.3,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ hideMapArea = true })
        local hiddenAreaQuest = RPQuest.QuestRepository:SaveDraft("Misión Sin Área", "Área oculta.")
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible even when hideMapArea is true")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true even when hideMapArea is true")

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

        -- 6. Editor mode -> hidden
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Editor mode")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false in Editor mode")

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

        AssertEqual(RPQuest.JournalTab.btnTargetOptional:IsHidden(), false, "btnTargetOptional visible when targets exist")
        RPQuest.JournalTab.btnTargetOptional:GetHandler("OnClicked")()
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(draft.targets[2].optional, true, "Clicking btnTargetOptional toggles optional=true on selected target")

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
        AssertEqual(tab.btnCaptureTargetLoc:GetText(), "Capture Loc", "btnCaptureTargetLoc shows plain label before capture")
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), true, "btnClearTargetLoc hidden before location capture")
        AssertEqual(tab.btnTargetLocRequired:IsHidden(), true, "btnTargetLocRequired hidden before location capture")
        AssertEqual(tab.btnTargetRadSmall:IsHidden(), true, "btnTargetRadSmall hidden before location capture")
        AssertEqual(tab.lblTargetLocStatus:GetText(), RPQuest.Locale:Get("TARGET_LOC_STATUS_NONE"), "Status shows Location: None initially")

        -- Capture location via button
        tab.btnCaptureTargetLoc:GetHandler("OnClicked")()
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(draft.targets[1]), true, "Target has captured location after btnCaptureTargetLoc")
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), false, "btnClearTargetLoc visible immediately after capture")
        AssertEqual(tab.btnTargetLocRequired:IsHidden(), false, "btnTargetLocRequired visible immediately after capture")
        AssertEqual(tab.btnTargetRadSmall:IsHidden(), false, "btnTargetRadSmall visible immediately after capture")
        AssertTrue(tab.btnCaptureTargetLoc:GetText():find("Capture Loc", 1, true) ~= nil and tab.btnCaptureTargetLoc:GetText():find("|c33FF33", 1, true) ~= nil, "btnCaptureTargetLoc highlighted when location is captured")
        AssertEqual(tab.lblTargetLocStatus:GetText(), RPQuest.Locale:Get("TARGET_LOC_STATUS_SET", 15), "Status updates to Location: Set (15m)")

        -- Toggle locationRequired = true, then clear location via btnClearTargetLoc
        tab.btnTargetLocRequired:GetHandler("OnClicked")()
        AssertEqual(draft.targets[1].locationRequired, true, "btnTargetLocRequired sets locationRequired=true")

        tab.btnClearTargetLoc:GetHandler("OnClicked")()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(draft.targets[1]), false, "HasTargetLocation false after btnClearTargetLoc")
        AssertEqual(draft.targets[1].zoneId, nil, "zoneId cleared to nil")
        AssertEqual(draft.targets[1].worldX, nil, "worldX cleared to nil")
        AssertEqual(draft.targets[1].worldZ, nil, "worldZ cleared to nil")
        AssertEqual(draft.targets[1].radius, nil, "radius cleared to nil")
        AssertEqual(draft.targets[1].locationRequired, false, "locationRequired reset to false")
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), true, "btnClearTargetLoc hidden immediately after clear")
        AssertEqual(tab.btnTargetLocRequired:IsHidden(), true, "btnTargetLocRequired hidden immediately after clear")
        AssertEqual(tab.btnTargetRadSmall:IsHidden(), true, "btnTargetRadSmall hidden immediately after clear")
        AssertEqual(tab.btnTargetRadMedium:IsHidden(), true, "btnTargetRadMedium hidden immediately after clear")
        AssertEqual(tab.btnTargetRadLarge:IsHidden(), true, "btnTargetRadLarge hidden immediately after clear")
        AssertEqual(tab.btnCaptureTargetLoc:GetText(), "Capture Loc", "btnCaptureTargetLoc returns to plain label after clear")
        AssertEqual(tab.lblTargetLocStatus:GetText(), RPQuest.Locale:Get("TARGET_LOC_STATUS_NONE"), "Status returns to Location: None after clear")

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
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), false, "btnClearTargetLoc visible when editing quest with target location")
        AssertEqual(tab.lblTargetLocStatus:GetText(), RPQuest.Locale:Get("TARGET_LOC_STATUS_SET", 15), "Edit status shows Location: Set (15m)")

        tab.btnClearTargetLoc:GetHandler("OnClicked")()
        local editDraft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(RPQuest.QuestRepository:HasTargetLocation(editDraft.targets[1]), false, "Edit draft target location cleared")
        AssertEqual(tab.btnClearTargetLoc:IsHidden(), true, "btnClearTargetLoc hidden after clearing in edit mode")
        AssertEqual(tab.lblTargetLocStatus:GetText(), RPQuest.Locale:Get("TARGET_LOC_STATUS_NONE"), "Edit status returns to Location: None")

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
        AssertEqual(repo:GetPreparedQuestStatus(copied), "draft", "Copied quest is in Preparing")
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
                customMessage = "Bandido abatido",
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
        AssertTrue(tab.detailObjText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_OPTIONAL_UNDETECTED"), 1, true) ~= nil, "Detail pane shows Optional Undetected")

        local qReq = repo:BuildQuestRecord(11, "Req Quest", "D", {
            { name = "G", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2, stealthMode = "required" }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        qReq.wasDetected = true
        qReq.failed = true
        table.insert(repo.savedVars.quests, qReq)
        repo._questById[11] = qReq
        tab:SelectQuest(11)
        AssertTrue(tab.detailObjText:GetText():find(RPQuest.Locale:Get("STEALTH_STATUS_REQUIRED_FAILED"), 1, true) ~= nil, "Detail pane shows Required Failed")
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

end
