CreateThread(function()
	plsr.Callbacks:RegisterServerCallback("Trunk:PutIn", function(source, data, cb)
		local t = plsr.Escort:GetEscorting(source)

		if t ~= nil then
			plsr.Escort:Stop(source)
			plsr.Callbacks:ClientCallback(t, "Trunk:GetPutIn", data)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Trunk:PullOut", function(source, data, cb)
		local ent = NetworkGetEntityFromNetworkId(data)
		local entState = plsr.State.Entity(ent)

		if entState.trunkOccupied then
			plsr.Callbacks:ClientCallback(entState.trunkOccupied, "Trunk:GetPulledOut", {}, function()
				Wait(500)
				plsr.Escort:Do(source, {
					target = entState.trunkOccupied,
					inVeh = false,
				})
			end)
		end
	end)
end)


local _trunkOccupied = {}
_TRUNK = {
	Enter = function(self, source, netId)
		plsr.State:SetPlayerFlag(source, 'trunkVeh', netId, true)

		local ent = NetworkGetEntityFromNetworkId(netId)
		if ent then
			local entState = plsr.State.Entity(ent)
			if not entState.trunkOccupied then
				entState.trunkOccupied = source

				-- GlobalState[string.format("PlayerTrunk:%s", source)] = netId
				-- local t = GlobalState[string.format("Trunk:%s", netId)] or {}
				-- table.insert(t, source)
				-- GlobalState[string.format("Trunk:%s", netId)] = t
			end
		end
	end,
	Exit = function(self, source, netId)
		local trunkVeh = plsr.State:Player(source).trunkVeh

		if trunkVeh then
			local ent = NetworkGetEntityFromNetworkId(trunkVeh)
			if ent then
				local entState = plsr.State.Entity(ent)
				if entState?.trunkOccupied and entState?.trunkOccupied == source then
					entState.trunkOccupied = nil
				end
			end

			TriggerClientEvent("Trunk:Client:Exit", source)
			plsr.State:SetPlayerFlag(source, 'trunkVeh', nil, true)
		end

		-- if GlobalState[string.format("Trunk:%s", netId)] ~= nil then
		-- 	local newTable = {}
		-- 	for k, v in ipairs(GlobalState[string.format("Trunk:%s", netId)]) do
		-- 		if source == v then
		-- 			GlobalState[string.format("PlayerTrunk:%s", source)] = nil
		-- 			TriggerClientEvent("Trunk:Client:Exit", source)
		-- 		else
		-- 			table.insert(newTable, v)
		-- 		end
		-- 	end

		-- 	GlobalState[string.format("Trunk:%s", netId)] = newTable
		-- elseif GlobalState[string.format("PlayerTrunk:%s", source)] then -- Car Probably Deleted
		-- 	GlobalState[string.format("PlayerTrunk:%s", source)] = nil
		-- 	TriggerClientEvent("Trunk:Client:Exit", source)
		-- end
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Trunk", _TRUNK)
end)

AddEventHandler("Characters:Server:PlayerLoggedOut", function(source, cData)
	if plsr.State:Player(source).trunkVeh then
		plsr.Trunk:Exit(source, GlobalState[string.format("PlayerTrunk:%s", source)])
	end
end)

AddEventHandler("Characters:Server:PlayerDropped", function(source, cData)
	if plsr.State:Player(source).trunkVeh then
		plsr.Trunk:Exit(source, GlobalState[string.format("PlayerTrunk:%s", source)])
	end
end)

RegisterNetEvent("Trunk:Server:Enter", function(netId)
	plsr.Trunk:Enter(source, netId)
end)

RegisterNetEvent("Trunk:Server:Exit", function(netId)
	plsr.Trunk:Exit(source, netId)
end)
