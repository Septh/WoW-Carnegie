
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
local db_defaults = {
	profile = {
		sorting = 1
	},
	char = {
		class = '',
		faction = '',
		level = 0,
		spec = 0,
		garrisons = {},
		artifacts = {
			equipped = 0,
			['*'] = {	-- Pour chaque artifact équippé
				name = '',
				icon = 0,
				tier = 0,
				traits = {
					bought = 0,
					avail  = 0
				},
			},
		},
		currencies = {
			['*'] = {	-- Pour chaque type de garnison
				primary = {
					id     = 0,
					amount = 0
				},
				secondary = {
					id     = 0,
					amount = 0
				}
			}
		},
		missions = {
			['*'] = {	-- Pour chaque type de sujets
				complete   = 0,
				inProgress = 0,
				nextTerm   = math.huge
			}
		},
		shipments = {
			['*'] = {	-- Pour chaque type de garnison
				complete   = 0,
				inProgress = 0,
				nextTerm   = math.huge
			}
		}
	}
}

-------------------------------------------------------------------------------
-- Suivi de l'avancement des missions
-------------------------------------------------------------------------------
local _missions = {}
function Carnegie:GARRISON_MISSION_LIST_UPDATE(evt, followerType)
	-- self:Event(evt, followerType)

	C_Garrison.GetInProgressMissions(_missions, followerType)

	local data = self.db.char.missions[followerType]
	data.complete   = 0
	data.inProgress = 0
	data.nextTerm   = math.huge

	for _,mission in ipairs(_missions) do
		if mission.timeLeftSeconds == 0 then
			data.complete = data.complete + 1
		else
			data.inProgress = data.inProgress + 1
			data.nextTerm   = math.min(data.nextTerm, mission.missionEndTime)
		end
	end
end

-------------------------------------------------------------------------------
-- Suivi de l'arme prodigieuse équipée
-------------------------------------------------------------------------------
function Carnegie:ARTIFACT_UPDATE(evt, ...)
	-- self:Event(evt, ...)

	local itemID, _, name, icon, power, spent, _, _, _, _, _, _, tier = C_ArtifactUI.GetEquippedArtifactInfo()
	if itemID then
		self.db.char.artifacts.equipped = itemID

		local data = self.db.char.artifacts[itemID]
		data.name = name
		data.icon = icon
		data.traits.bought = spent
		data.traits.avail  = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(spent, power, tier)
	else
		self.db.char.artifacts.equipped = 0
	end
end

-------------------------------------------------------------------------------
function Carnegie:ARTIFACT_XP_UPDATE(evt, ...)
	self:ARTIFACT_UPDATE(evt, ...)
end

-------------------------------------------------------------------------------
function Carnegie:PLAYER_EQUIPMENT_CHANGED(evt, slot)
	-- self:Event(evt, slot)

	if slot == INVSLOT_MAINHAND then
		self:ARTIFACT_UPDATE(evt)
	end
end

-------------------------------------------------------------------------------
-- Suivi des ressources
-------------------------------------------------------------------------------
function Carnegie:CURRENCY_DISPLAY_UPDATE(evt)
	self:Event(evt, slot)

	for _,garrType in ipairs(self.db.char.garrisons) do
		local data = self.db.char.currencies[garrType]

		local primary, secondary = C_Garrison.GetCurrencyTypes(garrType)
		if primary then
			data.primary.id = primary
			data.primary.amount = select(2, GetCurrencyInfo(primary))
		else
			data.primary.id = 0
			data.primary.amount = 0
		end
		if secondary then
			data.secondary.id = secondary
			data.secondary.amount = select(2, GetCurrencyInfo(secondary))
		else
			data.secondary.id = 0
			data.secondary.amount = 0
		end
	end
end

-------------------------------------------------------------------------------
-- Suivi de l'accès aux domaines
-------------------------------------------------------------------------------
function Carnegie:GARRISON_SHOW_LANDING_PAGE(evt)
	-- self:Event(evt)

	-- Recense les types de garnisons connus par ce personnage, par ordre décroissant
	wipe(self.db.char.garrisons)
	for garrType = NUM_LE_GARRISON_TYPES, 1, -1 do
		if C_Garrison.GetGarrisonInfo(garrType) then
			table.insert(self.db.char.garrisons, garrType)
		end
	end
end

-------------------------------------------------------------------------------
-- Suivi des caractéristiques du personnage
-------------------------------------------------------------------------------
function Carnegie:ACTIVE_TALENT_GROUP_CHANGED(evt, ...)
	self.db.char.spec = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or 0
end

-------------------------------------------------------------------------------
function Carnegie:PLAYER_LEVEL_UP(evt, level)
	self.db.char.level = level and tonumber(level) or UnitLevel('player')
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Carnegie:OnEnable()

	-- Initialise la base de données
	self.db = LibStub('AceDB-3.0'):New('CarnegieDB', db_defaults, true)

	-- Met à jour les infos sur le personnage actuel
	self.db.char.faction = UnitFactionGroup('player')
	self.db.char.class = select(2, UnitClass('player'))
	self:PLAYER_LEVEL_UP()
	self:ACTIVE_TALENT_GROUP_CHANGED()
	self:GARRISON_SHOW_LANDING_PAGE()
	self:CURRENCY_DISPLAY_UPDATE()
	self:ARTIFACT_UPDATE()

	-- Ecoute les événements
	self:RegisterEvent('PLAYER_LEVEL_UP')
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
	self:RegisterEvent('GARRISON_SHOW_LANDING_PAGE')
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE')
	self:RegisterEvent('ARTIFACT_UPDATE')
	self:RegisterEvent('ARTIFACT_XP_UPDATE')
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
	self:RegisterEvent('GARRISON_MISSION_LIST_UPDATE')
	-- self:RegisterEvent("GARRISON_LANDINGPAGE_SHIPMENTS", 'Event')
	-- self:RegisterEvent("GARRISON_SHIPMENT_RECEIVED",     'Event')

	-- Gestion de la landing page
	self:RegisterEvent('ADDON_LOADED')
	if IsAddOnLoaded('Blizzard_GarrisonUI') then
		self:ADDON_LOADED('ADDON_LOADED', 'Blizzard_GarrisonUI')
	end
	GarrisonLandingPageMinimapButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	self:SecureHookScript(GarrisonLandingPageMinimapButton, 'OnClick', 'GarrisonLandingPageMinimapButton_OnClick')

	-- TODO: A virer
	_G['Carnegie'] = self
end

-------------------------------------------------------------------------------
function Carnegie:OnInitialize()
end

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------
function Carnegie:Dump(...)
	if not IsAddOnLoaded('Blizzard_DebugTools') then UIParentLoadAddOn('Blizzard_DebugTools') end
	DevTools_Dump(...)
end

-------------------------------------------------------------------------------
function Carnegie:Event(evt, ...)
	if evt then self:Print(evt, tostringall(...)) end
end
