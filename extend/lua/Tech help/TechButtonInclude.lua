--==========================================================
-- Include file that has handy stuff for the tech tree
-- and other screens that need to show a tech button
-- Re-written by bc1 using Notepad++
--==========================================================

if not GameInfoCache then
	include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
end
local GameInfo = GameInfoCache

include "IconHookup"
local IconHookup = IconHookup

local IsCiv5 = type( MouseOverStrategicViewResource ) == "function"
local IsCivBE = not IsCiv5
local gk_mode = Game.GetReligionName ~= nil
local bnw_mode = Game.GetActiveLeague ~= nil

--==========================================================
-- Minor lua optimizations
--==========================================================
local tonumber = tonumber
local tostring = tostring
local unpack = unpack
local insert = table.insert

local UI = UI
local DomainTypes = DomainTypes
local Events = Events
local SearchForPediaEntry = Events.SearchForPediaEntry.Call
local Mouse = Mouse
local Locale = Locale
local L = Locale.ConvertTextKey

local ORDER_TRAIN = OrderTypes.ORDER_TRAIN
local ORDER_CONSTRUCT = OrderTypes.ORDER_CONSTRUCT
local ORDER_CREATE = OrderTypes.ORDER_CREATE
local ORDER_MAINTAIN = OrderTypes.ORDER_MAINTAIN

local g_OrderInfo = {
	[ORDER_TRAIN] = GameInfo.Units,
	[ORDER_CONSTRUCT] = GameInfo.Buildings,
	[ORDER_CREATE] = GameInfo.Projects,
	[ORDER_MAINTAIN] = GameInfo.Processes,
	[11] = GameInfo.Resources,
	[12] = GameInfo.Builds,
	[13] = GameInfo.Missions,
	[15] = IsCivBE and GameInfo.PlayerPerks,
}
-- the following need to be GLOBAL
techPediaSearchStrings = {}
g_searchTable = {}	-- holds mapping of searchable words to techs for Civ BE (unused in this script)
g_recentlyAddedUnlocks = {}
turnsString = L"TXT_KEY_TURNS"
freeString = L"TXT_KEY_FREE"
lockedString = "[ICON_LOCKED]" --L"TXT_KEY_LOCKED"

local g_AffinityInfo = IsCivBE and {
	AFFINITY_TYPE_PURITY	= { 0, "AFFINITY_ATLAS_TECHWEB", "TXT_KEY_TECHWEB_AFFINITY_ADDS_PURITY" },
	AFFINITY_TYPE_SUPREMACY	= { 1, "AFFINITY_ATLAS_TECHWEB", "TXT_KEY_TECHWEB_AFFINITY_ADDS_SUPREMACY" },
	AFFINITY_TYPE_HARMONY	= { 2, "AFFINITY_ATLAS_TECHWEB", "TXT_KEY_TECHWEB_AFFINITY_ADDS_HARMONY" },
}

local g_civType

function GetTechPedia( techID, void2, button )
	SearchForPediaEntry( techPediaSearchStrings[tostring(button)] )
end

local function doNothing() end

local function registerPediaCallback( button, row )
	local entry = row and row.Type
	if button and entry then
		if entry:sub(1,6) == "BUILD_" then
			row = GameInfo.Improvements[ row.ImprovementType ] or GameInfo.Routes[ row.RouteType ] or GameInfo.Concepts.CONCEPT_WORKERS_CLEARINGLAND -- we are a choppy thing

		elseif entry:sub(1,8) =="MISSION_" then
			if entry == "MISSION_EMBARK" then
				row = GameInfo.Concepts.CONCEPT_MOVEMENT_EMBARKING
			elseif entry == "MISSION_ROUTE_TO" then
				row = GameInfo.Concepts.CONCEPT_WORKERS_ROADS_TRADE_ROUTES
			elseif entry == "MISSION_ESTABLISH_TRADE_ROUTE" then
				row = GameInfo.Concepts.CONCEPT_TRADE_ROUTES
			else
				row = nil
			end

		elseif entry:sub(1,10) == "TERRAFORM_" then -- IsCivBE only
			if entry == "TERRAFORM_ADD_MIASMA" then
				row = GameInfo.Concepts.CONCEPT_WORKERS_PLACE
			elseif entry == "TERRAFORM_CLEAR_MIASMA" then
				row = GameInfo.Concepts.CONCEPT_WORKERS_REMOVE
			else
				row = GameInfo.Features[ row.FeatureTypeChange ] or GameInfo.Terrains[ row.TerrainTypeChange ]
			end
		end

		entry = row and row._Name
		if entry then
			return button:RegisterCallback( Mouse.eRClick, function() SearchForPediaEntry( entry ) end )
		end
	end
	button:ClearCallback( Mouse.eRClick )
end

function GatherInfoAboutUniqueStuff( civType )
	g_civType = civType
	-- kludge to prevent TECH PANEL opening upon ButtonPopupTypes.BUTTONPOPUP_CHOOSETECH
	if OnOpenInfoCorner and OnPopup then
		Events.SerialEventGameMessagePopup.Remove( OnPopup )
		OnPopup = nil
	end
end

local function PediaCallback( techID, itemID )
	local orderID = itemID%16
	itemID = (itemID - orderID)/16
	local row = g_OrderInfo[orderID]
	row = row and row[itemID]
	if row then
		if orderID==12 then
			row = GameInfo.Improvements[ row.ImprovementType ] or GameInfo.Routes[ row.RouteType ] or GameInfo.Concepts.CONCEPT_WORKERS_CLEARINGLAND -- we are a choppy thing
		elseif orderID==ORDER_MAINTAIN then
			row = GameInfo.Technologies[ row.TechPrereq ]
		end
	end
print( "SearchForPediaEntry", itemID, orderID, row, row and row.Description )
	return SearchForPediaEntry( row and row.Description )
end

local TechButtonTooltipCall = LuaEvents.TechButtonTooltip.Call

local function ToolTipCallback( button )
	local itemID = button:GetVoid2()
	local orderID = itemID%16
	return TechButtonTooltipCall( orderID, (itemID - orderID)/16 )
end

local function ToolTipSetup( button )
	button:SetToolTipCallback( ToolTipCallback )
	button:SetToolTipType( "EUI_ItemTooltip" )
end



local YieldIcons = {}
local validUnitBuilds = {}
local validBuildingBuilds = {}
local validImprovementBuilds = {}

do
	local DB_Query = DB.Query
	for row in Game and GameInfo.Yields() or DB_Query("SELECT * from Yields") do
		YieldIcons[row.ID or false] = row.IconString
		YieldIcons[row.Type or false] = row.IconString
	end
	YieldIcons.YIELD_CULTURE = YieldIcons.YIELD_CULTURE or "[ICON_CULTURE]"
	YieldIcons.YIELD_ELECTRICITY = "[ICON_RES_ELECTRICITY]"
	YieldIcons.YIELD_TOURISM = "[ICON_TOURISM]"
end


local g_buttonItemInfo = {}

--==========================================================
--	Has a few assumptions:
--		1.) the small buttons are named "B1", "B2", "B3"
--		2.) GatherInfoAboutUniqueStuff() has been called before this
--
--	ARGS:
--	thisTechButtonInstance,	UI element
--	tech,					data structure with technology info
--	maxSmallButtonSize		no more than this many buttons will be populated
--	textureSize
--	startingButtoNum,		(optional) 1, but will use this instead if set
--
--	RETURNS: the # of small buttons added
--==========================================================

function AddSmallButtonsToTechButton( thisTechButtonInstance, tech, maxSmallButtons, textureSize, startingButtonNum )

	local techType = tech and tech.Type

	if not techType then
		return 0
	end

	-- temporary used (e.g., search populating)
	g_recentlyAddedUnlocks = {}
	local civType = g_civType
	local buttonNum = startingButtonNum or 1
	local thisPrereqTech = { PrereqTech = techType }
	local thisTechPrereq = { TechPrereq = techType }
	local thisTechType = { TechType = techType }

	local function addSmallButtonWithPedia( index, atlas, row, ... )
		local button = thisTechButtonInstance["B"..buttonNum]
		if button then
			button:SetToolTipCallback( doNothing )
			button:SetToolTipType()
			registerPediaCallback( button, row )
			IconHookup( index or 0, textureSize, atlas or "GENERIC_FUNC_ATLAS", button )
			if ... then
				button:LocalizeAndSetToolTip( ... )
			else
				button:SetToolTipString( "missing tooltip" )
			end
			button:SetText("")
			buttonNum = buttonNum + 1
			return button
		end
	end

	local function addSmallButton( index, atlas, ... )
		return addSmallButtonWithPedia( index, atlas, nil, ... )
	end

	local function addSmallGenericButton( ... )
		return addSmallButtonWithPedia( 0, "GENERIC_FUNC_ATLAS", nil, ... )
	end
	local function addSmallGenericButtonIF( ... )
		if ... then
			return addSmallButtonWithPedia( 0, "GENERIC_FUNC_ATLAS", nil, ... )
		end
	end
	local function NZ( n )
		return (tonumber(n) or 0) ~= 0
	end
	local function addSmallGenericButtonNZ( n, s )
		if NZ(n) then
			return addSmallButtonWithPedia( 0, "GENERIC_FUNC_ATLAS", nil, s, n )
		end
	end



	--------------------------定义科技树中圆圈动图
	local function addSmallArtButton( row, orderID, portraitOffset, portraitAtlas )
		if row then
			insert( g_recentlyAddedUnlocks, row._Name )
			local button = thisTechButtonInstance["B"..buttonNum]
			if button then
				button:SetText("")
				button:SetVoid2( row.ID*16 + orderID )
				button:SetToolTipCallback( ToolTipSetup ) ----调取文本
				button:RegisterCallback( Mouse.eRClick, PediaCallback )  ----调取大文本界面
				IconHookup( portraitOffset or row.PortraitIndex or row.IconIndex or 0, textureSize, portraitAtlas or row.IconAtlas or "GENERIC_FUNC_ATLAS", button )
				buttonNum = buttonNum + 1
				return button
			end
		else
			return addSmallGenericButton( "unknown item" )
		end
	end


		local function addSmallArtYieldButton(row, icons, toolTip)
		if row then
			local button = thisTechButtonInstance["B"..buttonNum]
			if button then
				table.insert( g_recentlyAddedUnlocks, row.Description )
				button:SetToolTipString( toolTip )
				button:ClearCallback( Mouse.eMouseEnter )
				g_buttonItemInfo[tostring(button)] = row
				button:RegisterCallback( Mouse.eRClick, GetTechPedia )
				IconHookup( row.PortraitIndex, textureSize, row.IconAtlas or "GENERIC_FUNC_ATLAS", button )
				buttonNum = buttonNum + 1
				button:GetTextControl():SetOffsetY( textureSize/3 )
				button:GetTextControl():SetAlpha( 0.8 )
				button:SetText( icons or "" )
				return button
			end
		end
	end


	local function addSmallActionButton( row, icons, ... )
		local button
		if row then
--print( "addSmallActionButton", tech._Name, row._Name, icons, ... )
			insert( g_recentlyAddedUnlocks, row._Name )
			button = thisTechButtonInstance["B"..buttonNum]
			if button then
				button:SetToolTipCallback( doNothing )
				button:SetToolTipType()
				button:LocalizeAndSetToolTip( ... )
				registerPediaCallback( button, row )
				IconHookup( row.IconIndex or row.PortraitIndex or 0, textureSize, row.IconAtlas or "GENERIC_FUNC_ATLAS", button )
				buttonNum = buttonNum + 1
			end
		else
			button = addSmallGenericButton( ... )
		end
		if button then
			button:GetTextControl():SetOffsetY( textureSize/3 )
			button:GetTextControl():SetAlpha( 0.8 )
			button:SetText( icons or "" )
			return button
		end
	end


	----------------------------科技解锁的单位
	-- units unlocked by this tech
	local overrideSearch = {CivilizationType = civType}
	local override, ok, improvement, yield
	for row in GameInfo.Units( thisPrereqTech ) do
		--CivilizationType, UnitClassType, UnitType

		if row.ShowInTechTree==1 then
		overrideSearch.UnitClassType = row.Class
		override = GameInfo.Civilization_UnitClassOverrides(overrideSearch)()
		if override then
			ok = override.UnitType == row.Type
		else
			ok = GameInfo.UnitClasses[ row.Class ]
			ok = ok and ok.DefaultUnit == row.Type
		end
		if ok and not addSmallArtButton( row, ORDER_TRAIN, UI.GetUnitPortraitIcon(row.ID) ) then
			break
		   end
	   end
	end
	overrideSearch.UnitClassType = nil







	-- buildings and wonders unlocked by this tech
	for row in GameInfo.Buildings( thisPrereqTech ) do
		--CivilizationType, BuildingClassType, BuildingType
		overrideSearch.BuildingClassType = row.BuildingClass
		override = GameInfo.Civilization_BuildingClassOverrides(overrideSearch)()
		if override then
			ok = override.BuildingType == row.Type
		else
			ok = GameInfo.BuildingClasses[ row.BuildingClass ]
			ok = ok and ok.DefaultBuilding == row.Type
		end
		if ok and not addSmallArtButton( row, ORDER_CONSTRUCT ) then
			break
		end
	end

	-- resources revealed by this tech
	for row in GameInfo.Resources{ TechReveal = techType } do
		if not addSmallArtButton( row, 11 ) then
			break
		end
	end

	-- projects unlocked by this tech
	for row in GameInfo.Projects( thisTechPrereq ) do
		if not addSmallArtButton( row, ORDER_CREATE ) then
			break
		end
	end

	-- actions enabled by this tech (usually only workers can do these)
	for row in GameInfo.Builds( thisPrereqTech ) do
		if row.ShowInTechTree ~= false then
			improvement = GameInfo.Improvements[ row.ImprovementType ]
			if (not improvement or not improvement.SpecificCivRequired or improvement.CivilizationType == civType) and not addSmallArtButton( row, 12 ) then
				break
			end
		end
	end

	-- processes unlocked by this tech
	for row in GameInfo.Processes( thisTechPrereq ) do
		if not addSmallArtButton( row, ORDER_MAINTAIN ) then
			break
		end
	end

	-- todo: need to add abilities, etc.
	-- Player Perk unlocks

	for row in GameInfo.Route_TechMovementChanges( thisTechType ) do
		row = GameInfo.Routes[row.RouteType]
		if row and not addSmallActionButton( GameInfo.Builds{ RouteType = row.Type }(), "[ICON_MOVES]", "TXT_KEY_FASTER_MOVEMENT", row._Name ) then
			break
		end
	end



	---------------------------------------------新增----------------------------------------------
	-- Some improvements can have multiple yield changes, group them and THEN add buttons.
	local improvementTypesChanged = {}
	for row in GameInfo.Improvement_TechYieldChanges( thisTechType ) do
		local thisImprovement = GameInfo.Improvements[ row.ImprovementType ]
		if thisImprovement and (not thisImprovement.CivilizationType or thisImprovement.CivilizationType == civType) then
			improvementTypesChanged[ row.ImprovementType or -1 ] = true
		end
	end
	-- Let's sort the yield change buttons!
	local sortedImprovements = {}
	for improvementType in pairs( improvementTypesChanged ) do
	    table.insert( sortedImprovements,GameInfo.Improvements[ improvementType ] )
		--sortedImprovements:insertIf( GameInfo.Improvements[ improvementType ] )
	end
	table.sort( sortedImprovements, function(a,b) return Locale.Compare(a.Description or "", b.Description or "") == -1 end )

	local thisTechAndImprovementTypes = { TechType = techType }
	for i,improvement in ipairs( sortedImprovements ) do
		local toolTip = Locale.ConvertTextKey( improvement.Description or "???" )
		local icons = ""
		thisTechAndImprovementTypes.ImprovementType = improvement.Type
		for row in GameInfo.Improvement_TechYieldChanges( thisTechAndImprovementTypes ) do
			if (row.Yield or 0)~=0 then
				local icon = YieldIcons[row.YieldType] or "???"
				icons = icons .. icon
				toolTip = toolTip .. (" +%g"):format(row.Yield) .. icon
			end
		end
		if not addSmallActionButton( GameInfo.Builds{ ImprovementType = improvement.Type }() or "???", icons, toolTip ) then
			break
		end
	end
	
	----------------------------------------------end----------------------------------------------
	

	for row in GameInfo.Improvement_TechNoFreshWaterYieldChanges( thisTechType ) do
		yield = GameInfo.Yields[row.YieldType]
		improvement = GameInfo.Improvements[row.ImprovementType]
		if yield and not addSmallActionButton( GameInfo.Builds{ ImprovementType = row.ImprovementType }(), yield.IconString,
				"TXT_KEY_NO_FRESH_WATER", improvement and improvement._Name or "?", yield._Name, row.Yield )
		then
			break
		end
	end

	for row in GameInfo.Improvement_TechFreshWaterYieldChanges( thisTechType ) do
		yield = GameInfo.Yields[row.YieldType]
		improvement = GameInfo.Improvements[row.ImprovementType]
		if yield and not addSmallActionButton( GameInfo.Builds{ ImprovementType = row.ImprovementType }(), yield.IconString,
				"TXT_KEY_FRESH_WATER", improvement and improvement._Name or "?", yield._Name, row.Yield )
		then
			break
		end
	end

	-- buildings yields improved by this tech
	for row in GameInfo.Buildings{ EnhancedYieldTech = techType } do
		--CivilizationType, BuildingClassType, BuildingType
		overrideSearch.BuildingClassType = row.BuildingClass
		override = GameInfo.Civilization_BuildingClassOverrides(overrideSearch)()
		if override then
			ok = override.BuildingType == row.Type
		else
			ok = GameInfo.BuildingClasses[ row.BuildingClass ]
			ok = ok and ok.DefaultBuilding == row.Type
		end
		if ok then
			local toolTip = row._Name
			local icons = ""
			local icon
			for row in GameInfo.Building_TechEnhancedYieldChanges{ BuildingType = row.Type } do
			-- BuildingType, YieldType, Yield
				if NZ(row.Yield) then
					icon = GameInfo.Yields[row.YieldType]
					icon = icon and icon.IconString or "?"
					icons = icons .. icon
					toolTip = ("%s %+i%s"):format( toolTip, row.Yield, icon )
				end
			end
			if icon and not addSmallActionButton( row, icons, toolTip ) then
				break
			end
		end
	end



	---------------------------------------------新增单位战力------------------------------------------------------------
	  for row in GameInfo.Unit_TechCombatStrength( thisTechType ) do
			local Unit = GameInfo.Units[row.UnitType]
			local icons = ""
			local toolTip = ""
			local toolTip2 = -1
        
             if  Unit then    -----未改变近战力

			    icons = "[ICON_STRENGTH]" 				
			    for row2 in GameInfo.Unit_TechRangedCombatStrength( thisTechType ) do
				local Unit2 = GameInfo.Units[row2.UnitType]
				if(Unit2~= nil and  row2.UnitType == row.UnitType ) then
				local icon = "[ICON_RANGE_STRENGTH]" or "???"
				icons = icons .. icon
				toolTip2 = Locale.ConvertTextKey("TXT_KEY_EUI_TECH_YIELD_UNIT_RANGED_COMBATSTRENGTH", Unit2.Description, row2.RangedCombatStrength)			
				    end
				end

				if toolTip2~= -1 then
				toolTip = toolTip2 .. "[NEWLINE]".. Locale.ConvertTextKey("TXT_KEY_EUI_TECH_YIELD_UNIT_COMBATSTRENGTH", Unit.Description, row.CombatStrength)
				else
				toolTip = toolTip.. Locale.ConvertTextKey("TXT_KEY_EUI_TECH_YIELD_UNIT_COMBATSTRENGTH", Unit.Description, row.CombatStrength)
				end			
			    addSmallArtYieldButton(Unit, icons, toolTip)
		    end
        end


		for row in GameInfo.Unit_TechRangedCombatStrength( thisTechType ) do
			local Unit = GameInfo.Units[row.UnitType]
			local icons = ""
			local toolTip = ""
			local toolTip2 = -1       
             if  Unit then  
			    icons = "[ICON_RANGE_STRENGTH]"				
			    for row2 in GameInfo.Unit_TechCombatStrength( thisTechType ) do
				local Unit2 = GameInfo.Units[row2.UnitType]
				if(Unit2~= nil and  row2.UnitType == row.UnitType ) then
				        toolTip2=1
				    end
				end
				if toolTip2~=1 then
				toolTip = toolTip ..Locale.ConvertTextKey("TXT_KEY_EUI_TECH_YIELD_UNIT_RANGED_COMBATSTRENGTH", Unit.Description, row.RangedCombatStrength)
				addSmallArtYieldButton(Unit, icons, toolTip)	
				end								    
		    end
        end


	---------------------------------------------新增------------------------------------------------------------
	for row in GameInfo.Tech_SpecialistYieldChanges( thisTechType ) do
			local specialist = GameInfo.Specialists[row.SpecialistType]
			if specialist then
				local icons = ""
				local toolTip = ""
				for row2 in GameInfo.Tech_SpecialistYieldChanges( thisTechType ) do
					if(row2.SpecialistType == row.SpecialistType) then
						local yield = GameInfo.Yields[row2.YieldType]
						if yield and (row2.Yield > 0) then
							local icon = YieldIcons[row2.YieldType] or "???"
							icons = icons .. icon
							toolTip = toolTip .. Locale.ConvertTextKey("TXT_KEY_EUI_SPECIALIST_YIELD_CHANGE", specialist.Description, yield.Description, row2.Yield, yield.IconString)
						end
					end
				end
				addSmallArtYieldButton(specialist, icons, toolTip)
			end
		end


	for row in GameInfo.Specialist_Resources({ RequiredTechType = techType }) do
			local specialist = GameInfo.Specialists[row.SpecialistType]
			if specialist then
				local icons = ""
				local toolTip = ""
				for row2 in GameInfo.Specialist_Resources( { RequiredTechType = techType }) do
					if(row2.SpecialistType == row.SpecialistType) then
						local Resource = GameInfo.Resources[row2.ResourceType]
						if Resource and (row2.Quantity > 0) then
							local icon = Resource.IconString or "???"
							icons = icons .. icon
							toolTip = toolTip .. Locale.ConvertTextKey("TXT_KEY_EUI_SPECIALIST_YIELD_CHANGE", specialist.Description, Resource.Description, row2.Quantity, Resource.IconString)
						end
					end
				end
				addSmallArtYieldButton(specialist, icons, toolTip)
			end
		end
	---------------------------------------------end------------------------------------------------------------



	if NZ(tech.EmbarkedMoveChange) then
		addSmallActionButton( GameInfo.Missions.MISSION_EMBARK, "+"..tech.EmbarkedMoveChange.."[ICON_MOVES]", "TXT_KEY_FASTER_EMBARKED_MOVEMENT" )
	end

	if tech.AllowsEmbarking then
		addSmallActionButton( GameInfo.Missions.MISSION_EMBARK, "", "TXT_KEY_ALLOWS_EMBARKING" )
	end

	----新增
	if tech.BombardIndirect~=0 then
	   addSmallActionButton( GameInfo.Missions.MISSION_RANGE_ATTACK, "", "TXT_KEY_CITY_BOMBARDMENT_MOD" )
	end
	---end

	if IsCiv5 then
		if tech.AllowsDefensiveEmbarking then
			addSmallActionButton( GameInfo.Missions.MISSION_EMBARK, "[ICON_STRENGTH]", "TXT_KEY_ABLTY_DEFENSIVE_EMBARK_STRING" )
		end
		if tech.EmbarkedAllWaterPassage then
		  addSmallButton( 24, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_ALLOWS_CROSSING_OCEANS" )
		end
	end
	if gk_mode then
		if NZ(tech.UnitFortificationModifier) then
			addSmallActionButton( GameInfo.Missions.MISSION_FORTIFY, "", "TXT_KEY_UNIT_FORTIFICATION_MOD", tech.UnitFortificationModifier )
		end
		if NZ(tech.UnitBaseHealModifier) then
			addSmallActionButton( GameInfo.Missions.MISSION_HEAL, "", "TXT_KEY_UNIT_BASE_HEAL_MOD", tech.UnitBaseHealModifier )
		end
		if tech.AllowEmbassyTradingAllowed then
		    addSmallButton( 26, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_ALLOWS_OPEN_BORDERS" )
		end
	end
	if IsCiv5 then
		if tech.OpenBordersTradingAllowed then
			addSmallActionButton( GameInfo.Missions.MISSION_SWAP_UNITS, "", "TXT_KEY_ALLOWS_OPEN_BORDERS" ) --[COLOR_GREEN]<>
		end
		if tech.DefensivePactTradingAllowed then
		    addSmallButton( 29, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_ALLOWS_DEFENSIVE_PACTS" )
		end
		if tech.ResearchAgreementTradingAllowed then
			addSmallActionButton( GameInfo.Missions.MISSION_DISCOVER, "", "TXT_KEY_ALLOWS_RESEARCH_AGREEMENTS" ) --[ICON_RESEARCH]
		end
		if tech.TradeAgreementTradingAllowed then
			addSmallActionButton( nil, "[ICON_TRADE]", "TXT_KEY_ALLOWS_TRADE_AGREEMENTS" )
		end
		if tech.BridgeBuilding then
		    addSmallButton( 21, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_ALLOWS_OPEN_BORDERS" )
		end
	else
		addSmallGenericButtonIF( tech.AllianceTradingAllowed and "TXT_KEY_ALLOWS_ALLIANCES" )
		addSmallGenericButtonNZ( tech.UnitBaseMiasmaHeal, "TXT_KEY_BASE_MIASMA_HEAL" )
	end

	if tech.MapVisible then
	     addSmallButton(33, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_REVEALS_ENTIRE_MAP" )
	end

	if bnw_mode then
		if NZ(tech.InternationalTradeRoutesChange) then
			addSmallActionButton( GameInfo.Missions.MISSION_ESTABLISH_TRADE_ROUTE, ("%+i   "):format( tech.InternationalTradeRoutesChange ), "TXT_KEY_ADDITIONAL_INTERNATIONAL_TRADE_ROUTE" )
		end

		for row in GameInfo.Technology_TradeRouteDomainExtraRange( thisTechType ) do
			if row.TechType == techType and NZ(row.Range) then
				local toolTip = "?"
				local domain = GameInfo.Domains[ row.DomainType ]
				if domain then
					if domain.ID == DomainTypes.DOMAIN_LAND then
						toolTip = "TXT_KEY_EXTENDS_LAND_TRADE_ROUTE_RANGE"
					elseif domain.ID == DomainTypes.DOMAIN_SEA then
						toolTip = "TXT_KEY_EXTENDS_SEA_TRADE_ROUTE_RANGE"
					end
					if not addSmallActionButton( GameInfo.Missions.MISSION_ESTABLISH_TRADE_ROUTE, ("%+i%%  "):format( row.Range ), toolTip ) then --[ICON_RANGE_STRENGTH]
						break
					end
				end
			end
		end

		if IsCiv5 then
			if NZ(tech.InfluenceSpreadModifier) then
				addSmallActionButton( GameInfo.Missions.MISSION_ONE_SHOT_TOURISM, "[ICON_TOURISM]", Locale.ConvertTextKey("TXT_KEY_EUI_MOD_TOURISM", tech.InfluenceSpreadModifier) )
			end
			if tech.AllowsWorldCongress then
				addSmallActionButton( GameInfo.Missions.MISSION_TRADE, "", "TXT_KEY_ALLOWS_WORLD_CONGRESS" ) --[ICON_CITY_STATE]
			end
			if NZ(tech.ExtraVotesPerDiplomat) then
				addSmallActionButton( nil, "[ICON_DIPLOMAT]", "TXT_KEY_EXTRA_VOTES_FROM_DIPLOMATS", tech.ExtraVotesPerDiplomat )
			end

			if (tech.WorkerSpeedModifier~=0) then
			    --addSmallButton( 44, "TECH_ENH_ICONS_ATLAS", "TXT_KEY_EUI_WORKER_SPEED_MOD" )
		       addSmallActionButton( GameInfo.Missions.MISSION_HURRY, "[ICON_PRODUCTION]",  Locale.ConvertTextKey("TXT_KEY_EUI_WORKER_SPEED_MOD", tech.WorkerSpeedModifier)  )
	        end

			addSmallGenericButtonIF( tech.ScenarioTechButton == 1 and "TXT_KEY_SCENARIO_TECH_BUTTON_1" )
			addSmallGenericButtonIF( tech.ScenarioTechButton == 2 and "TXT_KEY_SCENARIO_TECH_BUTTON_2" )
			addSmallGenericButtonIF( tech.ScenarioTechButton == 3 and "TXT_KEY_SCENARIO_TECH_BUTTON_3" )
			addSmallGenericButtonIF( tech.ScenarioTechButton == 4 and "TXT_KEY_SCENARIO_TECH_BUTTON_4" )
			--addSmallGenericButtonIF( tech.TriggersArchaeologicalSites and "TXT_KEY_EUI_TRIGGERS_ARCHAEOLOGICAL_SITES" )
		end
	end

	if gk_mode then
		for row in GameInfo.Technology_FreePromotions( thisTechType ) do
			local promotion = GameInfo.UnitPromotions[ row.PromotionType ]
			if promotion and not addSmallButton( promotion.PortraitIndex, promotion.IconAtlas, "TXT_KEY_FREE_PROMOTION_FROM_TECH", promotion._Name, promotion.Help ) then
				break
			end
		end
	end


	
	--FirstFreeUnitClass, "TXT_KEY_EUI_FIRST_FREE_UNIT_CLASS"
	--FeatureProductionModifier, "TXT_KEY_EUI_FEATURE_PRODUCTION_MOD"
	--addSmallGenericButtonNZ( tech.WorkerSpeedModifier, "TXT_KEY_EUI_WORKER_SPEED_MOD" )
	addSmallGenericButtonNZ( tech.FirstFreeTechs, "TXT_KEY_EUI_FIRST_FREE_TECHS" )
	addSmallGenericButtonIF( tech.EndsGame and "TXT_KEY_EUI_ENDS_GAME" )
	addSmallGenericButtonIF( tech.ExtraWaterSeeFrom and "TXT_KEY_EUI_EXTRA_WATER_SEE_FROM" )
	addSmallGenericButtonIF( tech.WaterWork and "TXT_KEY_EUI_WATER_WORK" )

	-- show buttons we are using and hide the rest
	for i = 1, maxSmallButtons do
		local button = thisTechButtonInstance["B"..i]
		if button then
			button:SetHide(i>=buttonNum)
		else
			break
		end
	end
	if IsCiv5 then
		return buttonNum
	else
		return buttonNum - 1  -- another Firaxis cleverness
	end
end

--==========================================================
--	Obtain small buttons for a tech and lay them out
--  radially centered from the bottom (Civ BE only).
--==========================================================
local AddSmallButtonsToTechButton = AddSmallButtonsToTechButton
function AddSmallButtonsToTechButtonRadial( thisTechButtonInstance, tech, maxSmallButtons, textureSize )
	local buttonNum = AddSmallButtonsToTechButton( thisTechButtonInstance, tech, maxSmallButtons, textureSize )

	-- Push the start back based on # of icons
	local phiDegrees = 90 - ((buttonNum-1) * 24 ) -- 90?is facing down (0?is far right), +values are clockwise, 24?is 1/2 angle per icon
	for i = 1, buttonNum do
		thisTechButtonInstance["B"..i]:SetOffsetVal( PolarToCartesian( 46, 24 * i + phiDegrees ) ) -- 46 is radius
	end

	return buttonNum
end

function AddCallbackToSmallButtons( thisTechButtonInstance, maxSmallButtons, void1, void2, thisEvent, thisCallback )
	for i = 1, maxSmallButtons do
		local button = thisTechButtonInstance["B"..i]
		if button then
			button:SetVoid1( void1 )
			button:RegisterCallback( thisEvent, thisCallback )
		else
			return
		end
	end
end

