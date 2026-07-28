CreateThread(function()
	RegisterCallbacks()
	RegisterMiddleware()
end)

-- authoritative escort relationships - sv_state's ClearPlayer (on disconnect) does not touch these,
-- HandleLogout below is what tears them down
local _escorting = {}
local _escortedBy = {}

local function _setPair(escorterId, targetId)
	_escorting[escorterId] = targetId
	_escortedBy[targetId] = escorterId
	plsr.State:SetPublicFlag(escorterId, 'isEscorting', targetId)
	plsr.State:SetPublicFlag(targetId, 'myEscorter', escorterId)
end

local function _clearPair(escorterId, targetId)
	_escorting[escorterId] = nil
	_escortedBy[targetId] = nil
	plsr.State:SetPublicFlag(escorterId, 'isEscorting', nil)
	plsr.State:SetPublicFlag(escorterId, 'myEscorter', nil)
	plsr.State:SetPublicFlag(targetId, 'isEscorting', nil)
	plsr.State:SetPublicFlag(targetId, 'myEscorter', nil)
end

_ESCORT = {
	Do = function(self, source, data)
		local mPed = GetPlayerPed(source)
		local tPed = GetPlayerPed(data.target)

		local mPos = GetEntityCoords(mPed)
		local tPos = GetEntityCoords(tPed)

		local tChar = plsr.Fetch:CharacterSource(data.target)
		local tICU = tChar ~= nil and tChar:GetData("ICU") or nil

		if _escortedBy[data.target] == nil and (plsr.State:Player(source).onDuty == "ems" or tICU == nil) then
			local dist = #(vector3(mPos.x, mPos.y, mPos.z) - vector3(tPos.x, tPos.y, tPos.z))
			if dist <= 1.5 or (data.inVeh and dist <= 5) or (data.isSwimming and dist <= 15) then
				if data.inVeh then
					TaskLeaveAnyVehicle(tPed, 0, 16)
				end

				_setPair(source, data.target)
				TriggerClientEvent("Escort:Client:Escorted", data.target)
				return true
			else
				return false
			end
		else
			return false
		end
	end,
	DoPutIn = function(self, source, data)
		local escorting = _escorting[source]
		if escorting ~= nil then
			local tPed = GetPlayerPed(escorting)
			local veh = NetworkGetEntityFromNetworkId(data.veh)
			ClearPedTasksImmediately(tPed)

			if data.class == 18 then -- Emergency
				-- Favour Lowest Back Seat But Try Passenger Seat as Last Resort
				local maxSeats = data.seatCount - 1
				for i = 1, maxSeats do
					local seat = (i < maxSeats) and i or 0

					local ent = GetPedInVehicleSeat(veh, seat)
					if ent == 0 then
						TaskWarpPedIntoVehicle(tPed, veh, seat)
						break
					end
				end
			else
				-- Favour Highest Back Seats First
				for i = (data.seatCount - 2), 0, -1 do
					local ent = GetPedInVehicleSeat(veh, i)
					if ent == 0 then
						TaskWarpPedIntoVehicle(tPed, veh, i)
						break
					end
				end
			end

			_clearPair(source, escorting)
			return true
		else
			return false
		end
	end,
	Stop = function(self, source)
		local escorting = _escorting[source]
		if escorting ~= nil then
			if GetPlayerEndpoint(escorting) then -- Check if player source still online
				local p = promise.new()
				plsr.Callbacks:ClientCallback(escorting, "Escort:StopEscort", {}, function()
					p:resolve(true)
				end)
				Citizen.Await(p)
			end

			_clearPair(source, escorting)
		end
	end,
	GetEscorting = function(self, source)
		return _escorting[source]
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Escort", _ESCORT)
end)

function RegisterCallbacks()
	plsr.Callbacks:RegisterServerCallback("Escort:DoEscort", function(source, data, cb)
		cb(plsr.Escort:Do(source, data))
	end)

	plsr.Callbacks:RegisterServerCallback("Escort:DoPutIn", function(source, data, cb)
		cb(plsr.Escort:DoPutIn(source, data))
	end)

	plsr.Callbacks:RegisterServerCallback("Escort:StopEscort", function(source, data, cb)
		plsr.Escort:Stop(source)
	end)
end

function RegisterMiddleware()

end

local function HandleLogout(source)
	local escorting = _escorting[source]
	local myEscorter = _escortedBy[source]

	if escorting ~= nil then
		if GetPlayerEndpoint(escorting) then -- Check if player source still online
			local p = promise.new()
			plsr.Callbacks:ClientCallback(escorting, "Escort:StopEscort", {}, function()
				p:resolve(true)
			end)
			Citizen.Await(p)
		end

		_clearPair(source, escorting)
	elseif myEscorter ~= nil then
		_clearPair(myEscorter, source)

		local p = promise.new()
		plsr.Callbacks:ClientCallback(source, "Escort:StopEscort", {}, function()
			p:resolve(true)
		end)
		Citizen.Await(p)
	end
end

AddEventHandler("Characters:Server:PlayerLoggedOut", HandleLogout)
AddEventHandler("Characters:Server:PlayerDropped", HandleLogout)

RegisterNetEvent("Ped:Server:Died", function()
	local src = source
	local escorting = _escorting[src]
	local myEscorter = _escortedBy[src]

	if escorting ~= nil then
		_clearPair(src, escorting)
	elseif myEscorter ~= nil then
		_clearPair(myEscorter, src)
	end
end)

RegisterNetEvent("Escort:Server:ForceStop", function()
	local src = source
	local escorting = _escorting[src]
	local myEscorter = _escortedBy[src]

	if escorting ~= nil then
		_clearPair(src, escorting)
	elseif myEscorter ~= nil then
		_clearPair(myEscorter, src)
	end
end)

RegisterNetEvent("Escort:Server:DoPutIn", function(veh)
	local src = source
	local escorting = _escorting[src]

	if escorting ~= nil then
		plsr.Callbacks:ClientCallback(escorting, "Escort:StopEscort", {}, function() end)
	end
end)
