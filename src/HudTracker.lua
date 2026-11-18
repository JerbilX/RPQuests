-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.HudTracker = {}
local HudTracker = Addon.HudTracker

local TRACKER_CONTROL_NAME = "RPQuest_HudTrackerPanel"

function HudTracker:Initialize()
    if self.isInitialized or not WINDOW_MANAGER or not GuiRoot then
        return
    end

    local panel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(290, 68)
    panel:SetMouseEnabled(true)

    local parentAnchor = ZO_FocusedQuestTrackerPanel or GuiRoot
    if ZO_FocusedQuestTrackerPanel then
        panel:SetAnchor(TOPRIGHT, parentAnchor, BOTTOMRIGHT, 0, 14)
    else
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -16, 260)
    end
    panel:SetHidden(true)

    local icon = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Icon", panel, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    icon:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -4, 2)
    if icon.SetTexture then
        icon:SetTexture((Addon.Constants and Addon.Constants.UI and Addon.Constants.UI.ICON_QUEST) or "EsoUI/Art/Compass/quest_icon_assisted.dds")
    end
    self.icon = icon

    local titleLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Title", panel, CT_LABEL)
    titleLabel:SetDimensions(254, 24)
    titleLabel:SetAnchor(TOPRIGHT, icon, TOPLEFT, -4, 0)
    if titleLabel.SetFont then titleLabel:SetFont("ZoFontWinH3") end
    if titleLabel.SetHorizontalAlignment then titleLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT or 2) end
    if titleLabel.SetColor then titleLabel:SetColor(0.91, 0.83, 0.63, 1) end
    self.titleLabel = titleLabel

    local objectiveLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Objective", panel, CT_LABEL)
    objectiveLabel:SetDimensions(280, 22)
    objectiveLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -4, 28)
    if objectiveLabel.SetFont then objectiveLabel:SetFont("ZoFontGameShadow") end
    if objectiveLabel.SetHorizontalAlignment then objectiveLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT or 2) end
    if objectiveLabel.SetColor then objectiveLabel:SetColor(1, 1, 1, 0.95) end
    self.objectiveLabel = objectiveLabel

    local locationLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Location", panel, CT_LABEL)
    locationLabel:SetDimensions(280, 18)
    locationLabel:SetAnchor(TOPRIGHT, objectiveLabel, BOTTOMRIGHT, 0, 2)
    if locationLabel.SetFont then locationLabel:SetFont("ZoFontGameSmall") end
    if locationLabel.SetHorizontalAlignment then locationLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT or 2) end
    if locationLabel.SetColor then locationLabel:SetColor(0.75, 0.75, 0.75, 0.85) end
    self.locationLabel = locationLabel

    panel:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside then return end
        if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
            PlaySound(SOUNDS.DEFAULT_CLICK)
        end
        local activeQuest = Addon.QuestRepository and Addon.QuestRepository:GetActiveQuest()
        if button == (MOUSE_BUTTON_INDEX_RIGHT or 2) then
            if Addon.WorldMapArea and activeQuest then
                Addon.WorldMapArea:ShowQuestOnMap(activeQuest)
            end
        else
            if Addon.JournalTab then
                if activeQuest then
                    Addon.JournalTab:SelectQuest(activeQuest.id)
                end
                Addon.JournalTab:OpenTab()
            end
        end
    end)

    self.panel = panel

    local FragmentClass = ZO_HUDFadeSceneFragment or ZO_FadeSceneFragment
    if FragmentClass then
        self.fragment = FragmentClass:New(panel)
        if HUD_SCENE and HUD_SCENE.AddFragment then
            HUD_SCENE:AddFragment(self.fragment)
        end
        if HUD_UI_SCENE and HUD_UI_SCENE.AddFragment then
            HUD_UI_SCENE:AddFragment(self.fragment)
        end
    end

    if Addon.QuestRepository then
        Addon.QuestRepository:RegisterListener(function(eventType)
            if eventType ~= "DRAFT_UPDATED" and eventType ~= "DRAFT_TARGET_CAPTURED" then
                self:Refresh()
            end
        end)
    end

    self.isInitialized = true
    self:Refresh()
end

function HudTracker:Refresh()
    if not self.panel then return end

    local activeQuest = Addon.QuestRepository and Addon.QuestRepository:GetActiveQuest()
    if not activeQuest or activeQuest.completed then
        if self.fragment and self.fragment.SetHiddenForReason then
            self.fragment:SetHiddenForReason("NoActiveRPQuest", true)
        end
        self.panel:SetHidden(true)
        return
    end

    self.titleLabel:SetText(activeQuest.title or "")

    local targets = (Addon.QuestRepository and Addon.QuestRepository:EnsureQuestTargets(activeQuest)) or {}
    local objLines = {}
    for _, t in ipairs(targets) do
        table.insert(objLines, Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            t.currentCount or 0,
            t.requiredCount or 1
        ))
    end
    local objHeight = math.max(22, #objLines * 20)
    self.objectiveLabel:SetDimensions(280, objHeight)
    self.objectiveLabel:SetText(table.concat(objLines, "\n"))
    self.panel:SetDimensions(290, 46 + objHeight)

    local locName = (activeQuest.mapName and activeQuest.mapName ~= "" and activeQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    self.locationLabel:SetText(locName)

    if self.fragment and self.fragment.SetHiddenForReason then
        self.fragment:SetHiddenForReason("NoActiveRPQuest", false)
    end

    local hudShowing = true
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        local inHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
        if SCENE_MANAGER:GetCurrentScene() ~= nil then
            hudShowing = inHud
        end
    end
    self.panel:SetHidden(not hudShowing)
end
