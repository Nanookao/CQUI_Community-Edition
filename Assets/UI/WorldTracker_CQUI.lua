print("Loading WorldTracker_CQUI.lua from CQUI");
include("ToolTipHelper");
include("CQUICommon.lua");

-- CQUI/Infixo Load a proper base file
-- CivBattleRoyale file could be loaded also here - need to find proper conditions to trigger it
if g_bIsRiseAndFall or g_bIsGatheringStorm then
    include("WorldTracker_Expansion1");
else
    include("WorldTracker");
end

-- ===========================================================================
-- Overwritten base functions
-- ===========================================================================
BASE_CQUI_OnInit              = OnInit
BASE_CQUI_LateInitialize      = LateInitialize
-- BASE_CQUI_OnGameDebugReturn   = OnGameDebugReturn
BASE_CQUI_OnShutdown          = OnShutdown

BASE_CQUI_OnCivicChanged      = OnCivicChanged
BASE_CQUI_OnResearchChanged   = OnResearchChanged

BASE_CQUI_OnCivicCompleted    = OnCivicCompleted
BASE_CQUI_OnResearchCompleted = OnResearchCompleted

BASE_CQUI_UpdateCivicsPanel   = UpdateCivicsPanel
BASE_CQUI_UpdateResearchPanel = UpdateResearchPanel

BASE_CQUI_RealizeEmptyMessage = RealizeEmptyMessage
BASE_CQUI_IsAllPanelsHidden   = IsAllPanelsHidden


-- ===========================================================================
-- Variables
-- ===========================================================================
g_researchInstance  = nil
g_civicsInstance    = nil
local m_ResearchType  :string
local m_CivicType     :string
-- local m_hideResearch  :boolean
-- local m_hideCivics    :boolean
-- local m_lastResearchCompletedID :number = -1
-- local m_lastCivicCompletedID    :number = -1
local CIVIC_PANEL_TEXTURE_NAME    = "CivicPanel_Frame";
local RESEARCH_PANEL_TEXTURE_NAME = "ResearchPanel_Frame";
-- local m_EmptyPanelDisabled = true


-- ===========================================================================
-- CQUI Extension Functions
-- ===========================================================================
function OnInit(isReload:boolean)	
    print( "CQUI OnInit(): isReload=", isReload )
    -- Standard refresh even if reloading
    -- Removed LuaEvents.GameDebug_GetValues()
    return BASE_CQUI_OnInit(false)
end

-- Called from event handler, thus no need to reregister
function LateInitialize()
    local playerID = Game.GetLocalPlayer()
    local pPlayerConfig = PlayerConfigurations[playerID];
    local m_hideResearch = toboolean( pPlayerConfig:GetValue("WorldTracker_hideResearch") )
    local m_hideCivics   = toboolean( pPlayerConfig:GetValue("WorldTracker_hideCivics") )
    local m_lastResearchCompletedID = tonumber( pPlayerConfig:GetValue("WorldTracker_lastResearchCompletedID") or nil )
    local m_lastCivicCompletedID    = tonumber( pPlayerConfig:GetValue("WorldTracker_lastCivicCompletedID") or nil )

    local pPlayer :table = Players[playerID]
    local pPlayerCulture :table = pPlayer and pPlayer:GetCulture()
    if pPlayerCulture then
        -- Hide choosers if nothing selected
        if m_hideResearch == nil then  m_hideResearch = -1 == pPlayer:GetTechs():GetResearchingTech()  end
        if m_hideCivics   == nil then  m_hideCivics   = -1 == pPlayerCulture:GetProgressingCivic()  end
    end

    if m_hideResearch then  UpdateResearchPanel(m_hideResearch)  end
    if m_hideCivics   then  UpdateCivicsPanel  (m_hideCivics  )  end
    if m_lastResearchCompletedID then  BASE_CQUI_OnResearchCompleted(playerID, m_lastResearchCompletedID)  end
    if m_lastCivicCompletedID    then  BASE_CQUI_OnCivicCompleted   (playerID, m_lastCivicCompletedID   )  end

    BASE_CQUI_LateInitialize()
end

--[[
function OnGameDebugReturn(context:string, contextTable:table)	
    -- if context ~= RELOAD_CACHE_ID then  return  end
    -- LateInitialize() restores m_lastResearchCompletedID and similars
end
--]]

function OnShutdown()
    Unsubscribe()
    -- Removed LuaEvents.GameDebug_AddValue(*)
end


function CQUI_Initialize()
	ContextPtr:SetInitHandler(OnInit)
	ContextPtr:SetShutdown(OnShutdown)
	LuaEvents.GameDebug_Return.Remove(OnGameDebugReturn)
end
CQUI_Initialize()


-- ===========================================================================
function OnCivicChanged( playerID:number, eCivic:number )
    if playerID == Game.GetLocalPlayer() then
        -- Show CivicsChooser when changed
        UpdateCivicsPanel(false)
    end
    BASE_CQUI_OnCivicChanged(playerID, eCivic)
end

function OnResearchChanged( playerID:number, eTech:number )
    if playerID == Game.GetLocalPlayer() then
        -- Show ResearchChooser when changed
        UpdateResearchPanel(false)
    end
    BASE_CQUI_OnResearchChanged(playerID, eCivic)
end


-- ===========================================================================
function OnCivicCompleted( playerID:number, eCivic:number )
    if playerID == Game.GetLocalPlayer() then
        m_lastCivicCompletedID = eCivic;
        PlayerConfigurations[playerID]:SetValue("WorldTracker_lastCivicCompletedID", m_lastCivicCompletedID)
    end

    BASE_CQUI_OnCivicCompleted(playerID, eCivic);
end

function OnResearchCompleted( playerID:number, eTech:number )
    if playerID == Game.GetLocalPlayer() then
        m_lastResearchCompletedID = eTech;
        PlayerConfigurations[playerID]:SetValue("WorldTracker_lastResearchCompletedID", m_lastResearchCompletedID)
    end

    BASE_CQUI_OnResearchCompleted(playerID, eTech);
end


-- ===========================================================================
function UpdateCivicsPanel(hideCivics:boolean)
    --print("UpdateCivicsPanel");
    BASE_CQUI_UpdateCivicsPanel(hideCivics);

    -- CQUI extension to add a tooltip showing the details of the current civic
    local localPlayer :number = Game.GetLocalPlayer();
    if (localPlayer ~= -1 and not hideCivics and not IsCivicsHidden()) then
        local iCivic:number = Players[localPlayer]:GetCulture():GetProgressingCivic();
        if iCivic == -1 then
            iCivic = m_lastCivicCompletedID;
        end
        -- show the tooltip
        if iCivic == -1 then
            -- Nothing yet researched (begin of the game)
            SetMainPanelToolTip(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_CIVIC"), CIVIC_PANEL_TEXTURE_NAME);
        else
            local mainPanelToolTip:string = ToolTipHelper.GetToolTip( GameInfo.Civics[iCivic].CivicType, localPlayer );
            SetMainPanelToolTip(mainPanelToolTip, CIVIC_PANEL_TEXTURE_NAME);
        end
    end
end

-- ===========================================================================
function UpdateResearchPanel( isHideResearch:boolean )
    --print("UpdateResearchPanel");
    BASE_CQUI_UpdateResearchPanel(isHideResearch);

    -- CQUI extension to add a tooltip showing the details of the current tech
    local localPlayer :number = Game.GetLocalPlayer();
    if (localPlayer ~= -1 and not isHideResearch and not IsResearchHidden()) then
        local iTech:number = Players[localPlayer]:GetTechs():GetResearchingTech();
        if iTech == -1 then
            iTech = m_lastResearchCompletedID;
        end
        -- show the tooltip
        if iTech == -1 then
            -- Nothing yet researched (begin of the game)
            SetMainPanelToolTip(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_RESEARCH"), RESEARCH_PANEL_TEXTURE_NAME);
        else
            local mainPanelToolTip:string = ToolTipHelper.GetToolTip( GameInfo.Technologies[iTech].TechnologyType, localPlayer );
            SetMainPanelToolTip(mainPanelToolTip, RESEARCH_PANEL_TEXTURE_NAME);
        end
    end
end


-- ===========================================================================
function RealizeEmptyMessage()
  -- Don't show Controls.EmptyPanel when all panels are hidden
  if m_EmptyPanelDisabled then  return  end

  -- First a quick check if all native panels are hidden.
  local basegamePanelsHidden :boolean = IsChatHidden() and IsCivicsHidden() and IsResearchHidden()
  basegamePanelsHidden = basegamePanelsHidden and IsUnitListHidden()

  local kCrisisData :table = basegamePanelsHidden and (g_bIsRiseAndFall or g_bIsGatheringStorm)
    and Game.GetEmergencyManager():GetEmergencyInfoTable(Game.GetLocalPlayer()) or {}
  basegamePanelsHidden = basegamePanelsHidden and next(kCrisisData) == nil

  local allPanelsHidden :boolean = basegamePanelsHidden and IsAllPanelsHidden()
  Controls.EmptyPanel:SetHide(not allPanelsHidden);
end

function IsAllPanelsHidden()
  local uiChildren:table = Controls.WorldTrackerVerticalContainer:GetChildren();
  for i,uiChild in ipairs(uiChildren) do
    -- print( "IsAllPanelsHidden()", uiChild:GetID(), uiChild:IsVisible() )
    if uiChild:IsVisible() then
      return false;
    end
  end
  return true;
end


-- ===========================================================================
-- CQUI Custom Functions
-- ===========================================================================
function SetMainPanelToolTip(toolTip:string, panelTextureName:string)
    --print("SetMainPanelToolTip", toolTip, panelTextureName);
    -- Get either the MainPanel from the CivicInstance or ResearchInstance
    for _,ctrl in pairs(Controls.WorldTrackerVerticalContainer:GetChildren()) do
        if (ctrl:GetID() == "MainPanel" and ctrl:GetTexture() == panelTextureName) then
            ctrl:LocalizeAndSetToolTip(toolTip);
        end
    end
end


function toboolean(str :string)
    if type(str) == 'boolean' then  return str  end
    if str == 'false' then  return false  end
    return str == 'true' or nil
end
