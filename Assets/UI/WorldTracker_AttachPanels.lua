local VERSION = 20250427
local loadedVersion = ExposedMembers.WorldTracker and ExposedMembers.WorldTracker.VERSION or 0
print( "Loading WorldTracker_AttachPanels.lua version "..VERSION..", already loaded:", loadedVersion )
if VERSION <= loadedVersion then  return  end


local m_PanelContainer = Controls.WorldTrackerVerticalContainer
local m_CheckBoxContainer = Controls.DropdownGrid and Controls.DropdownGrid:GetChildren()[1]
ExposedMembers.WorldTracker = ExposedMembers.WorldTracker or {}
ExposedMembers.WorldTracker.VERSION = VERSION
ExposedMembers.WorldTracker.Panels = ExposedMembers.WorldTracker.Panels or {}
ExposedMembers.WorldTracker.CheckBoxes = ExposedMembers.WorldTracker.CheckBoxes or {}
ExposedMembers.WorldTracker.PanelContainer = m_PanelContainer
ExposedMembers.WorldTracker.CheckBoxContainer = m_CheckBoxContainer


-- ===========================================================================
--	Global API
-- ===========================================================================
-- Call this globally accessible method to attach a panel from a different UI context (different xml).
-- The panel will be restored if WorldTracker is hot-reloaded.
-- The previous panel with the same ID will be removed.
-- @param  ID  the unique identifier of the added panel
-- @param  pPanel  the panel UI object
function ExposedMembers.WorldTracker:AttachPanel(ID :string, pPanel :table, pCheckBox :table)
    print( "ExposedMembers.WorldTracker:AttachPanel('"..ID.."', pPanel= ", pPanel, ", pCheckBox= ", pCheckBox, ")" )
    local pPrevious = self.Panels[ID]
    if pPrevious ~= pPanel then
        self.Panels[ID] = pPanel
        if pPrevious then  m_PanelContainer:DestroyChild(pPrevious)  end
        if pPanel    then  pPanel:ChangeParent(m_PanelContainer)  end
        self:ResizePanels()
    end

    pPrevious = self.CheckBoxes[ID]
    if pPrevious ~= pCheckBox and m_CheckBoxContainer then
        self.CheckBoxes[ID] = pCheckBox
        if pPrevious then  m_CheckBoxContainer:DestroyChild(pPrevious)  end
        if pCheckBox then  pCheckBox:ChangeParent(m_CheckBoxContainer)  end
        m_CheckBoxContainer.ReprocessAnchoring()
    end
end


-- ===========================================================================
function ExposedMembers.WorldTracker:ResizePanels()
    -- What's necessary?
    m_PanelContainer:CalculateSize()  -- also in UpdateUnitListSize()
    m_PanelContainer:ReprocessAnchoring()  -- not called otherwise
    -- m_PanelContainer:DoAutoSize()  -- ??
end

local function ReattachPanels()
    for k,pPanel in pairs(ExposedMembers.WorldTracker.Panels) do
        pPanel:ChangeParent(m_PanelContainer)
    end
    ExposedMembers.WorldTracker:ResizePanels()
end

local function DetachPanels()
    for k,pPanel in pairs(ExposedMembers.WorldTracker.Panels) do
        pPanel:ChangeParent(nil)
    end
end


-- ===========================================================================
--	OVERRIDE FUNCTIONS
-- ===========================================================================
-- local BASE_AP_AttachDynamicUI = AttachDynamicUI
local BASE_AP_OnInit      = OnInit
local BASE_AP_OnShutdown  = OnShutdown


function OnInit(isReload :boolean)
    print( "WorldTracker_AttachPanels OnInit(): isReload=", isReload )
    ReattachPanels()
    BASE_AP_OnInit(isReload)
end

function OnShutdown()
    DetachPanels()
    BASE_AP_OnShutdown()
end




function AP_Initialize()
    ContextPtr:SetInitHandler(OnInit)
    ContextPtr:SetShutdown(OnShutdown)
end
AP_Initialize()




--[[
-- ===========================================================================
--	Add any UI from tracked items that are loaded.
--	Items are expected to be tables with the following fields:
--		Name			localization key for the title name of panel
--		InstanceType	the instance (in XML) to create for the control
--		SelectFunc		if instance has "IconButton" the callback when pressed
-- ===========================================================================
function AttachDynamicUI()
	for i,pPanel in ipairs(g_TrackedItems) do
    local uiParent :table = Controls.WorldTrackerVerticalContainer
    local uiInstance :table = pPanel.Instance
		if uiInstance then
      uiInstance:ChangeParent(uiParent)
    elseif pPanel.ContextName then
      uiInstance = ContextPtr:LoadNewContext(pPanel.ContextName)
      pPanel.Instance = uiInstance
      uiInstance:ChangeParent(uiParent)
    else
      uiInstance = {}
      pPanel.Instance = uiInstance
      ContextPtr:BuildInstanceForControl(pPanel.InstanceType, pPanel.Instance, uiParent)

      if pPanel.SelectFunc and uiInstance.IconButton then
        uiInstance.IconButton:RegisterCallback(Mouse.eLClick, function() pPanel.SelectFunc() end);
      end

      if(uiInstance.TitleButton) then
        uiInstance.TitleButton:LocalizeAndSetText(pPanel.Name);
      end
      if pPanel.OnInit then  pPanel:OnInit()  end
    end

    -- table.insert(g_TrackedInstances, uiInstance);
    if pPanel.OnAttach then  pPanel:OnAttach()  end
	end
end


function DetachDynamicUI()
	for i,pPanel in ipairs(g_TrackedItems) do
    if pPanel.OnDetach then  pPanel:OnDetach()  end
  end
end


function OnShutdown()
	DetachDynamicUI()
  BASE_AP_OnShutdown()
end
--]]
