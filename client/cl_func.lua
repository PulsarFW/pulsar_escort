local _gJobs = {
	police = 3000,
	ems = 1500,
}

function DoEscort()
	local cPlayer, Dist = plsr.Game.Players:GetClosestPlayer()
	local tarPlayer = GetPlayerServerId(cPlayer)
	local closeDist = 1
	if IsPedSwimming(PlayerPedId()) then
		closeDist = 15
	end

	if plsr.State.flags.myEscorter == nil and not plsr.State.flags.isDead then
		if tarPlayer ~= 0 and Dist <= closeDist then
			if
				plsr.State.flags.isEscorting == nil
				and not IsPedInAnyVehicle(PlayerPedId(), true)
				and not IsPedInAnyVehicle(GetPlayerPed(tarPlayer), true)
				and not plsr.Hud:IsDisabledAllowDead()
				and not plsr.State:GetPublicFlag(tarPlayer, 'isHospitalized')
				and (plsr.State:GetPublicFlag(tarPlayer, 'isEscorting') == nil and plsr.State:GetPublicFlag(tarPlayer, 'myEscorter') == nil)
			then
				plsr.Escort:DoEscort(tarPlayer, cPlayer)
			elseif plsr.State.flags.isEscorting ~= nil then
				plsr.Escort:StopEscort()
			end
		end
	end
end

function StartEscortThread(t)
	while plsr.State.flags.isEscorting == nil do
		Wait(10)
	end

	CreateThread(function()
		local ped = GetPlayerPed(t)
		local myped = PlayerPedId()

		while plsr.State.flags.isEscorting ~= nil do
			if (not plsr.State.flags.onDuty or (plsr.State.flags.onDuty ~= "ems")) and not IsPedSwimming(ped) then
				DisableControlAction(1, 21, true) -- Sprint
			end
			DisableControlAction(1, 23, true) -- F
			Wait(5)
		end
	end)

	CreateThread(function()
		local ped = GetPlayerPed(t)

		while plsr.State.flags.isEscorting ~= nil do
			Wait(500)
            if not DoesEntityExist(ped) then
                plsr.Escort:StopEscort()
            end
		end
	end)
end

RegisterNetEvent("Escort:Client:Escorted", function()
	_fuckSake = true
	while plsr.State.flags.myEscorter == nil do
		Wait(10)
	end

	if plsr.State.flags.isCuffed then
		TriggerEvent("Handcuffs:Client:DoShittyAnim")
	end

	if plsr.State.flags.sitting then
		TriggerEvent("Animations:Client:StandUp", true)
	end

	if plsr.State.flags.doingAction then
		plsr.Progress:Cancel()
	end

	CreateThread(function()
		local ped = GetPlayerPed(GetPlayerFromServerId(plsr.State.flags.myEscorter))
		local myped = PlayerPedId()

		while not DoesEntityExist(ped) do
			Wait(1)
			ped = GetPlayerPed(GetPlayerFromServerId(plsr.State.flags.myEscorter))
		end

		local correctedZ = 0
		local escortermodel = GetEntityModel(ped)
		if escortermodel == `mythic_k9_shepherd` then
			correctedZ = 0.5
		end

		AttachEntityToEntity(
			PlayerPedId(),
			ped,
			11816,
			0.54,
			0.44,
			0.0 + correctedZ,
			0.0,
			0.0,
			0.0,
			false,
			false,
			false,
			false,
			2,
			true
		)
		while plsr.State.flags.myEscorter ~= nil do
			DisableControlAction(1, 21, true) -- Sprint
			DisableControlAction(1, 22, true) -- Jump
			DisableControlAction(1, 23, true) -- F
			Wait(5)
		end
		DetachEntity(PlayerPedId(), true, true)
	end)
end)

AddEventHandler("Escort:Client:PutIn", function(entity, data)
	plsr.Callbacks:ServerCallback("Escort:DoPutIn", {
		veh = NetworkGetNetworkIdFromEntity(entity.entity),
		class = GetVehicleClass(entity.entity),
		seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(entity.entity)),
	}, function(state) end)
end)

AddEventHandler("Escort:Client:PullOut", function(entity, data)
	local vehmodel = GetEntityModel(entity.entity)
    local vehClass = GetVehicleClass(entity.entity)

    local targetSeat = nil
    local targetPed = nil

    if vehClass == 18 then
        -- Favour Highest Back Seats First
        for i = GetVehicleModelNumberOfSeats(vehmodel), -1, -1 do
            local ent = GetPedInVehicleSeat(entity.entity, i)
            if ent ~= 0 then
                targetSeat = i
                targetPed = ent
                break
            end
        end
    else
        for i = -1, GetVehicleModelNumberOfSeats(vehmodel) do
            local ent = GetPedInVehicleSeat(entity.entity, i)
            if ent ~= 0 then
                targetSeat = i
                targetPed = ent
                break
            end
        end
    end

    if targetSeat and targetPed then
        local dur = 5000
        if _gJobs[plsr.State.flags.onDuty] ~= nil then
            dur = _gJobs[plsr.State.flags.onDuty]
        end

        plsr.Progress:ProgressWithTickEvent({
            name = "unseat",
            duration = dur,
            label = "Unseating",
            useWhileDead = false,
            canCancel = true,
            animation = false,
            ignoreModifier = true,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
        }, function()
            if
                #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity.entity)) <= 5.0
                and GetPedInVehicleSeat(entity.entity, targetSeat) == targetPed
            then
                return
            end
            plsr.Progress:Cancel()
        end, function(cancelled)
            if not cancelled then
                local playerId = NetworkGetPlayerIndexFromPed(targetPed)
                plsr.Escort:DoEscort(GetPlayerServerId(playerId), playerId)
            end
        end)
    end
end)
