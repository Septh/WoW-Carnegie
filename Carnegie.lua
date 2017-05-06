
-- Environnement
local Carnegie = LibStub('AceAddon-3.0'):NewAddon('Carnegie', 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')
local L        = LibStub('AceLocale-3.0'):GetLocale('Carnegie')

--[[
	Nom
		Niveau
		Ressources de domaine
		Puissance prodigieuse (traits achetables)
	Missions
	Recherches
		Niveau de connaissances
	Armements
	Troupes 1
	Troupes 2
]]

-- Données locales
local charName    = UnitName('player')
local charRealm   = GetRealmName()
local charKey     = charName .. ' - ' .. charRealm
local charFaction = UnitFactionGroup('player')
local charClass   = select(2, UnitClass('player'))
local charLevel   = UnitLevel('player')

local classIcons = {}
for class, coords in pairs(CLASS_ICON_TCOORDS) do
	local offset, left, right, bottom, top = 0.025, unpack(coords)
	classIcons[class] = string.format([[|TInterface\Glues\CharacterCreate\UI-CharacterCreate-Classes:14:14:0:0:256:256:%s:%s:%s:%s|t]], (left + offset) * 256, (right - offset) * 256, (bottom + offset) * 256, (top - offset) * 256)
end

local classColors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

local CarnegieTabsFrame, orderHallButton, garrisonButton
local CarnegieCharList, CarnegieCharTab

local enCours = {}

local allChars = {}

local db_defaults = {
	profile = {
		sort = 1
	},
	char = {
		missions = {
			['*'] = {
				inProgress = 0,
				complete   = 0
			}
		},
		shipments = {
			['*'] = {
				inProgress = 0,
				complete   = 0
			}
		}
	}
}

-------------------------------------------------------------------------------
-- Fonctions utilitaires diverses
-------------------------------------------------------------------------------
local _dash = '-'
local function SplitCharKey(charKey)
	-- return (charKey:gmatch('(%S+) %- (%S+)'))()
	local realm, name = _dash:split(charKey, 2)
	return realm:trim(), name:trim()
end

-------------------------------------------------------------------------------
-- Gestion du choix du rapport
-------------------------------------------------------------------------------
function Carnegie:GarrisonLandingPageMinimapButton_OnClick(frame, mouseButton)
	if GarrisonLandingPage:IsShown() and mouseButton == "RightButton" and CarnegieCharTab then
		CarnegieCharTab:Click()
	end
end

-------------------------------------------------------------------------------
local function CarnegieOrderHallButton_OnClick()
	orderHallButton:SetChecked(true)
	garrisonButton:SetChecked(false)

	HideUIPanel(GarrisonLandingPage)
	GarrisonThreatCountersFrame:Hide()
	ShowGarrisonLandingPage(LE_GARRISON_TYPE_7_0)
end

-------------------------------------------------------------------------------
local function CarnegieGarrisonButton_OnClick()
	orderHallButton:SetChecked(false)
	garrisonButton:SetChecked(true)

	HideUIPanel(GarrisonLandingPage)
	ShowGarrisonLandingPage(LE_GARRISON_TYPE_6_0)
end

-------------------------------------------------------------------------------
local function CarnegieTabButton_OnEnter(self)
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetText(self.title, 1, 1, 1)
	GameTooltip:AddLine(self.description, nil, nil, nil, true)
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Gestion de la liste des personnages
-------------------------------------------------------------------------------
local function GarrisonLandingPageTab_SetTab(self)
	PanelTemplates_DeselectTab(CarnegieCharTab)
	CarnegieCharList:Hide()
end

local function CarnegieCharTab_OnClick(self)
	PanelTemplates_DeselectTab(GarrisonLandingPageTab1)
	PanelTemplates_DeselectTab(GarrisonLandingPageTab2)
	PanelTemplates_DeselectTab(GarrisonLandingPageTab3)

	PanelTemplates_SelectTab(self)
	GarrisonLandingPage.Report:Hide()
	GarrisonLandingPage.FollowerList:Hide()
	GarrisonLandingPage.FollowerTab:Hide()
	GarrisonLandingPage.ShipFollowerList:Hide()
	GarrisonLandingPage.ShipFollowerTab:Hide()

	CarnegieCharList:Show()
end

-------------------------------------------------------------------------------
-- Gestion des événements
-------------------------------------------------------------------------------
function Carnegie:ADDON_LOADED(evt, addonName)
	if addonName == 'Blizzard_GarrisonUI' then
		if not GarrisonLandingPage then
			C_Timer.After(0.5, function() Carnegie:ADDON_LOADED(nil, 'Blizzard_GarrisonUI') end)
			return
		end

		-- Boutons de sélection du rapport
--[[		if not CarnegieTabsFrame then
			RaiseFrameLevel(GarrisonLandingPage)

			CarnegieTabsFrame = CreateFrame('Frame', 'CarnegieTabsFrame', GarrisonLandingPage)
			CarnegieTabsFrame:SetAllPoints()
			CarnegieTabsFrame:SetFrameLevel(GarrisonLandingPage:GetFrameLevel() - 1)
			-- CarnegieTabsFrame.bg = CarnegieTabsFrame:CreateTexture(nil, 'BACKGROUND')
			-- CarnegieTabsFrame.bg:SetAllPoints()
			-- CarnegieTabsFrame.bg:SetColorTexture(1, 0, 0, 0.25)

			-- Bouton du domaine de classe
			orderHallButton = CreateFrame('CheckButton', 'CarnegieGarrisonTab1', CarnegieTabsFrame, 'SpellBookSkillLineTabTemplate')
			orderHallButton.title = ORDER_HALL_LANDING_PAGE_TITLE
			orderHallButton.description = MINIMAP_ORDER_HALL_LANDING_PAGE_TOOLTIP
			orderHallButton:SetPoint('BOTTOMLEFT', CarnegieTabsFrame, 'RIGHT', -10, 8)
			orderHallButton:GetNormalTexture():SetAtlas("legionmission-landingbutton-"..charClass.."-up", true)
			orderHallButton:SetScript('OnClick', CarnegieOrderHallButton_OnClick)
			orderHallButton:SetScript('OnEnter', CarnegieTabButton_OnEnter)
			orderHallButton:Show()

			-- Bouton du fief
			garrisonButton = CreateFrame('CheckButton', 'CarnegieGarrisonTab2', CarnegieTabsFrame, 'SpellBookSkillLineTabTemplate')
			garrisonButton.title = GARRISON_LANDING_PAGE_TITLE
			garrisonButton.description = MINIMAP_GARRISON_LANDING_PAGE_TOOLTIP
			garrisonButton:SetPoint('TOPLEFT', CarnegieTabsFrame, 'RIGHT', -10, -8)
			garrisonButton:GetNormalTexture():SetAtlas("GarrLanding-MinimapIcon-"..charFaction.."-Up", true)
			garrisonButton:SetScript('OnClick', CarnegieGarrisonButton_OnClick)
			garrisonButton:SetScript('OnEnter', CarnegieTabButton_OnEnter)
			garrisonButton:Show()
		end
]]
		-- Liste des personnages
		if not CarnegieCharList then
			-- Frame principale
			CarnegieCharList = CreateFrame('Frame', 'CarnegieCharList', GarrisonLandingPage)
			CarnegieCharList:SetAllPoints()
			CarnegieCharList:Hide()
			-- local bg = CarnegieCharList:CreateTexture(nil, 'BACKGROUND')
			-- bg:SetAllPoints()
			-- bg:SetColorTexture(1, 0, 0, 0.25)

			CarnegieCharList.title = CarnegieCharList:CreateFontString(nil, 'BORDER', 'QuestFont_Enormous')
			CarnegieCharList.title:SetPoint('LEFT', GarrisonLandingPage.HeaderBar, 'LEFT', 26, 0)
			CarnegieCharList.title:SetText(L['Characters'])

			-- Liste
			CarnegieCharList.scrollFrame = CreateFrame('ScrollFrame', nil, CarnegieCharList, 'HybridScrollFrameTemplate')
			CarnegieCharList.scrollFrame:SetPoint('TOPLEFT', 45, -96)
			CarnegieCharList.scrollFrame:SetPoint('BOTTOMRIGHT', -41, 36)
			CarnegieCharList.scrollFrame:SetScript('OnMouseWheel', nil)

			local bar = CreateFrame('Slider', nil, CarnegieCharList.scrollFrame, 'MinimalHybridScrollBarTemplate')
			bar:SetPoint('TOPLEFT', CarnegieCharList.scrollFrame, 'TOPRIGHT', -20, -15)
			bar:SetPoint('BOTTOMLEFT', CarnegieCharList.scrollFrame, 'BOTTOMRIGHT', -20, 12)
			bar.doNotHide = true
			bar.trackBG:SetVertexColor(0, 0, 0, 0.75)
			bar.trackBG:Show()

			-- HybridScrollFrame_CreateButtons(CarnegieCharList.scrollFrame, 'CarnegieCharacterSummaryTemplate', 0, 0)

			-- Onglet
			CarnegieCharTab = CreateFrame('Button', 'CarnegieCharTab', GarrisonLandingPage, 'GarrisonLandingPageTabTemplate')
			-- CarnegieCharTab:SetPoint('TOPLEFT', GarrisonLandingPage, 'BOTTOMRIGHT', -150, 21)
			CarnegieCharTab:SetPoint('TOP', GarrisonLandingPage, 'BOTTOM', 0, 21)
			CarnegieCharTab:SetText(L['Characters'])
			CarnegieCharTab:SetScript('OnClick', CarnegieCharTab_OnClick)

			self:SecureHook('GarrisonLandingPageTab_SetTab', GarrisonLandingPageTab_SetTab)
		end

		-- Test
		local sv, top = rawget(self.db, 'sv'), 0
		for charKey, charData in pairs(sv.char) do
			local name, realm = SplitCharKey(charKey)

			local x = CreateFrame('Button', nil, CarnegieCharList.scrollFrame, 'CarnegieCharacterSummaryTemplate')
			x:SetPoint('TOPLEFT', 0, top)
			top = top - x:GetHeight() - 2

			-- Icone de classe/spec
			if charData.spec then
				local _, _, _, icon = GetSpecializationInfoByID(charData.spec)
				x.spec.icon:SetTexCoord(0, 1, 0, 1)
				SetPortraitToTexture(x.spec.icon, icon)
			else
				x.spec.icon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
				x.spec.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[charData.class]))
			end

			-- Nom du perso
			x.name.text:SetText(name)
			x.name.text:SetTextColor(classColors[charData.class].r, classColors[charData.class].g, classColors[charData.class].b)

			-- Missions

			-- Commandes
			for _,b in ipairs(x.Shipments) do
				-- b.Done:Hide()
				b.Icon:SetAtlas("ClassHall-CombatIcon-Desaturated", true)
			end
		end
	end
end

-------------------------------------------------------------------------------
function Carnegie:GARRISON_MISSION_LIST_UPDATE(evt, followerType)

	C_Garrison.GetInProgressMissions(enCours, followerType)

	local data = self.db.char.missions[followerType]
	data.inProgress = 0
	data.complete = 0

	for _,mission in ipairs(enCours) do
		if mission.timeLeftSeconds > 0 then
			data.inProgress = data.inProgress + 1
		else
			data.complete = data.complete + 1
		end
	end
end

-------------------------------------------------------------------------------
function Carnegie:PLAYER_LEVEL_UP(evt, level)
	self.db.char.level = level and tonumber(level) or UnitLevel('player')
end

-------------------------------------------------------------------------------
function Carnegie:ACTIVE_TALENT_GROUP_CHANGED(evt, ...)
	self.db.char.spec = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or nil
end

-------------------------------------------------------------------------------
function Carnegie:Event(evt, ...)
	self:Printf('%q %s', evt or 'nil', strjoin(" ", tostringall(... or {})))
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Carnegie:OnEnable()

	-- Crée la base de données
	self.db = LibStub('AceDB-3.0'):New('CarnegieDB', db_defaults, true)
	self.db.char.faction = charFaction
	self.db.char.class = charClass
	self:PLAYER_LEVEL_UP()
	self:ACTIVE_TALENT_GROUP_CHANGED()

	-- Recense tous les personnages connus
	for key in pairs(rawget(self.db, 'sv').char) do
		table.insert(allChars, key)
	end

	-- Ecoute les événements
	self:RegisterEvent('PLAYER_LEVEL_UP')
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	self:RegisterEvent("GARRISON_MISSION_LIST_UPDATE")
	-- self:RegisterEvent("GARRISON_LANDINGPAGE_SHIPMENTS", 'Event')
	-- self:RegisterEvent("GARRISON_SHIPMENT_RECEIVED",     'Event')
	self:RegisterEvent('ADDON_LOADED')
	if IsAddOnLoaded('Blizzard_GarrisonUI') then
		self:ADDON_LOADED(nil, 'Blizzard_GarrisonUI')
	end

	-- Affichage du rapport
	GarrisonLandingPageMinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self:SecureHookScript(GarrisonLandingPageMinimapButton, 'OnClick', 'GarrisonLandingPageMinimapButton_OnClick')

	-- TODO: A virer
	_G["Carnegie"] = self
end

-------------------------------------------------------------------------------
function Carnegie:OnInitialize()
end
