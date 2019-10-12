-- Rebalance the distribution of gold and XP to make for a better 10v10 game
local GOLD_SCALE_FACTOR_INITIAL = 1
local GOLD_SCALE_FACTOR_FINAL = 2.5
local GOLD_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes
local XP_SCALE_FACTOR_INITIAL = 2
local XP_SCALE_FACTOR_FINAL = 2
local XP_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes

require("common/init")
require("util")

WebApi.customGame = "Dota12v12"

LinkLuaModifier("modifier_core_courier", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_silencer_new_int_steal", LUA_MODIFIER_MOTION_NONE)

_G.newStats = newStats or {}

if CMegaDotaGameMode == nil then
	_G.CMegaDotaGameMode = class({}) -- put CMegaDotaGameMode in the global scope
	--refer to: http://stackoverflow.com/questions/6586145/lua-require-with-global-local
end

function Activate()
	CMegaDotaGameMode:InitGameMode()
end

function CMegaDotaGameMode:InitGameMode()
	print( "10v10 Mode Loaded!" )

	-- Adjust team limits
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 12 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 12 )
	GameRules:SetStrategyTime( 0.0 )
	GameRules:SetShowcaseTime( 0.0 )

	-- Hook up gold & xp filters
    GameRules:GetGameModeEntity():SetItemAddedToInventoryFilter( Dynamic_Wrap( CMegaDotaGameMode, "ItemAddedToInventoryFilter" ), self )
	GameRules:GetGameModeEntity():SetModifyGoldFilter( Dynamic_Wrap( CMegaDotaGameMode, "FilterModifyGold" ), self )
	GameRules:GetGameModeEntity():SetModifyExperienceFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterModifyExperience" ), self )
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterBountyRunePickup" ), self )
	GameRules:GetGameModeEntity():SetModifierGainedFilter( Dynamic_Wrap( CMegaDotaGameMode, "ModifierGainedFilter" ), self )
	GameRules:GetGameModeEntity():SetRuneSpawnFilter( Dynamic_Wrap( CMegaDotaGameMode, "RuneSpawnFilter" ), self )
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CMegaDotaGameMode, 'ExecuteOrderFilter'), self)

	GameRules:GetGameModeEntity():SetTowerBackdoorProtectionEnabled( true )
	GameRules:GetGameModeEntity():SetPauseEnabled(IsInToolsMode())
	GameRules:SetGoldTickTime( 0.3 ) -- default is 0.6
	GameRules:LockCustomGameSetupTeamAssignment(true)
	GameRules:SetCustomGameSetupAutoLaunchDelay(1)
	GameRules:GetGameModeEntity():SetKillableTombstones( true )
	if IsInToolsMode() then
		GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride(0)
	end

	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(CMegaDotaGameMode, 'OnGameRulesStateChange'), self)
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CMegaDotaGameMode, "OnNPCSpawned" ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CMegaDotaGameMode, 'OnEntityKilled' ), self )

	self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL
	self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL
	self.couriers = {}
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, 5 )

	ListenToGameEvent("dota_player_used_ability", function(event)
		local hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)
		if not hero then return end
		if event.abilityname == "night_stalker_darkness" then
			local ability = hero:FindAbilityByName(event.abilityname)
			CustomGameEventManager:Send_ServerToAllClients("time_nightstalker_darkness", {
				duration = ability:GetSpecialValueFor("duration")
			})
		end
	end, nil)

	_G.goodraxbonus = 0
	_G.badraxbonus = 0

	_G.kicks = {
		false,
		false,
		false,
		false,
		false
	}

	Timers:CreateTimer( 0.6, function()
		for i = 0, GameRules:NumDroppedItems() - 1 do
			local container = GameRules:GetDroppedItem( i )

			if container then
				local item = container:GetContainedItem()

				if item:GetAbilityName():find( "item_ward_" ) then
					local owner = item:GetOwner()

					if owner then
						local team = owner:GetTeam()
						local fountain
						local multiplier

						if team == DOTA_TEAM_GOODGUYS then
							multiplier = -350
							fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
						elseif team == DOTA_TEAM_BADGUYS then
							multiplier = -650
							fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
						end

						local fountain_pos = fountain:GetAbsOrigin()

						if ( fountain_pos - container:GetAbsOrigin() ):Length2D() > 1200 then
							local pos_item = fountain_pos:Normalized() * multiplier + RandomVector( RandomFloat( 0, 200 ) ) + fountain_pos
							pos_item.z = fountain_pos.z

							container:SetAbsOrigin( pos_item )
							CustomGameEventManager:Send_ServerToPlayer( PlayerResource:GetPlayer( owner:GetPlayerID() ), "display_custom_error", { message = "#dropped_wards_return_error" } )
						end
					end
				end
			end
		end

		return 0.6
	end )
end

function GetActivePlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function GetActiveHumanPlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and not self:isPlayerBot(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function otherTeam(team)
    if team == DOTA_TEAM_BADGUYS then
        return DOTA_TEAM_GOODGUYS
    elseif team == DOTA_TEAM_GOODGUYS then
        return DOTA_TEAM_BADGUYS
    end
    return -1
end

---------------------------------------------------------------------------
-- Event: OnEntityKilled
---------------------------------------------------------------------------
function CMegaDotaGameMode:OnEntityKilled( event )
    local killedUnit = EntIndexToHScript( event.entindex_killed )
    local killer = EntIndexToHScript( event.entindex_attacker )
	local killedTeam = killedUnit:GetTeam()
	local name = killedUnit:GetUnitName()

	local raxbonuses = {
		npc_dota_goodguys_range_rax_top = 1,
		npc_dota_goodguys_melee_rax_top = 2,
		npc_dota_goodguys_range_rax_mid = 1,
		npc_dota_goodguys_melee_rax_mid = 2,
		npc_dota_goodguys_range_rax_bot = 1,
		npc_dota_goodguys_melee_rax_bot = 2,
		npc_dota_badguys_range_rax_top = -1,
		npc_dota_badguys_melee_rax_top = -2,
		npc_dota_badguys_range_rax_mid = -1,
		npc_dota_badguys_melee_rax_mid = -2,
		npc_dota_badguys_range_rax_bot = -1,
		npc_dota_badguys_melee_rax_bot = -2,
	}
	if raxbonuses[name] ~= nil then
		if raxbonuses[name] > 0 then
			_G.badraxbonus = _G.badraxbonus + raxbonuses[name]
		else
			_G.goodraxbonus = _G.goodraxbonus - raxbonuses[name]
		end
		SendOverheadEventMessage( nil, OVERHEAD_ALERT_MANA_LOSS, killedUnit, math.abs(raxbonuses[name]), nil )
		GameRules:SendCustomMessage("#destroyed_" .. string.sub(name,10,#name - 4),-1,0)
		if _G.badraxbonus == 9 then
			_G.badraxbonus = 11
			GameRules:SendCustomMessage("#destroyed_goodguys_all_rax",-1,0)
		end
		if _G.goodraxbonus == 9 then
			_G.goodraxbonus = 11
			GameRules:SendCustomMessage("#destroyed_badguys_all_rax",-1,0)
		end
	end

    --print("fired")
    if killedUnit:IsRealHero() and not killedUnit:IsReincarnating() then
		local player_id = -1
		if killer and killer:IsRealHero() and killer.GetPlayerID then
			player_id = killer:GetPlayerID()
		else
			if killer:GetPlayerOwnerID() ~= -1 then
				player_id = killer:GetPlayerOwnerID()
			end
		end
		if player_id ~= -1 then

			newStats[player_id] = newStats[player_id] or {
				npc_dota_sentry_wards = 0,
				npc_dota_observer_wards = 0,
				tower_damage = 0,
				killed_hero = {}
			}

			local kh = newStats[player_id].killed_hero

			kh[name] = kh[name] and kh[name] + 1 or 1
		end


	    local dotaTime = GameRules:GetDOTATime(false, false)
	    local timeToStartReduction = 0 -- 20 minutes
	    local respawnReduction = 0.75 -- Original Reduction rate

	    -- Reducation Rate slowly increases after a certain time, eventually getting to original levels, this is to prevent games lasting too long
	    if dotaTime > timeToStartReduction then
	    	dotaTime = dotaTime - timeToStartReduction
	    	respawnReduction = respawnReduction + ((dotaTime / 60) / 100) -- 0.75 + Minutes of Game Time / 100 e.g. 25 minutes fo game time = 0.25
	    end

	    if respawnReduction > 1 then
	    	respawnReduction = 1
	    end

	    local timeLeft = killedUnit:GetRespawnTime()
	 	timeLeft = timeLeft * respawnReduction -- Respawn time reduced by a rate

	    -- Disadvantaged teams get 5 seconds less respawn time for every missing player
	    local herosTeam = GetActivePlayerCountForTeam(killedUnit:GetTeamNumber())
	    local opposingTeam = GetActivePlayerCountForTeam(otherTeam(killedUnit:GetTeamNumber()))
	    local difference = herosTeam - opposingTeam

	    local addedTime = 0
	    if difference < 0 then
	        addedTime = difference * 5
	        local RespawnReductionRate = string.format("%.2f", tostring(respawnReduction))
		    local OriginalRespawnTime = tostring(math.floor(timeLeft))
		    local TimeToReduce = tostring(math.floor(addedTime))
		    local NewRespawnTime = tostring(math.floor(timeLeft + addedTime))
	        --GameRules:SendCustomMessage( "ReductionRate:"  .. " " .. RespawnReductionRate .. " " .. "OriginalTime:" .. " " ..OriginalRespawnTime .. " " .. "TimeToReduce:" .. " " ..TimeToReduce .. " " .. "NewRespawnTime:" .. " " .. NewRespawnTime, 0, 0)
	    end

	    timeLeft = timeLeft + addedTime
	    --print(timeLeft)

	    if timeLeft < 1 then
	        timeLeft = 1
	    end

	    killedUnit:SetTimeUntilRespawn(timeLeft)
    end

end

LinkLuaModifier("modifier_rax_bonus", LUA_MODIFIER_MOTION_NONE)
function CMegaDotaGameMode:OnNPCSpawned( event )
	local spawnedUnit = EntIndexToHScript( event.entindex )

	local owner = spawnedUnit:GetOwner()
	local name = spawnedUnit:GetUnitName()

	if owner and owner.GetPlayerID and ( name == "npc_dota_sentry_wards" or name == "npc_dota_observer_wards" ) then
		local player_id = owner:GetPlayerID()

		newStats[player_id] = newStats[player_id] or {
			npc_dota_sentry_wards = 0,
			npc_dota_observer_wards = 0,
			tower_damage = 0,
			killed_hero = {}
		}

		newStats[player_id][name] = newStats[player_id][name] + 1
	end

	if spawnedUnit:IsRealHero() then
		-- Silencer Nerf
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rax_bonus", {})
		Timers:CreateTimer(1, function()
			if spawnedUnit:HasModifier("modifier_silencer_int_steal") then
				spawnedUnit:RemoveModifierByName('modifier_silencer_int_steal')
				spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_silencer_new_int_steal", {})
			end
		end)

		if self.couriers[spawnedUnit:GetTeamNumber()] then
			self.couriers[spawnedUnit:GetTeamNumber()]:SetControllableByPlayer(spawnedUnit:GetPlayerID(), true)
		end

		if not spawnedUnit.firstTimeSpawned then
			spawnedUnit.firstTimeSpawned = true
			spawnedUnit:SetContextThink("HeroFirstSpawn", function()
				local playerId = spawnedUnit:GetPlayerID()
				if spawnedUnit == PlayerResource:GetSelectedHeroEntity(playerId) then
					Patreons:GiveOnSpawnBonus(playerId)
				end
			end, 2/30)
		end
	end
end

function CMegaDotaGameMode:ModifierGainedFilter(filterTable)
	local disableHelpResult = DisableHelp.ModifierGainedFilter(filterTable)
	if disableHelpResult == false then
		return false
	end

	return true
end

function CMegaDotaGameMode:RuneSpawnFilter(kv)
	local r = RandomInt( 0, 5 )

	if r == 5 then r = 6 end

	kv.rune_type = r

	return true
end

function CMegaDotaGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- update the scale factor:
	 	-- * SCALE_FACTOR_INITIAL at the start of the game
		-- * SCALE_FACTOR_FINAL after SCALE_FACTOR_FADEIN_SECONDS have elapsed
		local curTime = GameRules:GetDOTATime( false, false )
		local goldFracTime = math.min( math.max( curTime / GOLD_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		local xpFracTime = math.min( math.max( curTime / XP_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL + (goldFracTime * ( GOLD_SCALE_FACTOR_FINAL - GOLD_SCALE_FACTOR_INITIAL ) )
		self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL + (xpFracTime * ( XP_SCALE_FACTOR_FINAL - XP_SCALE_FACTOR_INITIAL ) )
--		print( "Gold scale = " .. self.m_CurrentGoldScaleFactor )
--		print( "XP scale = " .. self.m_CurrentXpScaleFactor )
	end
	return 5
end


function CMegaDotaGameMode:FilterBountyRunePickup( filterTable )
--	print( "FilterBountyRunePickup" )
--  for k, v in pairs( filterTable ) do
--  	print("MG: " .. k .. " " .. tostring(v) )
--  end
	filterTable["gold_bounty"] = self.m_CurrentGoldScaleFactor * filterTable["gold_bounty"]
	filterTable["xp_bounty"] = self.m_CurrentXpScaleFactor * filterTable["xp_bounty"]
	return true
end

function CMegaDotaGameMode:FilterModifyGold( filterTable )
--	print( "FilterModifyGold" )
--	print( self.m_CurrentGoldScaleFactor )
	filterTable["gold"] = self.m_CurrentGoldScaleFactor * filterTable["gold"]
	return true
end

function CMegaDotaGameMode:FilterModifyExperience( filterTable )
--	print( "FilterModifyExperience" )
--	print( self.m_CurrentXpScaleFactor )
	filterTable["experience"] = self.m_CurrentXpScaleFactor * filterTable["experience"]
	return true
end

function CMegaDotaGameMode:OnGameRulesStateChange(keys)
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_POST_GAME then
		local couriers = FindUnitsInRadius( 2, Vector( 0, 0, 0 ), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_COURIER, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false )

		for i = 0, 23 do
			if PlayerResource:IsValidPlayer( i ) then
				local networth = 0
				local hero = PlayerResource:GetSelectedHeroEntity( i )

				for _, cour in pairs( couriers ) do
					if cour:GetTeam() == cour:GetTeam() then
						for s = 0, 8 do
							local item = cour:GetItemInSlot( s )

							if item and item:GetOwner() == hero then
								networth = networth + item:GetCost()
							end
						end
					end
				end

				for s = 0, 8 do
					local item = hero:GetItemInSlot( s )

					if item then
						networth = networth + item:GetCost()
					end
				end

				networth = networth + PlayerResource:GetGold( i )

				local stats = {
					networth = networth,
					total_damage = PlayerResource:GetRawPlayerDamage( i ),
					total_healing = PlayerResource:GetHealing( i ),
				}

				if newStats and newStats[i] then
					stats.tower_damage = newStats[i].tower_damage
					stats.sentries_count = newStats[i].npc_dota_sentry_wards
					stats.observers_count = newStats[i].npc_dota_observer_wards
					stats.killed_hero = newStats[i].killed_hero
				end

				CustomNetTables:SetTableValue( "custom_stats", tostring( i ), stats )
			end
		end

		local winner
		local forts = Entities:FindAllByClassname("npc_dota_fort")
		for _, fort in ipairs(forts) do
			if fort:GetHealth() > 0 then
				local team = fort:GetTeam()
				if winner then
					winner = nil
					break
				end

				winner = team
			end
		end

		if winner then
			WebApi:AfterMatch(winner)
		end
	end

	if newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		local ggp = 0
		local bgp = 0
		local ggcolor = {
			{70,70,255},
			{0,255,255},
			{255,0,255},
			{255,255,0},
			{255,165,0},
			{0,255,0},
			{255,0,0},
			{75,0,130},
			{109,49,19},
			{255,20,147},
			{128,128,0},
			{255,255,255}
		}
		local bgcolor = {
			{255,135,195},
			{160,180,70},
			{100,220,250},
			{0,128,0},
			{165,105,0},
			{153,50,204},
			{0,128,128},
			{0,0,165},
			{128,0,0},
			{180,255,180},
			{255,127,80},
			{0,0,0}
		}
		for i=0, PlayerResource:GetPlayerCount()-1 do
			if PlayerResource:GetTeam(i) == DOTA_TEAM_GOODGUYS then
				ggp = ggp + 1
				PlayerResource:SetCustomPlayerColor(i,ggcolor[ggp][1],ggcolor[ggp][2],ggcolor[ggp][3])
			end
			if PlayerResource:GetTeam(i) == DOTA_TEAM_BADGUYS then
				bgp = bgp + 1
				PlayerResource:SetCustomPlayerColor(i,bgcolor[bgp][1],bgcolor[bgp][2],bgcolor[bgp][3])
			end
		end

        for i=0, DOTA_MAX_TEAM_PLAYERS do
            if PlayerResource:IsValidPlayer(i) then
                if PlayerResource:HasSelectedHero(i) == false then

                    local player = PlayerResource:GetPlayer(i)
                    player:MakeRandomHeroSelection()

                    local hero_name = PlayerResource:GetSelectedHeroName(i)
                end
            end
        end
	end

	if newState == DOTA_GAMERULES_STATE_PRE_GAME then
        local toAdd = {
            luna_moon_glaive_fountain = 4,
            ursa_fury_swipes_fountain = 1,
        }

        local fountains = Entities:FindAllByClassname('ent_dota_fountain')
        -- Loop over all ents
        for k,fountain in pairs(fountains) do
            for skillName,skillLevel in pairs(toAdd) do
                fountain:AddAbility(skillName)
                local ab = fountain:FindAbilityByName(skillName)
                if ab then
                    ab:SetLevel(skillLevel)
                end
            end

            local item = CreateItem('item_monkey_king_bar_fountain', fountain, fountain)
            if item then
                fountain:AddItem(item)
            end

        end

		local courier_spawn = {}
		courier_spawn[2] = Entities:FindByClassname(nil, "info_courier_spawn_radiant")
		courier_spawn[3] = Entities:FindByClassname(nil, "info_courier_spawn_dire")

		for team = 2, 3 do
			self.couriers[team] = CreateUnitByName("npc_dota_courier", courier_spawn[team]:GetAbsOrigin(), true, nil, nil, team)
			self.couriers[team]:AddNewModifier(self.couriers[team], nil, "modifier_core_courier", {})
		end

--		Timers:CreateTimer(30, function()
--			for i=0,PlayerResource:GetPlayerCount() do
--				local hero = PlayerResource:GetSelectedHeroEntity(i)
--				if hero ~= nil then
--					if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
--						hero:AddItemByName("item_courier")
--						break
--					end
--				end
--			end
--			for i=0,PlayerResource:GetPlayerCount() do
--				local hero = PlayerResource:GetSelectedHeroEntity(i)
--				if hero ~= nil then
--					if hero:GetTeam() == DOTA_TEAM_BADGUYS then
--						hero:AddItemByName("item_courier")
--						break
--					end
--				end
--			end
--		end)
	end
end

function CMegaDotaGameMode:ItemAddedToInventoryFilter( filterTable )
	if filterTable["item_entindex_const"] == nil then
		return true
	end
 	if filterTable["inventory_parent_entindex_const"] == nil then
		return true
	end
	local hInventoryParent = EntIndexToHScript( filterTable["inventory_parent_entindex_const"] )
	local hItem = EntIndexToHScript( filterTable["item_entindex_const"] )
	if hItem ~= nil and hInventoryParent ~= nil then
		local itemName = hItem:GetName()
		if hInventoryParent:IsRealHero() then
			local plyID = hInventoryParent:GetPlayerID()
			if not plyID then return true end
			local pitems = {
			--	"item_patreon_1",
			--	"item_patreon_2",
			--	"item_patreon_3",
			--	"item_patreon_4",
			--	"item_patreon_5",
			--	"item_patreon_6",
			--	"item_patreon_7",
			--	"item_patreon_8",
				"item_patreonbundle_1",
				"item_patreonbundle_2"
			}
			local pitem = false
			for i=1,#pitems do
				if itemName == pitems[i] then
					pitem = true
					break
				end
			end
			if pitem == true then
				local psets = Patreons:GetPlayerSettings(plyID)
				if psets.level < 1 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#nopatreonerror" })
					UTIL_Remove(hItem)
					return false
				end
			end
			if itemName == "item_banhammer" then
				local psets = Patreons:GetPlayerSettings(plyID)
				if psets.level < 2 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#nopatreonerror2" })
					UTIL_Remove(hItem)
					return false
				else
					if GameRules:GetDOTATime(false,false) < 300 then
						CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#notyettime" })
						UTIL_Remove(hItem)
						return false
					end
				end
			end
		else
			local pitems = {
				"item_patreonbundle_1",
				"item_patreonbundle_2",
				"item_banhammer"
			}
			for i=1,#pitems do
				if itemName == pitems[i] then
					local prsh = hItem:GetPurchaser()
					if prsh ~= nil then
						if prsh:IsRealHero() then
							local prshID = prsh:GetPlayerID()
							if not prshID then
								UTIL_Remove(hItem)
								return false
							end
							local psets = Patreons:GetPlayerSettings(prshID)
							if not psets then
								UTIL_Remove(hItem)
								return false
							end
							if itemName == "item_banhammer" then
								if psets.level < 2 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#nopatreonerror2" })
									UTIL_Remove(hItem)
									return false
								else
									if GameRules:GetDOTATime(false,false) < 300 then
										CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#notyettime" })
										UTIL_Remove(hItem)
										return false
									end
								end
							else
								if psets.level < 1 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#nopatreonerror" })
									UTIL_Remove(hItem)
									return false
								end
							end
						else
							UTIL_Remove(hItem)
							return false
						end
					else
						UTIL_Remove(hItem)
						return false
					end
				end
			end
		end
	end

	return true
end

RegisterCustomEventListener("GetKicks", function(data)
    CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.id), "setkicks", {kicks = _G.kicks})
end)

function CMegaDotaGameMode:ExecuteOrderFilter(filterTable)
	-- DeepPrintTable({ order = filterTable })
	local orderType = filterTable.order_type
	local playerId = filterTable.issuer_player_id_const
	local target = filterTable.entindex_target ~= 0 and EntIndexToHScript(filterTable.entindex_target) or nil
	local ability = filterTable.entindex_ability ~= 0 and EntIndexToHScript(filterTable.entindex_ability) or nil
	-- `entindex_ability` is item id in some orders without entity
	if ability and not ability.GetAbilityName then ability = nil end
	local abilityName = ability and ability:GetAbilityName() or nil
	local unit
	-- TODO: Are there orders without a unit?
	if filterTable.units and filterTable.units["0"] then
		unit = EntIndexToHScript(filterTable.units["0"])
	end

	local disableHelpResult = DisableHelp.ExecuteOrderFilter(orderType, ability, target, unit)
	if disableHelpResult == false then
		return false
	end

	if orderType == DOTA_UNIT_ORDER_CAST_POSITION then
		if abilityName == "item_ward_dispenser" or abilityName == "item_ward_sentry" or abilityName == "item_ward_observer" then
			local list = Entities:FindAllByClassname("trigger_multiple")
			local orderVector = Vector(filterTable.position_x, filterTable.position_y, 0)
			local fs = {
				Vector(5000,6912,0),
				Vector(-5300,-6938,0)
			}
			if PlayerResource:GetTeam(playerId) == 2 then
				fs = {fs[2],fs[1]}
			end
			for i=1,#list do
				if list[i]:GetName():find("neutralcamp") ~= nil then
					if IsInTriggerBox(list[i], 12, orderVector) and ( fs[1] - orderVector ):Length2D() < ( fs[2] - orderVector ):Length2D() then
						CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#block_spawn_error" })
						return false
					end
				end
			end
		end
	end

	if unit then
		if unit:IsCourier() then
			if (orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_GIVE_ITEM) and ability and ability:IsItem() then
				local purchaser = ability:GetPurchaser()
				if purchaser and purchaser:GetPlayerID() ~= playerId then
					--CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#hud_error_courier_cant_order_item" })
					return false
				end
			end
		end
	end

	return true
end

msgtimer = {}
RegisterCustomEventListener("OnTimerClick", function(keys)
	if msgtimer[keys.PlayerID] and GameRules:GetGameTime() - msgtimer[keys.PlayerID] < 3 then
		return
	end
	msgtimer[keys.PlayerID] = GameRules:GetGameTime()

	local time = math.abs(math.floor(GameRules:GetDOTATime(false, true)))
	local min = math.floor(time / 60)
	local sec = time - min * 60
	if min < 10 then min = "0" .. min end
	if sec < 10 then sec = "0" .. sec end
	Say(PlayerResource:GetPlayer(keys.PlayerID), min .. ":" .. sec, true)
end)
