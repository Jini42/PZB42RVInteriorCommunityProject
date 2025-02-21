-- Do nothing in multiplayer on the server (isServer always returns false in single player)
if isServer() then return end

-- The speed returned for a parked vehicle can sometimes end up non-zero, so set a threshold for "stationary"
local stationaryThreshold = 0.2

------------------------------------------------------------------------------------------------------------------------
-- Entering vehicles
------------------------------------------------------------------------------------------------------------------------

--- Test if its unsafe for a player to enter their vehicle interior, based on the sandbox settings.  This can only be
--- tested client-side because IsoCell:getNearestVisibleZombie() appears to be client only.
local function getPlayerHassledByZombiesReason(vehicle, player)
    if math.abs(vehicle:getCurrentSpeedKmHour()) >= stationaryThreshold then
        -- Zombies nearby shouldn't stop someone entering if the vehicle is on the move.
        return nil
    end
    if SandboxVars.RVInterior.NotWhenChased and player:getStats():getNumChasingZombies() > 0 then
        return getText("UI_zombiesChasing")
    end
    local zombie = getCell():getNearestVisibleZombie(player:getPlayerNum())
    if SandboxVars.RVInterior.SafeZombieDistance > 0 and zombie and
            zombie:getSquare():getMovingObjects():indexOf(zombie) >= 0 then -- to ignore deleted zombies
        local distance = IsoUtils.DistanceToSquared(zombie:getX(), zombie:getY(), zombie:getZ(),
                player:getX(), player:getY(), player:getZ())
        if distance < SandboxVars.RVInterior.SafeZombieDistance * SandboxVars.RVInterior.SafeZombieDistance then
            return getText("UI_zombiesNearby")
        end
    end
    return nil
end

-- Callback to signal the server that a player is trying to enter a vehicle interior
local function onPlayerEnterInterior(player)
    -- Turns out you can exit a vehicle while still interacting with the radial menu, so re-check validity.
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if not RVInterior.vehicleHasInteriorParameters(vehicle) then
        return
    end
    if not player:getVehicle() then
        local vehicleName = vehicle:getScript():getFullName()
        -- Do additional checks if they're entering from outside the vehicle.
        if not RVInterior.canEnterFromBackList[vehicleName] then
            return
        end
        local part = vehicle:getUseablePart(player)
        if not part then
            return
        end
        if part:getId() ~= "TrunkDoor" and part:getId() ~= "DoorRear" and
                part:getId() ~= "DoorRearLeft" and part:getId() ~= "DoorRearRight" then
            return
        end
        if vehicle:isTrunkLocked() then
            vehicle:playPartSound(part, player, "IsLocked")
            return
        end
    end
    local hassled = getPlayerHassledByZombiesReason(vehicle, player)
    if hassled then
        player:Say(getText("UI_cantEnter"))
        player:Say(hassled)
    elseif RVInterior.isPlayerTrespassingInInterior(vehicle, player) then
        player:Say(getText("UI_cantEnter"))
        player:Say(getText("UI_noEnterInteriorSafehouse"))
    elseif vehicle:isDriver(player) and math.abs(vehicle:getCurrentSpeedKmHour()) >= stationaryThreshold then
        player:Say(getText("UI_cantEnter"))
        player:Say(getText("UI_vehicleMoving"))
    else
        sendClientCommand(player, "RVInterior","clientStartEnterInterior",{ vehicleId = vehicle:getId() })
    end
end

-- Loads the textures.
local function loadRVInteriorTextures()
    getTexture("media/textures/rvInteriorEnter.png")       -- Radial Menu UI - enter (normal)
    getTexture("media/textures/rvInteriorEnterGrey.png")   -- Radial Menu UI - enter (disabled)
end
Events.OnGameBoot.Add(loadRVInteriorTextures)

-- Save the default function so we can invoke it from within our wrapper
if not RVInterior.oldShowRadialMenu then
    RVInterior.oldShowRadialMenu = ISVehicleMenu.showRadialMenu
end
if not RVInterior.old_ISVehicleMenu_showRadialMenuOutside then
    RVInterior.old_ISVehicleMenu_showRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside
end

-- Wrap the current version of showRadialMenu with our own version.
function ISVehicleMenu.showRadialMenu(player)
    RVInterior.oldShowRadialMenu(player)
    RVInterior.showRadialMenu(player)
end

function RVInterior.addRadialMenu(player)
    if player:isNPC() then return end
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if not vehicle then return end
    local vehicleName = vehicle:getScript():getFullName()
    if not vehicleName then return end

    -- If they're inside a supported vehicle type, add the radial option to enter the interior.
    if RVInterior.vehicleHasInteriorParameters(vehicle) and vehicle then
        local menu = getPlayerRadialMenu(player:getPlayerNum())
        local texture = getTexture("media/textures/rvInteriorEnter.png")
        if getPlayerHassledByZombiesReason(vehicle, player) or
                RVInterior.isPlayerTrespassingInInterior(vehicle, player) or
                (vehicle:isDriver(player) and math.abs(vehicle:getCurrentSpeedKmHour()) >= stationaryThreshold) then
            -- Grey out the enter option if they can't enter
            texture = getTexture("media/textures/rvInteriorEnterGrey.png")
        end
        return vehicle, vehicleName, menu, texture
    else return end
end

function RVInterior.showRadialMenu(player)
    if not RVInterior.addRadialMenu(player) then return end
    local _vehicle, vehicleName, menu, texture = RVInterior.addRadialMenu(player)
    if player:isSeatedInVehicle() then
        if not RVInterior.canEnterFromBackList[vehicleName] then
            menu:addSlice(getText("UI_enterrvinterior"), texture, onPlayerEnterInterior, player)
        end
    end
end

function ISVehicleMenu.showRadialMenuOutside(player)
    RVInterior.old_ISVehicleMenu_showRadialMenuOutside(player)
    if not RVInterior.addRadialMenu(player) then return end
    local vehicle, vehicleName, menu, texture = RVInterior.addRadialMenu(player)
    if RVInterior.canEnterFromBackList[vehicleName] then
        local part = vehicle:getUseablePart(player)
        if not part then return end
        if not vehicle:isTrunkLocked() and (part:getId() == "TrunkDoor" or part:getId() == "DoorRear" or
                part:getId() == "DoorRearLeft" or part:getId() == "DoorRearRight") then
            menu:addSlice(getText("UI_enterrvinterior"), texture, onPlayerEnterInterior, player)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Exiting vehicles
------------------------------------------------------------------------------------------------------------------------

local function onPlayerSelectExit(player)
    if player:isSitOnGround() then
        player:setSitOnGround(false)
    end
    sendClientCommand(player, "RVInterior","clientStartExitInterior", {})
end

local function addExitOption(playerId, context)
    local player = getSpecificPlayer(playerId)
    if RVInterior.playerInsideInterior(player) then
        context:addOption(getText("UI_exitrvinterior"), player, onPlayerSelectExit)
    end
end

Events.OnFillWorldObjectContextMenu.Add(addExitOption)

------------------------------------------------------------------------------------------------------------------------
-- Keyboard hotkey
------------------------------------------------------------------------------------------------------------------------

local keyData = {
    key = Keyboard.KEY_NONE, -- No default value, user needs to configure it.
    name = "RV_INTERIOR_ENTER", -- Maps to UI_optionscreen_binding_RV_INTERIOR_ENTER in Translate files
}

if ModOptions and ModOptions.getInstance then
    ModOptions:AddKeyBinding("[Vehicle]", keyData);
end

local function onKeyPressed(keyCode)
    if keyCode == keyData.key then
        local player = getSpecificPlayer(0) -- Keyboard shortcuts are just for the first player
        if RVInterior.playerInsideInterior(player) then
            onPlayerSelectExit(player)
        else
            onPlayerEnterInterior(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

------------------------------------------------------------------------------------------------------------------------
-- Server commands
------------------------------------------------------------------------------------------------------------------------

local serverCommandHandlers = {}

local function onServerCommand(module, command, arguments)
    if module ~= "RVInterior" then
        return
    end
    if serverCommandHandlers[command] then
        -- This peculiar expression works to get the player on this client from the onlineID in both SP and MP
        local player = getSpecificPlayer(arguments.playerId % 4)
        serverCommandHandlers[command](player, arguments)
    end
end

Events.OnServerCommand.Add(onServerCommand)

serverCommandHandlers.serverNoFreeInteriors = function(player)
    player:Say(getText("UI_noFreeInteriors"))
end

--- Jump to the vehicle entry point
local function sendPlayerToEntryCoordinates(player, vehicleName, interiorInstance)
    local coordinates = RVInterior.getInteriorCoordinates(vehicleName, interiorInstance)
    -- Current coordinates
    player:setX(coordinates.x + 0.5)
    player:setY(coordinates.y + 0.5)
    player:setZ(coordinates.z)
    -- Last coordinates, for movement calculation purposes
    player:setLx(player:getX())
    player:setLy(player:getY())
    player:setLz(player:getZ())
    -- Change facing
    player:faceLocation(coordinates.x, coordinates.y - 1)
end

--- If there are any zombies closer than 2 tiles from the player, stagger them. The cell loads asynchronously, and
--- there's no event to say that it's finished, so give the player a period of protection.
local function pushNearbyZombies(player)
    local finishTime = getTimestampMs() + 1500
    local pushZombiesClosure
    pushZombiesClosure = function ()
        if getTimestampMs() > finishTime then
            Events.OnTick.Remove(pushZombiesClosure)
        end
        local zombieList = getCell():getZombieList()
        for index = 0,zombieList:size()-1 do
            local zombie = zombieList:get(index)
            if zombie and zombie:getSquare():getMovingObjects():indexOf(zombie) >= 0 then
                local distance2 = IsoUtils.DistanceToSquared(zombie:getX(), zombie:getY(), zombie:getZ(),
                        player:getX(), player:getY(), player:getZ())
                if distance2 < 4 and not zombie:isStaggerBack() then
                    zombie:setStaggerBack(true)
                    zombie:setHitForce(1.0)
                    zombie:reportEvent("wasHit")
                end
            end
        end
    end
    Events.OnTick.Add(pushZombiesClosure)
end

local playerSeats = {}
--- Handle the player entering a vehicle interior
serverCommandHandlers.serverEnterInterior = function(player, arguments)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    local vehicleName = vehicle:getScript():getFullName()
    playerSeats[player:getOnlineID()] = vehicle:getSeat(player)
    if arguments.isBoat and TickControl.main then
        -- Disable Aquatsar's onTick which makes players in water get wet etc.
        Events.OnTick.Remove(TickControl.main)
    end
    vehicle:exit(player)
    if ChimeTick then
        -- Remove the Vehicle Light Chime mod's onTick callback, if present.
        Events.OnTick.Remove(ChimeTick)
    end
    getPlayerVehicleDashboard(player:getPlayerNum()):setVehicle(nil)
    sendPlayerToEntryCoordinates(player, vehicleName, arguments.interiorInstance)
    -- Wait for things to load before telling the server that we've entered.
    local retries = 500
    local playerEnteredInteriorClosure
    playerEnteredInteriorClosure = function()
        -- After a player has entered an interior, wait until at least the tile they're on has loaded and then tell
        -- the server to update the fuel in the generator.
        local square = player:getCurrentSquare()
        if square == nil then
            retries = retries - 1
            if retries == 0 then
                -- The interior map is not present - ask the player if they want to return to the vehicle.
                local mapsMissingDialogCallback = function (_this, button)
                    if button.internal == "YES" then
                        onPlayerSelectExit(player)
                        Events.OnPlayerUpdate.Remove(playerEnteredInteriorClosure)
                    else
                        -- Reset the retries counter
                        retries = 500
                    end
                end
                local mapsMissingDialog = ISModalDialog:new(0, 0, 250, 150,
                        getText("UI_rvInteriorMapsMissing"), true, nil, mapsMissingDialogCallback)
                mapsMissingDialog:initialise()
                mapsMissingDialog:addToUIManager()
                if JoypadState.players[player:getPlayerNum()+1] then
                    setJoypadFocus(player:getPlayerNum(), mapsMissingDialog)
                end
            end
            return
        end
        if arguments.isBoat and TickControl.main then
            -- Re-enable Aquatsar's onTick
            Events.OnTick.Add(TickControl.main)
        end
        sendClientCommand(player, "RVInterior", "clientFinishEnterInterior", {})
        pushNearbyZombies(player)
        Events.OnPlayerUpdate.Remove(playerEnteredInteriorClosure)
    end
    Events.OnPlayerUpdate.Add(playerEnteredInteriorClosure)
end

-- Test if a vehicle matches the expected name and interior instance.
local function doesVehicleMatch(vehicle, vehicleName, interiorInstance)
    local canonicalVehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName(), true)
    if canonicalVehicleName ~= vehicleName then
        return false
    end
    local modData = RVInterior.getVehicleModData(vehicle, RVInterior.getInteriorParameters(canonicalVehicleName))
    return modData and interiorInstance == modData.interiorInstance
end

--- Handle the player leaving an interior
serverCommandHandlers.serverLeaveInterior = function(player, arguments)
    player:setX(arguments.x)
    player:setY(arguments.y)
    player:setZ(arguments.z)
    player:setLx(arguments.x)
    player:setLy(arguments.y)
    player:setLz(arguments.z)
    if arguments.isBoat and TickControl.main then
        -- Disable Aquatsar's onTick which makes players in water get wet etc.
        Events.OnTick.Remove(TickControl.main)
    end
    local retries = 500
    local vehicleIndex = 0
    local playerLeftInteriorClosure
    playerLeftInteriorClosure = function ()
        -- Wait until at least the tile they're now on has loaded before trying to find the vehicle.
        local square = player:getCurrentSquare()
        if square == nil then
            return
        end
        -- Check if we've been trying for too long, and give up if so.
        retries = retries - 1
        if retries <= 0 then
            print("RVInterior WARNING: serverLeaveInterior unable to find vehicle, giving up.")
            if arguments.isBoat and TickControl.main then
                -- Re-enable Aquatsar's onTick
                Events.OnTick.Add(TickControl.main)
            end
            Events.OnPlayerUpdate.Remove(playerLeftInteriorClosure)
        end
        -- Try to locate the correct vehicle as they're loaded into memory.
        local allVehicles = getCell():getVehicles()
        if allVehicles:size() == 0 then
            return
        elseif vehicleIndex >= allVehicles:size() then
            vehicleIndex = 0
        end
        local vehicle = allVehicles:get(vehicleIndex)
        vehicleIndex = vehicleIndex + 1
        if not doesVehicleMatch(vehicle, arguments.vehicleName, arguments.interiorInstance) then
            return
        end
        local seat = playerSeats[player:getOnlineID()] or vehicle:getScript():getPassengerCount() - 1
        while seat >= 0 and (not vehicle:isSeatInstalled(seat) or vehicle:isSeatOccupied(seat)) do
            if seat == playerSeats[player:getOnlineID()] then
                seat = vehicle:getScript():getPassengerCount() - 1
                playerSeats[player:getOnlineID()] = nil
            else
                seat = seat - 1
            end
        end
        if seat >= 0 then
            -- We need to get the passenger position manually, as the two-argument `vehicle:enter` function only works
            -- if the seat they're trying to enter has a door leading to the outside.
            local position = vehicle:getPassengerPosition(seat, "inside")
            if position and position:getOffset() then
                vehicle:enter(seat, player, position:getOffset())
                triggerEvent("OnEnterVehicle", player)
            else
                print("RVInterior WARNING: exiting an interior of " .. vehicle:getScript():getFullName() ..
                        ", couldn't get the inside offset for seat ", seat)
            end
        else
            local vehicleName = vehicle:getScript():getFullName()
            if RVInterior.canEnterFromBackList[vehicleName] then
                local partArea = vehicle:getScript():getAreaById("TruckBed")
                local trunkX, trunkY = nil
                if not partArea then
                    local tempVector = Vector3f.new()
                    local shapeOffset = vehicle:getScript():getExtents():y()
                    local vecPos = vehicle:getWorldPos(0,0,-shapeOffset*1.5,tempVector)
                    trunkX = vecPos:x()
                    trunkY = vecPos:y()
                else
                    local partPos = vehicle:areaPositionWorld(partArea)
                    trunkX = partPos:getX()
                    trunkY = partPos:getY()
                end
                player:setX(trunkX)
                player:setY(trunkY)
                player:setLx(trunkX)
                player:setLy(trunkY)
            else
                -- They'll end up outside (clipped into) the vehicle.
                print("RVInterior WARNING: player exiting an interior didn't find an installed unoccupied seat.")
            end
        end
        if arguments.isBoat and TickControl.main then
            -- Re-enable Aquatsar's onTick
            Events.OnTick.Add(TickControl.main)
        end
        sendClientCommand(player, "RVInterior", "clientFinishExitInterior",
                { vehicleId = vehicle:getId() })
        pushNearbyZombies(player)
        Events.OnPlayerUpdate.Remove(playerLeftInteriorClosure)
    end
    Events.OnPlayerUpdate.Add(playerLeftInteriorClosure)
end

------------------------------------------------------------------------------------------------------------------------
-- Update modData as vehicle with interiors move.
------------------------------------------------------------------------------------------------------------------------

local function sendUpdateVehiclePosition(vehicle)
    if RVInterior.vehicleHasInteriorParameters(vehicle) then
        sendClientCommand("RVInterior", "updateVehiclePosition", { vehicleId = vehicle:getId() })
    end
end

local function watchIfPlayerDriving(player)
    local vehicle = player:getVehicle()
    -- If they're in the driver's seat, start watching them for movement.
    if vehicle:isDriver(player) then
        local delay = 0
        local lastSentTile
        local updateDrivingVehicleClosure
        updateDrivingVehicleClosure = function()
            -- Only check for updates once every 100 ticks.
            if delay > 0 then
                delay = delay - 1
                return
            end
            delay = 100
            local speed = math.abs(vehicle:getCurrentSpeedKmHour())
            -- If the vehicle starts moving, update positions immediately and every 70 meters.
            -- If the vehicle stops after previously moving, also update positions.
            if (speed >= stationaryThreshold and (not lastSentTile or lastSentTile:DistTo(player) > 70)) or
                    (speed < stationaryThreshold and lastSentTile) then
                -- If this vehicle has an interior, update its position.
                sendUpdateVehiclePosition(vehicle)
                -- If we're towing something with an interior, also update that vehicle's position.
                sendUpdateVehiclePosition(vehicle:getVehicleTowing())
                if speed < stationaryThreshold then
                    lastSentTile = nil
                else
                    lastSentTile = vehicle:getSquare()
                end
            end
            -- If they're no longer driving and the vehicle is stationary, stop updating the vehicle position.
            if not vehicle:isDriver(player) and not lastSentTile then
                Events.OnPlayerUpdate.Remove(updateDrivingVehicleClosure)
            end
        end
        Events.OnPlayerUpdate.Add(updateDrivingVehicleClosure)
    end
end

Events.OnEnterVehicle.Add(watchIfPlayerDriving)
Events.OnSwitchVehicleSeat.Add(watchIfPlayerDriving)

------------------------------------------------------------------------------------------------------------------------
-- Other events
------------------------------------------------------------------------------------------------------------------------

--- Test if the player has spawned inside a vehicle interior (e.g. respawned in a safehouse on MP), and put them at the
--- normal vehicle interior entry point if so.
local function onPlayerRespawnInVehicleInterior(player)
    local interior = RVInterior.calculatePlayerInteriorInstance(player)
    if not interior then
        -- They didn't start inside a vehicle interior
        return
    end
    print("RVInterior info: OnNewGame spawned player inside a vehicle interior for vehicle ",
            interior.vehicleName, " instance ", interior.interiorInstance)
    -- Jump them to the normal entry point, as if they'd just entered.
    sendPlayerToEntryCoordinates(player, interior.vehicleName, interior.interiorInstance)
end

Events.OnNewGame.Add(onPlayerRespawnInVehicleInterior);