local customOffsets = {
	[`taxi`] = { y = 0.0, z = -0.5 },
	[`buccaneer`] = { y = 0.5, z = 0.0 },
	[`peyote`] = { y = 0.35, z = -0.15 },
	[`regina`] = { y = 0.2, z = -0.35 },
	[`pigalle`] = { y = 0.2, z = -0.15 },
	[`glendale`] = { y = 0.0, z = -0.35 },
}

local _inTrunkVeh = nil

CreateThread(function()
	plsr.State.flags.inTrunk = false

	plsr.Callbacks:RegisterClientCallback("Trunk:GetPutIn", function(data, cb)
		if NetworkDoesEntityExistWithNetworkId(data) then
			InTrunk(NetToVeh(data))
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Trunk:GetPulledOut", function(data, cb)
		if plsr.State.flags.inTrunk then
			plsr.Trunk:GetOut()

			while plsr.State.flags.inTrunk do
				Wait(5)
			end

			cb(true)
		else
			cb(false)
		end
	end)
end)

AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
	if plsr.State.flags.inTrunk and (not plsr.State.flags.isDead and not plsr.State.flags.isCuffed) then
		plsr.Trunk:GetOut()
	end
end)

AddEventHandler("Keybinds:Client:KeyUp:secondary_action", function()
	if plsr.State.flags.inTrunk and (not plsr.State.flags.isDead and not plsr.State.flags.isCuffed) then
		plsr.Trunk:ToggleTrunk()
	end
end)

function loadAnimDict(dict)
	RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do
		Wait(0)
	end
end

local cam = nil
function MountTrunkCam()
	if not DoesCamExist(cam) then
		cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
		SetCamRot(cam, 0.0, 0.0, 0.0)
		SetCamActive(cam, true)
		RenderScriptCams(true, false, 0, true, true)
		SetCamCoord(cam, plsr.State.flags.position)
	end
	AttachCamToEntity(cam, PlayerPedId(), 0.0, -2.5, 1.0, true)
	SetCamRot(cam, -30.0, 0.0, GetEntityHeading(PlayerPedId()))
end

function UnmountTrunkCam()
	RenderScriptCams(false, false, 0, 1, 0)
	DestroyCam(cam, false)
	cam = nil
end

function InTrunk(veh)
	if not DoesVehicleHaveDoor(veh, 6) and DoesVehicleHaveDoor(veh, 5) and IsThisModelACar(GetEntityModel(veh)) then
		DoScreenFadeOut(200)
		while not IsScreenFadedOut() do
			Wait(10)
		end

		local min, max = GetModelDimensions(GetEntityModel(veh))
		local trunkZ = max.z
		if trunkZ > 1.4 then
			trunkZ = 1.4 - (max.z - 1.4)
		end

		_inTrunkVeh = veh
		--Entity(veh).state.VIN
		plsr.State.flags.inTrunk = true
		TriggerServerEvent("Trunk:Server:Enter", VehToNet(veh))

		while not plsr.State.flags.inTrunk do
			Wait(5)
		end

		local animDict = "mp_common_miss"
		local anim = "dead_ped_idle"

		loadAnimDict(animDict)

		DetachEntity(PlayerPedId())
		SetPedKeepTask(PlayerPedId(), true)
		ClearPedTasks(PlayerPedId())
		TaskPlayAnim(PlayerPedId(), animDict, anim, 8.0, 8.0, -1, 2, 999.0, 0, 0, 0)

		local vehicleName = GetEntityModel(veh)
		local trunkOffsets = customOffsets[vehicleName] or { y = 0.0, z = 0.0 }

		AttachEntityToEntity(
			PlayerPedId(),
			veh,
			0,
			-0.1,
			(min.y + 0.85) + trunkOffsets.y,
			(trunkZ - 0.87) + trunkOffsets.z,
			0,
			0,
			40.0,
			1,
			1,
			1,
			1,
			1,
			1
		)

		SetVehicleDoorsShut(veh, 5, true, false)
		MountTrunkCam()

		DoScreenFadeIn(1000)
		while not IsScreenFadedIn() do
			Wait(10)
		end

		if not plsr.State.flags.isCuffed and not plsr.State.flags.isDead then
			plsr.Action:Show(
				"trunk",
				"{keybind}primary_action{/keybind} Exit Trunk | {keybind}secondary_action{/keybind} Open/Close Trunk"
			)
		end

		while plsr.State.flags.loggedIn and plsr.State.flags.inTrunk and veh == _inTrunkVeh do
			--MountTrunkCam()

			if not IsVehicleSeatFree(veh, -1) then
				if DoesCamExist(cam) then
					UnmountTrunkCam()
				end
				local p = GetPedInVehicleSeat(veh, -1)
				SetGameplayCamFollowPedThisUpdate(p)
			else
				local n = GetVehicleNumberOfPassengers(veh)
				if n > 0 then
					if DoesCamExist(cam) then
						UnmountTrunkCam()
					end
					for seat = 0, n + 1 do
						if not IsVehicleSeatFree(veh, seat) then
							local p = GetPedInVehicleSeat(veh, seat)
							SetGameplayCamFollowPedThisUpdate(p)
						end
					end
				elseif not DoesCamExist(cam) then
					MountTrunkCam()
				end
			end

			if not DoesEntityExist(veh) then
				plsr.Trunk:GetOut()
			end

			if not IsEntityPlayingAnim(PlayerPedId(), animDict, anim, 3) then
				TaskPlayAnim(PlayerPedId(), animDict, anim, 8.0, 8.0, -1, 1, 999.0, 0, 0, 0)
			end


			Wait(1)
		end

		if veh == _inTrunkVeh then
			DoScreenFadeOut(200)
			while not IsScreenFadedOut() do
				Wait(10)
			end

			plsr.Action:Hide("trunk")
			SetVehicleDoorOpen(_inTrunkVeh, 5, 1, 1)
			UnmountTrunkCam()
			DetachEntity(PlayerPedId())
			if DoesEntityExist(veh) then
				local exit = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.5, 0.0)
				SetEntityCoords(PlayerPedId(), exit.x, exit.y, exit.z)
			else
				SetEntityCoords(PlayerPedId(), GetEntityCoords(PlayerPedId()))
			end

			_inTrunkVeh = nil
			DoScreenFadeIn(1000)
			while not IsScreenFadedIn() do
				Wait(10)
			end
		end
	end
end

_TRUNK = {
	GetIn = function(self, veh)
		InTrunk(veh)
	end,
	GetOut = function(self)
		TriggerServerEvent("Trunk:Server:Exit", VehToNet(_inTrunkVeh))
	end,
	ToggleTrunk = function(self)
		if GetVehicleDoorAngleRatio(_inTrunkVeh, 5) > 0.0 then
			--SetVehicleDoorsShut(_inTrunkVeh, 5, true, false)
			plsr.Vehicles.Sync.Doors:Shut(_inTrunkVeh, 5, true)
		else
			--SetVehicleDoorOpen(_inTrunkVeh, 5, true, true)
			plsr.Vehicles.Sync.Doors:Open(_inTrunkVeh, 5, false, false)
		end
	end,
}

RegisterNetEvent("Trunk:Client:Exit", function()
	plsr.State.flags.inTrunk = false
end)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Trunk", _TRUNK)
end)

AddEventHandler("Trunk:Client:GetIn", function(entity, data)
	InTrunk(entity.entity)
end)

AddEventHandler("Ped:Client:Died", function()
	if plsr.State.flags.inTrunk then
		plsr.Trunk:GetOut()
	end
end)

AddEventHandler("Trunk:Client:PutIn", function(entity, data)
	plsr.Callbacks:ServerCallback("Trunk:PutIn", NetworkGetNetworkIdFromEntity(entity.entity), function(state) end)
end)

AddEventHandler("Trunk:Client:PullOut", function(entity, data)
	plsr.Callbacks:ServerCallback("Trunk:PullOut", NetworkGetNetworkIdFromEntity(entity.entity), function(state) end)
end)
