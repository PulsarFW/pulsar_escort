local _timeout = false

CreateThread(function()
	plsr.State.flags.AllowEscorting = true

	plsr.Keybinds:Add("escort", "k", "keyboard", "Escort", function()
		if _timeout then
			plsr.Notification:Error("Stop spamming you pepega.")
			return
		end
		_timeout = true
		DoEscort()
		Citizen.SetTimeout(1000, function()
			_timeout = false
		end)
	end)

	plsr.Callbacks:RegisterClientCallback("Escort:StopEscort", function(data, cb)
		DetachEntity(PlayerPedId(), true, true)
		cb(true)
	end)
end)

ESCORT = {
	DoEscort = function(self, target, tPlayer)
		if target ~= nil then
			if plsr.State.flags.AllowEscorting == false then
				plsr.Notification:Error("Unable to escort in this location.")
				return
			end
			plsr.Callbacks:ServerCallback("Escort:DoEscort", {
				target = target,
				inVeh = IsPedInAnyVehicle(GetPlayerPed(tPlayer)),
				isSwimming = IsPedSwimming(PlayerPedId()),
			}, function(state)
				if state then
					StartEscortThread(tPlayer)
				end
			end)
		end
	end,
	StopEscort = function(self)
		plsr.Callbacks:ServerCallback("Escort:StopEscort", function() end)
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Escort", ESCORT)
end)

AddEventHandler("Interiors:Exit", function()
	if plsr.State.flags.isEscorting ~= nil then
		plsr.Escort:StopEscort()
	end
end)

--[[ TODO
Add Dragging When Dead
Place In vehicle while Dead Slump Animation
Police Drag Maybe Cuff Also
Get In Trunk or Place in trunk???
]]
