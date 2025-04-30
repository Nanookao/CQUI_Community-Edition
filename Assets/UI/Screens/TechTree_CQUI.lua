
-- CQUI/Infixo choose a proper base file to load
include("CQUICommon");

if g_bIsGatheringStorm then
    include("TechTree_Expansion2"); -- XP2
elseif g_bIsRiseAndFall then
    include("TechTree_Expansion1"); -- XP1
else
    include("TechTree"); -- base
end


-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_OnOpen = OnOpen;
BASE_CQUI_Close = Close;
BASE_CQUI_PopulateNode = PopulateNode;
BASE_CQUI_OnLocalPlayerTurnBegin = OnLocalPlayerTurnBegin;
BASE_CQUI_OnResearchComplete = OnResearchComplete;
BASE_CQUI_LateInitialize = LateInitialize;
BASE_CQUI_OnShutdown = OnShutdown;
BASE_CQUI_SetCurrentNode = SetCurrentNode;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_STATUS_MESSAGE_TECHS :number = 4;  -- Number to distinguish tech messages
local CQUI_halfwayNotified  :table = {};
local CQUI_ShowTechCivicRecommendations = false;
local CQUI_AutoRepeatTechCivic:boolean = false;

function CQUI_OnSettingsUpdate()
    CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1;
    CQUI_AutoRepeatTechCivic = GameConfiguration.GetValue("CQUI_AutoRepeatTechCivic");
end

-- ===========================================================================
--  CQUI modified OnOpen functiton
--  Add to popup queue
--  Search bar autofocus
-- ===========================================================================
function OnOpen()
    if (Game.GetLocalPlayer() == -1) then
        return
    end

    BASE_CQUI_OnOpen();

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
--  CQUI modified OnClose functiton
--  Main close function all exit points should call.
--  Remove from popup queue
-- ===========================================================================
function Close()
    BASE_CQUI_Close()
    UIManager:DequeuePopup(ContextPtr)
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
--  Check for Tech Progress
-- ===========================================================================
function OnLocalPlayerTurnBegin()
    BASE_CQUI_OnLocalPlayerTurnBegin();

    local ePlayer :number = Game.GetLocalPlayer();
    if ePlayer ~= -1 then
        -- Get the current tech
        local kPlayer   :table  = Players[ePlayer];
        local playerTechs :table  = kPlayer:GetTechs();
        local currentTechID :number = playerTechs:GetResearchingTech();
        local isCurrentBoosted :boolean = playerTechs:HasBoostBeenTriggered(currentTechID);

        -- Make sure there is a technology selected before continuing with checks
        if currentTechID ~= -1 then
            local techName = GameInfo.Technologies[currentTechID].Name;
            local techType = GameInfo.Technologies[currentTechID].Type;
            local currentCost = playerTechs:GetResearchCost(currentTechID);
            local currentProgress  = playerTechs:GetResearchProgress(currentTechID);
            local currentYield = playerTechs:GetScienceYield();
            local percentageToBeDone = (currentProgress + currentYield) / currentCost;
            local percentageNextTurn = (currentProgress + currentYield*2) / currentCost;
            local CQUI_halfway:number = 0.5;

            -- Finds boost amount, always 50 in base game, China's +10% modifier is not applied here
            for row in GameInfo.Boosts() do
                if (row.ResearchType == techType) then
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
                CQUI_halfwayNotified[techName] = true;
            elseif percentageNextTurn >= CQUI_halfway and isCurrentBoosted == false and CQUI_halfwayNotified[techName] ~= true then
                    LuaEvents.StatusMessage("[ICON_SCIENCE]"..Locale.Lookup("LOC_CQUI_TECH_MESSAGE_S") .. " " .. Locale.Lookup( techName ) .. " " .. Locale.Lookup("LOC_CQUI_HALF_MESSAGE_E"), 10, ReportingStatusTypes.DEFAULT);
                    CQUI_halfwayNotified[techName] = true;
            end

        end
    end
end

-- ===========================================================================
--  CQUI modified OnResearchComplete functiton
--  Show completion notification
--  Update real housing
-- ===========================================================================
function OnResearchComplete( ePlayer:number, eTech:number)
    BASE_CQUI_OnResearchComplete(ePlayer, eTech);

    if ePlayer == Game.GetLocalPlayer() then
        -- Get the current tech
        local kPlayer   :table      = Players[ePlayer];
        local currentTechID :number = eTech;

        -- Make sure there is a technology selected before continuing with checks
        if currentTechID ~= -1 then
            local techName = GameInfo.Technologies[currentTechID].Name;
            LuaEvents.StatusMessage("[ICON_SCIENCE]"..Locale.Lookup("LOC_TECH_BOOST_COMPLETE", techName), 10, ReportingStatusTypes.DEFAULT);
        end

        -- CQUI update all cities real housing when play as India and researched Sanitation
        if GameInfo.Technologies["TECH_SANITATION"] and eTech == GameInfo.Technologies["TECH_SANITATION"].Index then    -- Sanitation
            if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_INDIA") then
                LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
            end
        -- CQUI update all cities real housing when play as Indonesia and researched Mass Production
        elseif GameInfo.Technologies["TECH_MASS_PRODUCTION"] and eTech == GameInfo.Technologies["TECH_MASS_PRODUCTION"].Index then    -- Mass Production
            if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_INDONESIA") then
                LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
            end
        end

        -- If repeatable, automatically repeat per settings
        if (currentTechID ~= -1 and CQUI_AutoRepeatTechCivic) then
            local tech = GameInfo.Technologies[currentTechID];
            local kPlayerTechs = kPlayer:GetTechs();
            local pathToTech = kPlayerTechs:GetResearchPath(tech.Hash);
            if ((pathToTech == nil or next(pathToTech) == nil) and tech and tech.Repeatable and kPlayerTechs:CanResearch(tech.Index)) then
                local tParameters = {};
                tParameters[PlayerOperations.PARAM_TECH_TYPE] = tech.Hash;
                tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
                UI.RequestPlayerOperation(ePlayer, PlayerOperations.RESEARCH, tParameters);
            end
        end
    end
end

-- ===========================================================================
--  CQUI modified SetCurrentNode functiton
--  Fix the future not tech not being repeatable from the tree
-- ===========================================================================
function SetCurrentNode( hash:number )
    BASE_CQUI_SetCurrentNode(hash);

    if hash ~= nil then
        local localPlayerTechs = Players[Game.GetLocalPlayer()]:GetTechs();
        local pathToTech = localPlayerTechs:GetResearchPath( hash );
        local tParameters = {};
        local tech = GameInfo.Technologies[hash] -- the selected tech

        if (pathToTech == nil or next(pathToTech) == nil) and tech and tech.Repeatable and localPlayerTechs:CanResearch(tech.Index) then
            tParameters[PlayerOperations.PARAM_TECH_TYPE] = hash;
            tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;

            UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.RESEARCH, tParameters);
            --UI.PlaySound("Confirm_Tech_TechTree");
        end
    end

end

function LateInitialize()
    BASE_CQUI_LateInitialize();

    LuaEvents.LaunchBar_RaiseTechTree.Remove(BASE_CQUI_OnOpen);
    LuaEvents.ResearchChooser_RaiseTechTree.Remove(BASE_CQUI_OnOpen);
    LuaEvents.LaunchBar_RaiseTechTree.Add(OnOpen);
    LuaEvents.ResearchChooser_RaiseTechTree.Add(OnOpen);
    --LuaEvents.TechTree_CloseTechTree.Add(OnClose_CQUI);
    Events.LocalPlayerTurnBegin.Remove(BASE_CQUI_OnLocalPlayerTurnBegin);
    Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
    Events.ResearchCompleted.Remove(BASE_CQUI_OnResearchComplete);
    Events.ResearchCompleted.Add(OnResearchComplete);

    -- CQUI add exceptions to the 50% notifications by putting techs into the CQUI_halfwayNotified table
    CQUI_halfwayNotified["LOC_TECH_POTTERY_NAME"] = true;
    CQUI_halfwayNotified["LOC_TECH_MINING_NAME"] = true;
    CQUI_halfwayNotified["LOC_TECH_ANIMAL_HUSBANDRY_NAME"] = true;

    LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end

function OnShutdown()
    -- Clean up events
    --[[
    --LuaEvents.LaunchBar_RaiseTechTree.Add(BASE_CQUI_OnOpen);
    --LuaEvents.ResearchChooser_RaiseTechTree.Add(BASE_CQUI_OnOpen);
    LuaEvents.LaunchBar_RaiseTechTree.Remove(OnOpen);
    LuaEvents.ResearchChooser_RaiseTechTree.Remove(OnOpen);
    LuaEvents.TechTree_CloseTechTree.Remove(OnClose);
    --Events.LocalPlayerTurnBegin.Add(BASE_CQUI_OnLocalPlayerTurnBegin);
    Events.LocalPlayerTurnBegin.Remove(OnLocalPlayerTurnBegin);
    --Events.ResearchCompleted.Add(BASE_CQUI_OnResearchComplete);
    Events.ResearchCompleted.Remove(OnResearchComplete);
    --]]

    LuaEvents.CQUI_SettingsUpdate.Remove(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SettingsInitialized.Remove(CQUI_OnSettingsUpdate);

    BASE_CQUI_OnShutdown();
end

