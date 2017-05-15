
-- Environnement
local Carnegie = LibStub('AceAddon-3.0'):GetAddon('Carnegie')
local L        = LibStub('AceLocale-3.0'):GetLocale('Carnegie')

-- Données locales
local selfKey = UnitName('player') .. ' - ' .. GetRealmName()
local emptyMH = select(2, GetInventorySlotInfo('MainHandSlot'))

local classIcons = {}
for class, coords in pairs(CLASS_ICON_TCOORDS) do
	local offset, left, right, bottom, top = 0.025, unpack(coords)
	classIcons[class] = string.format([[|TInterface\Glues\CharacterCreate\UI-CharacterCreate-Classes:14:14:0:0:256:256:%s:%s:%s:%s|t]], (left + offset) * 256, (right - offset) * 256, (bottom + offset) * 256, (top - offset) * 256)
end

local classColors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

local CarnegieTabsFrame, orderHallButton, garrisonButton
local mainFrame, mainTab

-------------------------------------------------------------------------------
-- Fonctions utilitaires diverses
-------------------------------------------------------------------------------
local _dash = '-'
local function SplitCharKey(charKey)
	-- return (charKey:gmatch('(%S+) %- (%S+)'))()
	local name, realm = _dash:split(charKey, 2)
	return name:trim(), realm:trim()
end

-------------------------------------------------------------------------------
-- Gestion du choix du rapport
-------------------------------------------------------------------------------
function Carnegie:GarrisonLandingPageMinimapButton_OnClick(frame, mouseButton)
	if GarrisonLandingPage:IsShown() and mouseButton == "RightButton" and mainTab then
		mainTab:Click()
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
function Carnegie:UpdateCharsList()

	local chars = mainFrame.chars
	local numChars = #chars

	local scrollFrame = mainFrame.scrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)

	local buttons = scrollFrame.buttons
	local numButtons = #buttons

	if numChars == 0 then
		-- Affiche un message ?
		scrollFrame:Hide()
		return
	else
		scrollFrame:Show()
	end

	-- Affiche les personnages
	for i = 1, numButtons do
		local button = buttons[i]
		local index  = offset + i
		local key    = chars[index]
		local data   = rawget(self.db, 'sv').char[key]

		button.weight = 0
		button.id     = index
		button.key    = key
		button.data   = data

		if data then
			button:Show()

			-- Icone de classe/spec
			if data.spec then
				local _, _, _, icon = GetSpecializationInfoByID(data.spec)
				button.spec.icon:SetTexCoord(0, 1, 0, 1)
				SetPortraitToTexture(button.spec.icon, icon)
			else
				button.spec.icon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
				button.spec.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[data.class]))
			end

			-- Nom du perso
			local name, realm = SplitCharKey(key)
			button.name.text:SetText(name)
			button.name.text:SetTextColor(classColors[data.class].r, classColors[data.class].g, classColors[data.class].b)

			-- Arme prodigieuse
			if data.artifacts then

				-- Affiche l'icône de l'arme équipée
				button.artifact.ItemIcon:SetTexture(data.artifacts.equipped and GetItemIcon(data.artifacts.equipped) or emptyMH)

				-- Affiche le nombre total de traits achetables, toutes armes confondues
				local avail = 0
				for k,v in pairs(data.artifacts) do
					if type(v) == 'table' and type(v.traits) == 'table' and type(v.traits.avail) == 'number' then
						avail = avail + v.traits.avail
					end
				end

				if avail > 0 then
					button.weight = button.weight + (1000 * avail)

					button.artifact.ItemIcon:SetDesaturated(false)
					button.artifact.ItemIconBorder:SetDesaturated(false)

					button.artifact.ForgeLevelRing:SetDesaturated(false)
					button.artifact.ForgeLevelLabel:SetText(avail)
					button.artifact.ForgeLevelLabel:SetTextColor(1, 0.82, 0)
				else
					button.artifact.ItemIcon:SetDesaturated(true)
					button.artifact.ItemIconBorder:SetDesaturated(true)

					button.artifact.ForgeLevelRing:SetDesaturated(true)
					button.artifact.ForgeLevelLabel:SetText('0')
					button.artifact.ForgeLevelLabel:SetTextColor(0.5, 0.5, 0.5)
				end
			else
				button.artifact.ItemIcon:SetTexture(emptyMH)
				button.artifact.ItemIcon:SetDesaturated(true)
				button.artifact.ItemIconBorder:SetDesaturated(true)

				button.artifact.ForgeLevelRing:SetDesaturated(true)
				button.artifact.ForgeLevelLabel:SetText('0')
				button.artifact.ForgeLevelLabel:SetTextColor(0.5, 0.5, 0.5)
			end

			-- Missions
			if data.missions then
				local done, running = 0, 0
				for k,v in pairs(data.missions) do
					if type(v.complete) == 'number' then
						done = done + v.complete
					end
					if type(v.inProgress) == 'number' then
						running = running + v.inProgress
					end
				end

				self:Printf('Missions pour %q > %d finies, %d en cours', key, done, running)
				if done > 0 then
					button.weight = button.weight + (200 * done) + (100 * running)

					button.missions.icon:SetDesaturated(false)
				else
					button.missions.icon:SetDesaturated(true)
				end
			else
				button.missions.icon:SetDesaturated(true)
			end

			-- Commandes
			for _,b in ipairs(button.Shipments) do
				b.Done:Hide()
				b.Icon:SetAtlas("ClassHall-CombatIcon-Desaturated", true)
			end
		else
			button:Hide()
		end
	end

	-- Trie les boutons
	table.sort(buttons, function(b1, b2)
		return (b1.weight or 0) < (b2.weight or 0)
	end)

	local totalHeight = numChars * scrollFrame.buttonHeight
	local displayedHeight = numButtons * scrollFrame.buttonHeight
	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight)
end

-------------------------------------------------------------------------------
local function GarrisonLandingPageTab_SetTab(self)
	PanelTemplates_DeselectTab(mainTab)
	mainFrame:Hide()
end

-------------------------------------------------------------------------------
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

	mainFrame:Show()
end

-------------------------------------------------------------------------------
-- Attache notre frame à celle de Blizzard
-------------------------------------------------------------------------------
local function _waitForXan()
	Carnegie:ADDON_LOADED('ADDON_LOADED', 'Blizzard_GarrisonUI')
end

function Carnegie:ADDON_LOADED(evt, addonName)
	if addonName == 'Blizzard_GarrisonUI' then
		-- Si xanOrderHalls est chargé, il produit un délai qu'on gère ici...
		if not GarrisonLandingPage then
			C_Timer.After(0.5, _waitForXan)
			return
		end

		-- Boutons de sélection du rapport
		--[[if not CarnegieTabsFrame then
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
			orderHallButton:GetNormalTexture():SetAtlas("legionmission-landingbutton-"..self.layerClass.."-up", true)
			orderHallButton:SetScript('OnClick', CarnegieOrderHallButton_OnClick)
			orderHallButton:SetScript('OnEnter', CarnegieTabButton_OnEnter)
			orderHallButton:Show()

			-- Bouton du fief
			garrisonButton = CreateFrame('CheckButton', 'CarnegieGarrisonTab2', CarnegieTabsFrame, 'SpellBookSkillLineTabTemplate')
			garrisonButton.title = GARRISON_LANDING_PAGE_TITLE
			garrisonButton.description = MINIMAP_GARRISON_LANDING_PAGE_TOOLTIP
			garrisonButton:SetPoint('TOPLEFT', CarnegieTabsFrame, 'RIGHT', -10, -8)
			garrisonButton:GetNormalTexture():SetAtlas("GarrLanding-MinimapIcon-"..self.playerFaction.."-Up", true)
			garrisonButton:SetScript('OnClick', CarnegieGarrisonButton_OnClick)
			garrisonButton:SetScript('OnEnter', CarnegieTabButton_OnEnter)
			garrisonButton:Show()
		end]]

		-- Crée la liste des personnages
		if not mainFrame then
			-- La frame principale
			mainFrame = CreateFrame('Frame', 'CarnegieFrame', GarrisonLandingPage)
			mainFrame:SetAllPoints()
			mainFrame:Hide()

			mainFrame.title = mainFrame:CreateFontString(nil, 'BORDER', 'QuestFont_Enormous')
			mainFrame.title:SetPoint('LEFT', GarrisonLandingPage.HeaderBar, 'LEFT', 26, 0)
			mainFrame.title:SetText(L['Characters'])

			-- La liste défilante
			mainFrame.scrollFrame = CreateFrame('ScrollFrame', 'CarnegieScrollFrame', mainFrame, 'HybridScrollFrameTemplate')
			mainFrame.scrollFrame:SetPoint('TOPLEFT', 45, -96)
			mainFrame.scrollFrame:SetPoint('BOTTOMRIGHT', -41, 36)
			-- mainFrame.scrollFrame:SetScript('OnMouseWheel', nil)

			mainFrame.slider = CreateFrame('Slider', 'CarnegieScrollFrameSlider', mainFrame.scrollFrame, 'MinimalHybridScrollBarTemplate')
			mainFrame.slider:SetPoint('TOPLEFT', mainFrame.scrollFrame, 'TOPRIGHT', -20, -15)
			mainFrame.slider:SetPoint('BOTTOMLEFT', mainFrame.scrollFrame, 'BOTTOMRIGHT', -20, 12)
			mainFrame.slider.doNotHide = true
			mainFrame.slider.trackBG:SetVertexColor(0, 0, 0, 0.75)
			mainFrame.slider.trackBG:Show()

			HybridScrollFrame_CreateButtons(mainFrame.scrollFrame, 'CarnegieCharacterSummaryTemplate', 0, 0)

			-- L'onglet
			mainTab = CreateFrame('Button', 'CarnegieMainTab', GarrisonLandingPage, 'GarrisonLandingPageTabTemplate')
			mainTab:SetPoint('TOPRIGHT', GarrisonLandingPage, 'BOTTOMRIGHT', IsAddOnLoaded('xanOrderHalls') and -150 or -50, 21)
			mainTab:SetText(L['Characters'])
			mainTab:SetScript('OnClick', CarnegieCharTab_OnClick)

			self:SecureHook('GarrisonLandingPageTab_SetTab', GarrisonLandingPageTab_SetTab)

			-- Construit la liste des personnages qu'on va afficher
			mainFrame.chars = {}
			for key, data in pairs(rawget(self.db, 'sv').char) do
				if data.garrisons and key ~= selfKey then
					table.insert(mainFrame.chars, key)
				end
			end

			-- Trie les personnages
			table.sort(mainFrame.chars)	-- TODO
		end

		-- Affiche la liste des personnages
		self:UpdateCharsList()
	end
end
