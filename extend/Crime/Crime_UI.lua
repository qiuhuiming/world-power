PlayerClass		 = getmetatable(Players[0]).__index
LuaEvents.Player = LuaEvents.Player		or function(player)	 end
LuaEvents.City	 = LuaEvents.City		or function(city)	 end


local gHandicap			= (PreGame.GetHandicap(0) > 0) and PreGame.GetHandicap(0) or 1


function Game.GetRandom(lower, upper)
	return Game.Rand((upper + 2) - lower, "") + lower
end

-- ********************************************************
-- end
-- ********************************************************	

--Player:GetCityCrimeTT
function Player.GetCityCrimeTT(player, city)
	--local totalCrime, totalCrime = player:GetCityCrimeTotal(city, true)
	local toolTipCrime = ""
	--local toolTipDisease = ""
	local toolTipCrimeSentiment = nil
-- ********************************************************
-- ��������ϸ
-- ********************************************************

    toolTipCrime = toolTipCrime ..city:GetYieldRateInfoTool(GameInfoTypes["YIELD_CRIME"])

	if city:GetYieldModifierTooltip(GameInfoTypes["YIELD_CRIME"])~= "" then
	   toolTipCrime = toolTipCrime .. city:GetYieldModifierTooltip(GameInfoTypes["YIELD_CRIME"])
	end

	
	return Locale.ConvertTextKey("TXT_KEY_CITYVIEW_CRIME_TEXT_TT_DETAIL",toolTipCrime)
	
end



