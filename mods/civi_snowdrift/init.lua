-- Parameters
local YWATER = 1 -- Normally set this to world's water level
local YMIN = -48 -- Normally set this to deepest ocean
local YMAX = 200 -- Normally set this to cloud level
local PRECTIM = 300 -- Precipitation noise 'spread'
local PRECTHR = 0.2 -- Precipitation noise threshold
local FLAKLPOS = 32 -- Snowflake light-tested positions per 0.5s cycle
local DROPLPOS = 64 -- Raindrop light-tested positions per 0.5s cycle
local DROPPPOS = 2 -- Number of raindrops spawned per light-tested position
local RAINGAIN = 0.2 -- Rain sound volume
local NISVAL = 39 -- Overcast sky RGB value at night
local DASVAL = 159 -- Overcast sky RGB value in daytime
local FLAKRAD = 16 -- Radius in which flakes are created
local DROPRAD = 16 -- Radius in which drops are created

-- Precipitation noise
local np_prec = {
	offset = 0,
	scale = 1,
	spread = {x = PRECTIM, y = PRECTIM, z = PRECTIM},
	seed = 813,
	octaves = 1,
	persist = 0,
	lacunarity = 2.0,
	flags = "defaults"
}

-- Temperature and humidity noise parameters
local np_temp = {
	offset = 50,
	scale = 50,
	spread = {x = 1000, y = 1000, z = 1000},
	seed = 5349,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	flags = "defaults"
}

local np_humid = {
	offset = 50,
	scale = 50,
	spread = {x = 1000, y = 1000, z = 1000},
	seed = 842,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	flags = "defaults"
}

-- Global state
civi_snowdrift = {
	force_precip = false,
	force_freeze = false
}

local nobj_temp = nil
local nobj_humid = nil
local nobj_prec = nil
local handles = {}
local skybox = {}
local os_time_0 = os.time()
local t_offset = math.random(0, 300000)
local timer = 0
local difsval = DASVAL - NISVAL
local grad = 14 / 95
local yint = 1496 / 95

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 then
		return
	end
	timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local player_name = player:get_player_name()
		local ppos = player:get_pos()
		if not ppos then return end
		local pposy = math.floor(ppos.y) + 2

		if pposy >= YMIN and pposy <= YMAX then
			local pposx = math.floor(ppos.x)
			local pposz = math.floor(ppos.z)

			-- Heat, humidity and precipitation noises
			local time = os.difftime(os.time(), os_time_0) - t_offset

			nobj_temp = nobj_temp or minetest.get_perlin(np_temp)
			nobj_humid = nobj_humid or minetest.get_perlin(np_humid)
			nobj_prec = nobj_prec or minetest.get_perlin(np_prec)

			local nval_temp = nobj_temp:get_2d({x = pposx, y = pposz})
			local nval_humid = nobj_humid:get_2d({x = pposx, y = pposz})
			local nval_prec = nobj_prec:get_2d({x = time, y = 0})

			local freeze = nval_temp < 35
			local precip = nval_prec > PRECTHR and
				nval_humid - grad * nval_temp > yint

			-- Admin overrides
			if civi_snowdrift.force_precip then
				precip = true
				if civi_snowdrift.force_freeze then
					freeze = true
				else
					freeze = false
				end
			end

			-- Set sky
			if precip and not skybox[player_name] then
				local sval
				local time_of_day = minetest.get_timeofday()
				if time_of_day >= 0.5 then
					time_of_day = 1 - time_of_day
				end
				if time_of_day <= 0.1875 then
					sval = NISVAL
				elseif time_of_day >= 0.2396 then
					sval = DASVAL
				else
					sval = math.floor(NISVAL + ((time_of_day - 0.1875) / 0.0521) * difsval)
				end

				player:set_sky({r = sval, g = sval, b = sval + 16, a = 255}, "plain", {}, false)
				skybox[player_name] = true
			elseif not precip and skybox[player_name] then
				player:set_sky({}, "regular", {}, true)
				skybox[player_name] = nil
			end

			-- Sound handling
			if not precip or freeze or pposy < YWATER then
				if handles[player_name] then
					minetest.sound_stop(handles[player_name])
					handles[player_name] = nil
				end
			end

			-- Particles
			if precip and pposy >= YWATER then
				if freeze then
					-- Snowfall
					for i = 1, FLAKLPOS do
						local lx = pposx - FLAKRAD + math.random(0, FLAKRAD * 2)
						local lz = pposz - FLAKRAD + math.random(0, FLAKRAD * 2)
						if minetest.get_node_light({x = lx, y = pposy + 10, z = lz}, 0.5) == 15 then
							local sy = pposy + 10 + math.random(0, 10) / 10
							minetest.add_particle({
								pos = {x = lx, y = sy, z = lz},
								velocity = {x = 0, y = -2.0, z = 0},
								expirationtime = math.min((sy - YWATER) / 2, 10),
								size = 2.8,
								collisiondetection = true,
								collision_removal = true,
								texture = "snowdrift_snowflake" .. math.random(1, 12) .. ".png",
								playername = player_name
							})
						end
					end
				else
					-- Rainfall
					for i = 1, DROPLPOS do
						local lx = pposx - DROPRAD + math.random(0, DROPRAD * 2)
						local lz = pposz - DROPRAD + math.random(0, DROPRAD * 2)
						if minetest.get_node_light({x = lx, y = pposy + 10, z = lz}, 0.5) == 15 then
							for d = 1, DROPPPOS do
								local sy = pposy + 10 + math.random(0, 60) / 10
								local ex = math.min((sy - YWATER) / 12, 2)
								minetest.add_particle({
									pos = {x = lx - 0.4 + math.random(0, 8) / 10, y = sy, z = lz - 0.4 + math.random(0, 8) / 10},
									velocity = {x = 0, y = -12.0, z = 0},
									expirationtime = ex,
									size = 2.8,
									collisiondetection = true,
									collision_removal = true,
									vertical = true,
									texture = "snowdrift_raindrop.png",
									playername = player_name
								})
							end
						end
					end
					if not handles[player_name] then
						handles[player_name] = minetest.sound_play("snowdrift_rain", {
							to_player = player_name,
							gain = RAINGAIN,
							loop = true,
						})
					end
				end
			end
		else
			-- Player outside limits
			if handles[player_name] then
				minetest.sound_stop(handles[player_name])
				handles[player_name] = nil
			end
			if skybox[player_name] then
				player:set_sky({}, "regular", {}, true)
				skybox[player_name] = nil
			end
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if handles[name] then
		minetest.sound_stop(handles[name])
		handles[name] = nil
	end
	skybox[name] = nil
end)

-- Chat command for testing
minetest.register_chatcommand("weather_set", {
	params = "[rain|snow|clear]",
	description = "Force weather state for testing",
	privs = { server = true },
	func = function(name, param)
		if param == "rain" then
			civi_snowdrift.force_precip = true
			civi_snowdrift.force_freeze = false
			return true, "Forcing rain..."
		elseif param == "snow" then
			civi_snowdrift.force_precip = true
			civi_snowdrift.force_freeze = true
			return true, "Forcing snow..."
		elseif param == "clear" then
			civi_snowdrift.force_precip = false
			civi_snowdrift.force_freeze = false
			return true, "Resetting weather to automated systems."
		else
			return false, "Usage: /weather_set [rain|snow|clear]"
		end
	end,
})
