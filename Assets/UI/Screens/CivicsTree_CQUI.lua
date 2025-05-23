
-- CQUI/Infixo choose a proper base file to load
include("CQUICommon");

if g_bIsGatheringStorm then
    include("CivicsTree_Expansion2");
else
    include("CivicsTree"); -- base & XP1
end


-- CQUI Infixo 2021-0528 fix for Game Seed = 0
local m_kScrambledRowLookup	:table  = {-1,-3,2,0,1,-2,3};		-- To help scramble modulo rows
local m_gameSeed			:number = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
if m_gameSeed == nil then m_gameSeed = 0; end

-- ===========================================================================
--	Get visual row for tech.
-- ===========================================================================
function GetRandomizedTreeRow( uirow:number )
	local range :number = (ROW_MAX - ROW_MIN);
	local index	:number = ((uirow + m_gameSeed) % range) + 1;
	uirow = m_kScrambledRowLookup[index];
	return uirow;
end

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_LateInitialize = LateInitialize;
BASE_CQUI_OnShutdown = OnShutdown;
BASE_CQUI_PopulateNode = PopulateNode;
BASE_CQUI_OnOpen = OnOpen;
BASE_CQUI_Close = Close;
BASE_CQUI_OnCivicComplete = OnCivicComplete;
BASE_CQUI_OnLocalPlayerTurnBegin = OnLocalPlayerTurnBegin;
BASE_CQUI_SetCurrentNode = SetCurrentNode;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_STATUS_MESSAGE_CIVIC :number = 3;    -- Number to distinguish civic messages
local CQUI_halfwayNotified  :table = {};
local CQUI_ShowTechCivicRecommendations = false;
local CQUI_AutoRepeatTechCivic:boolean = false;

function CQUI_OnSettingsUpdate()
    CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1;
    CQUI_AutoRepeatTechCivic = GameConfiguration.GetValue("CQUI_AutoRepeatTechCivic");
end

-- ===========================================================================
--  CQUI modified PopulateNode functiton
--  Show/Hide Recommended Icon if enabled in settings
-- ===========================================================================
function PopulateNode(uiNode, playerTechData)
    BASE_CQUI_PopulateNode(uiNode, playerTechData);

    local live :table = playerTechData[DATA_FIELD_LIVEDATA][uiNode.Type]; 
    if not CQUI_ShowTechCivicRecommendations then
        uiNode.RecommendedIcon:SetHide(true);
    end
end

-- ===========================================================================
--  CQUI modified OnLocalPlayerTurnBegin functiton
--  Check for Civic Progress
-- ===========================================================================
function OnLocalPlayerTurnBegin()
    BASE_CQUI_OnLocalPlayerTurnBegin();

    -- CQUI comment: We do not use UpdateLocalPlayer() here, because of Check for Civic Progress
    local ePlayer :number = Game.GetLocalPlayer();
    if ePlayer ~= -1 then
        -- Get the current tech
        local kPlayer       :table  = Players[ePlayer];
        local playerCivics      :table  = kPlayer:GetCulture();
        local currentCivicID  :number = playerCivics:GetProgressingCivic();
        local isCurrentBoosted  :boolean = playerCivics:HasBoostBeenTriggered(currentCivicID);

        -- Make sure there is a civic selected before continuing with checks
        if currentCivicID ~= -1 then
            local civicName = GameInfo.Civics[currentCivicID].Name;
            local civicType = GameInfo.Civics[currentCivicID].Type;
            local currentCost = playerCivics:GetCultureCost(currentCivicID);
            local currentProgress = playerCivics:GetCulturalProgress(currentCivicID);
            local currentYield = playerCivics:GetCultureYield();
            local percentageToBeDone = (currentProgress + currentYield) / currentCost;
            local percentageNextTurn = (currentProgress + currentYield*2) / currentCost;
            local CQUI_halfway:number = .5;

            -- Finds boost amount, always 50 in base game, China's +10% modifier is not applied here
            for row in GameInfo.Boosts() do
                if (row.CivicType == civicType) then
                    CQUI_halfway = (100 - row.Boost) / 100;
                    break;
                end
            end
            --If playing as china, apply boost modifier. Not sure where I can query this value...
            if (PlayerConfigurations[Game.GetLocalPlayer()]:GetCivilizationTypeName() == "CIVILIZATION_CHINA") then
                CQUI_halfway = CQUI_halfway - .1;
            end

            -- Is it greater than 50% and has yet to be displayed?
            if isCurrentBoosted then
                CQUI_halfwayNotified[civicName] = true;
            elseif percentageNextTurn >= CQUI_halfway and CQUI_halfwayNotified[civicName] ~= true then
                LuaEvents.StatusMessage("[ICON_CULTURE]"..Locale.Lookup("LOC_CQUI_CIVIC_MESSAGE_S") .. " " .. Locale.Lookup( civicName ) ..  " " .. Locale.Lookup("LOC_CQUI_HALF_MESSAGE_E"), 10, ReportingStatusTypes.DEFAULT);
                CQUI_halfwayNotified[civicName] = true;
            end

        end
    end
end

-- ===========================================================================
--  CQUI modified OnCivicComplete functiton
--  Show completion notification
--  Update real housing
-- ===========================================================================
function OnCivicComplete( ePlayer:number, eTech:number)
    BASE_CQUI_OnCivicComplete(ePlayer, eTech);

    if ePlayer == Game.GetLocalPlayer() then
        -- Get the current tech
        local kPlayer       :table  = Players[ePlayer];
        local currentCivicID  :number = eTech;

        -- Make sure there is a civic selected before continuing with checks
        if currentCivicID ~= -1 then
            local civicName = GameInfo.Civics[currentCivicID].Name;
            LuaEvents.StatusMessage("[ICON_CULTURE]"..Locale.Lookup("LOC_CIVIC_BOOST_COMPLETE", civicName), 10, ReportingStatusTypes.DEFAULT);
        end

        -- CQUI update all cities real housing when play as Cree and researched Civil Service
        if GameInfo.Civics["CIVIC_CIVIL_SERVICE"] and eTech == GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index then    -- Civil Service
            if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_CREE") then
                LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
            end
        -- CQUI update all cities real housing when play as Scotland and researched Globalization
        elseif GameInfo.Civics["CIVIC_GLOBALIZATION"] and eTech == GameInfo.Civics["CIVIC_GLOBALIZATION"].Index then    -- Globalization
            if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_SCOTLAND") then
                LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
            end
        end

        -- If repeatable, automatically repeat per settings
        if (currentCivicID ~= -1 and CQUI_AutoRepeatTechCivic) then
            local civic = GameInfo.Civics[currentCivicID];
            local kPlayerCivics = kPlayer:GetCulture();
            local pathToCivic = kPlayerCivics:GetCivicPath(civic.Hash);
            if ((pathToCivic == nil or next(pathToCivic) == nil) and civic and civic.Repeatable and kPlayerCivics:CanProgress(civic.Index)) then
                local tParameters = {};
                tParameters[PlayerOperations.PARAM_CIVIC_TYPE]  = civic.Hash;
                tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
                UI.RequestPlayerOperation(ePlayer, PlayerOperations.PROGRESS_CIVIC, tParameters);
            end
        end
    end
end

-- ===========================================================================
--  CQUI modified OnOpen functiton
--  Search bar autofocus
-- ===========================================================================
function OnOpen()
    if (Game.GetLocalPlayer() == -1) then
        return;
    end

    BASE_CQUI_OnOpen()

    -- Queue the screen as a popup, but we want it to render at a desired location in the hierarchy, not on top of everything.
    if not UIManager:IsInPopupQueue(ContextPtr) then
        local kParameters = {};
        kParameters.RenderAtCurrentParent = true;
        kParameters.InputAtCurrentParent = true;
        kParameters.AlwaysVisibleInQueue = true;
        UIManager:QueuePopup(ContextPtr, PopupPriority.Low, kParameters);
        -- Change our parent to be 'Screens' so the navigational hooks draw on top of it.
        ContextPtr:ChangeParent(ContextPtr:LookUpControl("/InGame/Screens"));
    end

    Controls.SearchEditBox:TakeFocus();
end

-- ===========================================================================
--  CQUI modified Close functiton
--  Main close function all exit points should call.
--  Remove from popup queue
-- ===========================================================================
function Close()
    BASE_CQUI_Close()
    UIManager:DequeuePopup(ContextPtr)
end

-- ===========================================================================
--  CQUI modified SetCurrentNode functiton
--  Fix the future civic not being repeatable
-- ===========================================================================
function SetCurrentNode( hash )
    BASE_CQUI_SetCurrentNode(hash);
    
    if hash ~= nil then
        local localPlayerCulture = Players[Game.GetLocalPlayer()]:GetCulture();
        -- Get the complete path to the tech
        local pathToCivic = localPlayerCulture:GetCivicPath( hash );
        local tParameters = {};
        local civic = GameInfo.Civics[hash];

        if (pathToCivc == nil or next(pathToCivic) == nil) and civic and civic.Repeatable and localPlayerCulture:CanProgress(civic.Index) then
            tParameters[PlayerOperations.PARAM_CIVIC_TYPE]  = hash;
            tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;

            UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.PROGRESS_CIVIC, tParameters);
            --UI.PlaySound("Confirm_Civic_CivicsTree");
        end
    end
end

function LateInitialize()
    BASE_CQUI_LateInitialize();

    LuaEvents.CivicsPanel_RaiseCivicsTree.Remove(BASE_CQUI_OnOpen);
    LuaEvents.LaunchBar_RaiseCivicsTree.Remove(BASE_CQUI_OnOpen);
    LuaEvents.CivicsChooser_RaiseCivicsTree.Add(OnOpen);
    LuaEvents.LaunchBar_RaiseCivicsTree.Add(OnOpen);
    --LuaEvents.CivicsTree_CloseCivicsTree.Add(OnClose_CQUI);
    Events.CivicCompleted.Remove(BASE_CQUI_OnCivicComplete);
    Events.CivicCompleted.Add(OnCivicComplete);
    Events.LocalPlayerTurnBegin.Remove(BASE_CQUI_OnLocalPlayerTurnBegin);
    Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);

    -- CQUI add exceptions to the 50% notifications by putting civics into the CQUI_halfwayNotified table
    CQUI_halfwayNotified["LOC_CIVIC_CODE_OF_LAWS_NAME"] = true;

    LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end

function OnShutdown()
    -- Clean up events
    --[[
    --LuaEvents.CivicsPanel_RaiseCivicsTree.Add(BASE_CQUI_OnOpen);
    --LuaEvents.LaunchBar_RaiseCivicsTree.Add(BASE_CQUI_OnOpen);
    LuaEvents.CivicsChooser_RaiseCivicsTree.Remove(OnOpen);
    LuaEvents.LaunchBar_RaiseCivicsTree.Remove(OnOpen);
    LuaEvents.CivicsTree_CloseCivicsTree.Remove(Close_CQUI);
    --Events.CivicCompleted.Add(BASE_CQUI_OnCivicComplete);
    Events.CivicCompleted.Remove(OnCivicComplete);
    --Events.LocalPlayerTurnBegin.Add(BASE_CQUI_OnLocalPlayerTurnBegin);
    Events.LocalPlayerTurnBegin.Remove(OnLocalPlayerTurnBegin);
    --]]

    LuaEvents.CQUI_SettingsUpdate.Remove(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SettingsInitialized.Remove(CQUI_OnSettingsUpdate);

    BASE_CQUI_OnShutdown();
end

