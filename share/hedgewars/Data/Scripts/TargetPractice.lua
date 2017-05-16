--[=[
Target Practice Mission Framework for Hedgewars

This is a simple library intended to make setting up simple training missions a trivial
task requiring just. The library has been created to reduce redundancy in Lua scripts.

The training framework generates complete and fully usable training missions by just
one function call.

The missions generated by this script are all the same:
- The player will get a team with a single hedgehog.
- The team gets a single predefined weapon infinitely times.
- A fixed sequence of targets will spawn at predefined positions.
- When a target has been destroyed, the next target of the target sequence appears
- The mission ends successfully when all targets have been destroyed
- The mission ends unsuccessfully when the time runs out or the hedgehog dies
- When the mission ends, a score is awarded, based on the performance (hit targets,
  accuracy and remaining time) of the hedgehog. When not all targets are hit, there
  will be no accuracy and time bonuses.

To use this library, you first have to load it and to call TrainingMission once with
the appropriate parameters. Really, that’s all!
See the comment of TrainingMission for a specification of all parameters.

Below is a template for your convenience, you just have to fill in the fields and delete
optional arguments you don’t want.
----- snip -----
HedgewarsScriptLoad("/Scripts/Training.lua")
params = {
	missionTitle = ,
	map = ,
	theme = ,
	time = ,
	ammoType = ,
	gearType = ,
	targets = {
		{ x = , y = },
		{ x = , y = },
		-- etc.
	},

	wind = ,
	solidLand = ,
	artillery = ,
	hogHat = ,
	hogName = ,
	teamName = ,
	teamGrave = ,
	clanColor = ,
	goalText = ,
	shootText =
}
TargetPracticeMission(params)
----- snip -----
]=]

HedgewarsScriptLoad("/Scripts/Locale.lua")

local player = nil
local scored = 0
local shots = 0
local end_timer = 1000
local game_lost = false
local time_goal = 0
local total_targets
local targets

--[[
TrainingMission(params)

This function sets up the *entire* training mission and needs one argument: params.
The argument “params” is a table containing fields which describe the training mission.
	mandatory fields:
	- missionTitle:	the name of the mission
	- map:		the name map to be used
	- theme:	the name of the theme (does not need to be a standalone theme)
	- time:		the time limit in milliseconds
	- ammoType:	the ammo type of the weapon to be used
	- gearType:	the gear type of the gear which is fired (used to count shots)
	- targets:	The coordinates of where the targets will be spawned.
			It is a table containing tables containing coordinates of format
			{ x=value, y=value }. The targets will be spawned in the same
			order as specified the coordinate tables appear. Example:
				targets = {
					{ x = 324, y = 43 },
					{ x = 123, y = 56 },
					{ x = 6, y = 0 },
				}
			There must be at least 1 target.

	optional fields:
	- wind:		the initial wind (-100 to 100) (default: 0 (no wind))
	- solidLand:	weather the terrain is indestructible (default: false)
	- artillery:	if true, the hog can’t move (default: false)
	- hogHat:	hat of the hedgehog (default: "NoHat")
	- hogName:	name of the hedgehog (default: "Trainee")
	- teamName:	name of the hedgehog’s team (default: "Training Team")
	- teamGrave:	name of the hedgehog’s grave
	- teamFlag:	name of the team’s flag (default: "cm_crosshair")
	- clanColor:	color of the (only) clan (default: 0xFF0204, which is a red tone)
	- goalText:	A short string explaining the goal of the mission
			(default: "Destroy all targets within the time!")
	- shootText:	A string which says how many times the player shot, “%d” is replaced
			by the number of shots. (default: "You have shot %d times.")
]]
function TargetPracticeMission(params)
	if params.hogHat == nil then params.hogHat = "NoHat" end
	if params.hogName == nil then params.hogName = loc("Trainee") end
	if params.teamName == nil then params.teamName = loc("Training Team") end
	if params.goalText == nil then params.goalText = loc("Eliminate all targets before your time runs out.|You have unlimited ammo for this mission.") end
	if params.shootText == nil then params.shootText = loc("You have shot %d times.") end
	if params.clanColor == nil then params.clanColor = 0xFF0204 end
	if params.teamGrave == nil then params.teamGrave= "Statue" end
	if params.teamFlag == nil then params.teamFlag = "cm_crosshair" end
	if params.wind == nil then params.wind = 0 end

	local solid, artillery
	if params.solidLand == true then solid = gfSolidLand else solid = 0 end
	if params.artillery == true then artillery = gfArtillery else artillery = 0 end

	targets = params.targets

	total_targets = #targets

	_G.onAmmoStoreInit = function()
		SetAmmo(params.ammoType, 9, 0, 0, 0)
	end

	_G.onGameInit = function()
		Seed = 1
		GameFlags = gfDisableWind + gfInfAttack + gfOneClanMode + solid + artillery
		TurnTime = params.time
		Map = params.map
		Theme = params.theme
		Goals = params.goalText
		CaseFreq = 0
		MinesNum = 0
		Explosives = 0
		-- Disable Sudden Death
		WaterRise = 0
		HealthDecrease = 0

		SetWind(params.wind)

		AddTeam(loc(params.teamName), params.clanColor, params.teamGrave, "Flowerhog", "Default", params.teamFlag)

		player = AddHog(loc(params.hogName), 0, 1, params.hogHat)
		SetGearPosition(player, params.hog_x, params.hog_y)
	end

	_G.onGameStart = function()
		SendHealthStatsOff()
		ShowMission(params.missionTitle, loc("Aiming practice"), params.goalText, -params.ammoType, 5000)
		spawnTarget()
	end

	_G.onNewTurn = function()
		SetWeapon(params.ammoType)
	end

	_G.spawnTarget = function()
		gear = AddGear(0, 0, gtTarget, 0, 0, 0, 0)

		x = targets[scored+1].x
		y = targets[scored+1].y

		SetGearPosition(gear, x, y)

		return gear
	end

	_G.onGameTick20 = function()
		if TurnTimeLeft < 40 and TurnTimeLeft > 0 and scored < total_targets and game_lost == false then
			game_lost = true
			AddCaption(loc("Time’s up!"), 0xFFFFFFFF, capgrpGameState)
			ShowMission(params.missionTitle, loc("Aiming practice"), loc("Oh no! Time's up! Just try again."), -amSkip, 0)
			SetHealth(player, 0)
			time_goal = 1
		end

		if band(GetState(player), gstDrowning) == gstDrowning and game_lost == false and scored < total_targets then
			game_lost = true
			time_goal = 1
			AddCaption(loc("You lose!"), 0xFFFFFFFF, capgrpGameState)
			ShowMission(params.missionTitle, loc("Aiming practice"), loc("Oh no! You failed! Just try again."), -amSkip, 0)
		end

		if scored == total_targets  or game_lost then
			if end_timer == 0 then
				generateStats()
				EndGame()
			else
				TurnTimeLeft = time_goal
			end
	        end_timer = end_timer - 20
		end
	end

	_G.onGearAdd = function(gear)
		if GetGearType(gear) == params.gearType then
			shots = shots + 1
		end
	end

	_G.onGearDamage = function(gear, damage)
		if GetGearType(gear) == gtTarget then
			scored = scored + 1
			if scored < total_targets then
				AddCaption(string.format(loc("Targets left: %d"), (total_targets-scored)), 0xFFFFFFFF, capgrpMessage)
				spawnTarget()
			else
				if not game_lost then
					AddCaption(loc("You have destroyed all targets!"), 0xFFFFFFFF, capgrpGameState)
					ShowMission(params.missionTitle, loc("Aiming practice"), loc("Congratulations! You have destroyed all targets within the time."), 0, 0)
					PlaySound(sndVictory, player)
					SetState(player, bor(GetState(player), gstWinner))
					time_goal = TurnTimeLeft
				end
			end
		end

		if GetGearType(gear) == gtHedgehog then
			if not game_lost then
				game_lost = true
				AddCaption(loc("You lose!"), 0xFFFFFFFF, capgrpGameState)
				ShowMission(params.missionTitle, loc("Aiming practice"), loc("Oh no! You failed! Just try again."), -amSkip, 0)

				SetHealth(player, 0)
				time_goal = 1
			end
		end
	end

	_G.onGearDelete = function(gear)
		if GetGearType(gear) == gtTarget and band(GetState(gear), gstDrowning) ~= 0 then
			AddCaption(loc("You lost your target, try again!"), 0xFFFFFFFF, capgrpGameState)
			local newTarget = spawnTarget()
			local x, y = GetGearPosition(newTarget)
			local success = PlaceSprite(x, y + 24, sprAmGirder, 0, 0xFFFFFFFF, false, false, false)
			if not success then
				WriteLnToConsole("ERROR: Failed to spawn girder under respawned target!")
			end
		end
	end

	_G.generateStats = function()
		local accuracy = (scored/shots)*100
		local end_score_targets = scored * math.ceil(6000/#targets)
		local end_score_overall
		if not game_lost then
			local end_score_time = math.ceil(time_goal/(params.time/6000))
			local end_score_accuracy = math.ceil(accuracy * 60)
			end_score_overall = end_score_time + end_score_targets + end_score_accuracy

			SendStat(siGameResult, loc("You have finished the target practice!"))

			SendStat(siCustomAchievement, string.format(loc("You have destroyed %d of %d targets (+%d points)."), scored, total_targets, end_score_targets))
			SendStat(siCustomAchievement, string.format(params.shootText, shots))
			SendStat(siCustomAchievement, string.format(loc("Your accuracy was %.1f%% (+%d points)."), accuracy, end_score_accuracy))
			SendStat(siCustomAchievement, string.format(loc("You had %.1fs remaining on the clock (+%d points)."), (time_goal/1000), end_score_time))
		else
			SendStat(siGameResult, loc("You lose!"))

			SendStat(siCustomAchievement, string.format(loc("You have destroyed %d of %d targets (+%d points)."), scored, total_targets, end_score_targets))
			SendStat(siCustomAchievement, string.format(params.shootText, shots))
			if(shots > 0) then
				SendStat(siCustomAchievement, string.format(loc("Your accuracy was %.1f%%."), accuracy))
			end
			end_score_overall = end_score_targets
		end
		SendStat(siPointType, loc("point(s)"))
		SendStat(siPlayerKills, tostring(end_score_overall), loc(params.teamName))
	end
end
