-- Do nothing in multiplayer on the client (isClient always returns false in single player)
if isClient() then return end

local modDataName = "rvInteriorMod"
local batteryChargeToFuel = 100 -- the %age of fuel the generator gets for a fully-charged battery.

-- ModData access functions

local function checkModData(vehicleName)
    if not ModData.exists(modDataName) then
        ModData.add(modDataName, {
            interiors = {}
        })
    end
    if vehicleName and ModData.get(modDataName).interiors[vehicleName] == nil then
        ModData.get(modDataName).interiors[vehicleName] = {
            interiorCount = 0,
            interiorData = {}
        }
    end
end

local function getInteriorModData(vehicleName, interiorInstance, create)
    checkModData(vehicleName)
    if not interiorInstance then
        return ModData.get(modDataName).interiors[vehicleName]
    else
        local interiorData = ModData.get(modDataName).interiors[vehicleName].interiorData[interiorInstance]
        if interiorData or not create then
            return interiorData
        else
            return {}
        end
    end
end

local function setInteriorModData(vehicleName, interiorInstance, interiorData)
    checkModData(vehicleName)
    local data = ModData.get(modDataName)
    data.interiors[vehicleName].interiorData[interiorInstance] = interiorData
    ModData.add(modDataName, data)
    return interiorData
end

-- Wrap sendServerCommand to invoke the event handler for singleplayer, because the game engine stupidly doesn't do it.
local function sendServerCommandTo(player, module, command, arguments)
    arguments = arguments or {}
    arguments.playerId = player:getOnlineID()
    if isServer() then
        sendServerCommand(player, module, command, arguments)
    else
        triggerEvent("OnServerCommand", module, command, arguments)
    end
end

-- Generic handler for client commands
local clientCommandHandlers = {}
local adminClientCommandHandlers = {}
local clientVehicleCommandHandlers = {}

local allCommandHandlers = {
    RVInterior = clientCommandHandlers,
    RVInteriorAdmin = adminClientCommandHandlers,
    vehicle = clientVehicleCommandHandlers
}

local function onClientCommand(module, command, player, arguments)
    local handers = allCommandHandlers[module]
    if handers and handers[command] then
        handers[command](player, arguments)
    end
end

Events.OnClientCommand.Add(onClientCommand)

--- Battery charge and generator fuel need to be synched, but the current values for both are rarely available at the
--- same time because they're in very distant cells.  We handle this by storing the last value for both that was last
--- synched, as well as tracking pending changes from each that hasn't yet been applied to the other.  After this
--- function in invoked with a given current level (batteryCharge or fuelLevel), the value of that level in
--- interiorData can be immediately applied back to the source (battery or generator).
---@param interiorData table The mod data stored for this particular interior.  Modified by this function.
---@param batteryCharge nil | number The current battery charge, if available.
---@param fuelLevel nil | number The current generator fuel level, if available.
local function synchBatteryAndGenerator(interiorData, batteryCharge, fuelLevel)
    if fuelLevel and not interiorData.fuelLevel and interiorData.batteryCharge then
        -- Special case: a freshly created generator's fuel should be set purely based on batteryCharge.
        fuelLevel = interiorData.batteryCharge * batteryChargeToFuel
    end
    -- Track how much the battery charge and fuel level have changed since the last time things were synched.
    interiorData.batteryUsage = interiorData.batteryUsage or 0
    if batteryCharge and interiorData.batteryCharge then
        interiorData.batteryUsage = interiorData.batteryUsage + interiorData.batteryCharge - batteryCharge
    end
    interiorData.fuelUsage = interiorData.fuelUsage or 0
    if fuelLevel and interiorData.fuelLevel then
        interiorData.fuelUsage = interiorData.fuelUsage + interiorData.fuelLevel - fuelLevel
    end
    -- Update the current battery charge and fuel level with available new values, applying any pending usage.
    if batteryCharge then
        if interiorData.fuelUsage ~= 0 then
            -- There is pending fuelUsage - apply it to the battery charge.
            batteryCharge = math.min(1, math.max(0, batteryCharge - interiorData.fuelUsage / batteryChargeToFuel))
            interiorData.fuelUsage = 0
        end
        interiorData.batteryCharge = batteryCharge
    end
    if fuelLevel then
        if interiorData.batteryUsage ~= 0 then
            -- There is pending batteryUsage - apply it to the fuel level.
            fuelLevel = math.min(batteryChargeToFuel, math.max(0, fuelLevel - interiorData.batteryUsage * batteryChargeToFuel))
            interiorData.batteryUsage = 0
        end
        interiorData.fuelLevel = fuelLevel
    end
end

local function getConnectedBattery(vehicle)
    if vehicle:getPartById("Battery") and vehicle:getPartById("Battery"):getCategory() ~= "nodisplay" then
        return vehicle:getPartById("Battery"):getInventoryItem()
    elseif vehicle:getVehicleTowedBy() and vehicle:getVehicleTowedBy():getPartById("Battery") then
        return vehicle:getVehicleTowedBy():getPartById("Battery"):getInventoryItem()
    else
        return nil
    end
end

local function getBatteryCharge(vehicle)
    local battery = getConnectedBattery(vehicle)
    if battery then
        return battery:getUsedDelta()
    else
        return 0
    end
end

local function updateVehicleBattery(vehicleName, interiorInstance, vehicle)
    local interiorData = getInteriorModData(vehicleName, interiorInstance, true)
    synchBatteryAndGenerator(interiorData, getBatteryCharge(vehicle))
    -- Apply any changes back to the battery
    local battery = getConnectedBattery(vehicle)
    -- It's legal for a vehicle to have no battery.
    if battery ~= nil then
        battery:setUsedDelta(interiorData.batteryCharge)
    end
    setInteriorModData(vehicleName, interiorInstance, interiorData)
    return interiorData
end

local function updateInteriorGenerator(vehicleName, interiorInstance, generator)
    local interiorData = getInteriorModData(vehicleName, interiorInstance, true)
    synchBatteryAndGenerator(interiorData, nil, generator:getFuel())
    -- Apply any changes back to the generator
    generator:setFuel(interiorData.fuelLevel)
    generator:setActivated(interiorData.fuelLevel > 0)
    generator:setSurroundingElectricity()
    setInteriorModData(vehicleName, interiorInstance, interiorData)
    return interiorData
end

--- Handle players entering vehicles
clientCommandHandlers.clientStartEnterInterior = function (player, arguments)
    local vehicleId = arguments.vehicleId
    local vehicle = getVehicleById(vehicleId)
    if vehicle == nil then
        print("RVInterior ERROR: player tried to enter interior for unknown vehicleId ", vehicleId)
        return
    end
    if RVInterior.isPlayerTrespassingInInterior(vehicle, player) then
        -- This shouldn't happen, since we check for safehouses in the client, but you can't trust the client.
        print("RVInterior WARNING: player ", player:getFullName(),
                " tried to enter no-trespass safehouse interior.  Their client should have prevented them from trying.")
        return
    end
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
    checkModData(vehicleName)
    local interiorParams = RVInterior.getInteriorParameters(vehicleName)
    local vehicleModData = RVInterior.getVehicleModData(vehicle, interiorParams)
    -- Initialise vehicle modData if required
    if not vehicleModData then
        local maxInteriors = RVInterior.interiorSquare * RVInterior.interiorSquare
        -- The interiorCount might have got out of sync in previous versions or through use of the debug menu, so
        -- recalculate it whenever we try to assign a new interior.
        local interiorCount = 0
        for instance = 1, maxInteriors do
            if getInteriorModData(vehicleName, instance) then
                interiorCount = interiorCount + 1
            end
        end
        if interiorCount ~= getInteriorModData(vehicleName).interiorCount then
            print('RVInterior WARNING: interiorCount for ' .. vehicleName .. ' is ' ..
                    getInteriorModData(vehicleName).interiorCount .. ' but should be ' .. interiorCount ..
                    ' - setting to '.. interiorCount)
            getInteriorModData(vehicleName).interiorCount = interiorCount
        end
        if interiorCount >= maxInteriors then
            print("RVInterior WARNING: no more interiors available for vehicle type ", vehicleName)
            -- Send the player an explanation
            sendServerCommandTo(player, "RVInterior", "serverNoFreeInteriors")
            return
        end
        local interiorInstance
        repeat
            interiorInstance = ZombRand(maxInteriors) + 1
        until not getInteriorModData(vehicleName, interiorInstance)
        vehicleModData = {
            interiorInstance = interiorInstance
        }
        vehicle:getModData().rvInterior = vehicleModData
    end
    local interiorInstance = vehicleModData.interiorInstance
    -- Increment the interior count if there's no current modData for this interior
    if not getInteriorModData(vehicleName, interiorInstance) then
        getInteriorModData(vehicleName).interiorCount = getInteriorModData(vehicleName).interiorCount + 1
    end
    -- Update the mod data for the interior
    local interiorData = updateVehicleBattery(vehicleName, interiorInstance, vehicle)
    interiorData.vehicleX = vehicle:getX()
    interiorData.vehicleY = vehicle:getY()
    interiorData.vehicleZ = vehicle:getZ()
    -- Send command to the client to teleport the player to the vehicle interior
    sendServerCommandTo(player, "RVInterior", "serverEnterInterior",
            { interiorInstance = interiorInstance, isBoat = interiorParams.isBoat })
end

--- Delete surplus generators on the nominated tile location, possibly keeping one or even creating one.
---@param coordinates {x = number, y = number, z = number} The coordinates of the tile.
---@param wantGenerator boolean If true, a generator is found (or created if necessary) and returned.  If false, all
--- generators on the tile are deleted.
---@return boolean | IsoGenerator Returns false if the tile fails to load, true if tile loads and wantGenerator is
--- false, and a generator instance on the tile if the tile loads and wantGenerator is true.
local function findAndCleanGeneratorsAtCoords(coordinates, wantGenerator)
    local square = getSquare(coordinates.x, coordinates.y, coordinates.z)
    if not square then
        return false
    end
    local result = not wantGenerator
    local objects = square:getObjects()
    if objects then
        for index = objects:size() - 1, 0, -1 do
            local object = objects:get(index)
            if instanceof(object, "IsoGenerator") then
                if not result then
                    result = object
                else
                    square:transmitRemoveItemFromSquare(object)
                    object:remove()
                end
            end
        end
    end
    if wantGenerator then
        if not result then
            -- If no generator was found and wantGenerator is true, create one
            result = IsoGenerator.new(nil, square:getCell(), square)
        end
        -- Ensure the generator is connected, and reset its condition so it's always functional.
        result:setConnected(true)
        result:setCondition(100)
    end
    return result
end

local function getInteriorGenerator(vehicleName, interiorInstance)
    -- Clean up any generators in superseded locations.
    local deleteGeneratorCoords = RVInterior.getDeleteGeneratorCoordinates(vehicleName, interiorInstance)
    for _, coordinates in pairs(deleteGeneratorCoords) do
        if findAndCleanGeneratorsAtCoords(coordinates, false) == false then
            return nil
        end
    end
    -- Find or create an existing generator.  Also clean up from previous bug which created multiple generators
    local coordinates = RVInterior.getGeneratorCoordinates(vehicleName, interiorInstance)
    return findAndCleanGeneratorsAtCoords(coordinates, true)
end

--- Handle the updating of an interior's generator when a player enters
clientCommandHandlers.clientFinishEnterInterior = function(player)
    local interior = RVInterior.calculatePlayerInteriorInstance(player)
    if not interior then
        print("RVInterior ERROR: clientFinishEnterInterior for player ", player:getFullName(), " at coordinates ",
                player:getX(), ",", player:getY(), ", not inside an interior.")
        return
    end
    -- Because the generator tile isn't always immediately available, keep trying in onTick for a while.
    local retries = 20
    local updateGeneratorClosure
    updateGeneratorClosure = function()
        local generator = getInteriorGenerator(interior.vehicleName, interior.interiorInstance)
        if not generator then
            -- Generator tile is not yet loaded, try again next tick or give up.
            retries = retries - 1
            if retries <= 0 then
                print("RVInterior WARNING: clientFinishEnterInterior was unable to access the interior's generator, giving up.")
                Events.OnTick.Remove(updateGeneratorClosure)
            end
            return
        end
        updateInteriorGenerator(interior.vehicleName, interior.interiorInstance, generator)
        Events.OnTick.Remove(updateGeneratorClosure)
    end
    Events.OnTick.Add(updateGeneratorClosure)
end

---@param player IsoPlayer
clientCommandHandlers.clientStartExitInterior = function (player)
    local interior = RVInterior.calculatePlayerInteriorInstance(player)
    if not interior then
        print("RVInterior ERROR: player ", player:getFullName(), " at coordinates ", player:getX(), ",", player:getY(),
                " tried to exit an interior when not inside one?")
        return
    end
    -- Synchronise generator fuel with battery charge
    local interiorData
    local generator = getInteriorGenerator(interior.vehicleName, interior.interiorInstance)
    if generator then
        interiorData = updateInteriorGenerator(interior.vehicleName, interior.interiorInstance, generator)
    else
        interiorData = getInteriorModData(interior.vehicleName, interior.interiorInstance)
        if not interiorData then
            error("RVInterior ERROR: Unable to get generator when player leaving the interior, and no mod data for the interior found?")
        else
            -- This doesn't matter too much, as long as the values are synched eventually.
            print("RVInterior WARNING: Unable to get generator when player leaving the interior?")
        end
    end
    -- Send client command to move the player back to the vehicle
    sendServerCommandTo(player, "RVInterior", "serverLeaveInterior", {
        x = interiorData.vehicleX, y = interiorData.vehicleY, z = interiorData.vehicleZ,
        vehicleName = interior.vehicleName, interiorInstance = interior.interiorInstance,
        isBoat = RVInterior.getInteriorParameters(interior.vehicleName).isBoat
    })
end

clientCommandHandlers.clientFinishExitInterior = function(player, arguments)
    checkModData()
    local vehicle = getVehicleById(arguments.vehicleId)
    if vehicle == nil then
        print("RVInterior WARNING: player ", player:getFullName(), " tried to update battery of ",
                arguments.vehicleName, " with unknown vehicleId: ", arguments.vehicleId)
        return
    end
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
    local vehicleModData = RVInterior.getVehicleModData(vehicle, RVInterior.getInteriorParameters(vehicleName))
    local interiorInstance = vehicleModData.interiorInstance
    updateVehicleBattery(vehicleName, interiorInstance, vehicle)
end

clientCommandHandlers.updateVehiclePosition = function(_player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId)
    if not vehicle then
        -- This can happen if a player enters the interior very quickly after stopping the vehicle, so just print a
        -- warning.
        print("RVInterior WARNING: updateVehiclePosition client command for vehicle with unknown ID " ..
                tostring(arguments.vehicleId))
        return
    elseif not RVInterior.vehicleHasInteriorParameters(vehicle) then
        print("RVInterior WARNING: updateVehiclePosition client command for vehicle with unsupported type " ..
                vehicle:getScript():getFullName())
        return
    end
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    if not vehicleModData then
        -- It's not an error to drive around in a vehicle which is of a type which *can* have an interior, but which
        -- no-one has actually entered yet.
        return
    end
    local interiorInstance = vehicleModData.interiorInstance
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
    local interiorData = getInteriorModData(vehicleName, interiorInstance)
    if not interiorData then
        error("RVInterior ERROR: updateVehiclePosition client command for unknown " ..
                vehicleName .. " instance " .. tostring(interiorInstance))
    else
        interiorData.vehicleX = vehicle:getX()
        interiorData.vehicleY = vehicle:getY()
        interiorData.vehicleZ = vehicle:getZ()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Data Migration
------------------------------------------------------------------------------------------------------------------------

RVInterior.migrateSinglePlayer = function(vehicleName, interiorCount, playerData)
    checkModData(vehicleName)
    -- If the data has already been migrated, do nothing
    if getInteriorModData(vehicleName).interiorCount > 0 then
        return
    end
    getInteriorModData(vehicleName).interiorCount = interiorCount
    -- playerData is {true|false,{player:getX(),player:getY(),player:getZ()},housedelX,housedelY}
    if playerData and playerData[1] then
        local interiorInstance = 1 + playerData[3] + 5 * playerData[4]
        setInteriorModData(vehicleName, interiorInstance, {
            vehicleX = playerData[2][1],
            vehicleY = playerData[2][2],
            vehicleZ = playerData[2][3]
        })
    end
end

RVInterior.migrateMultiPlayer = function(vehicleName, interiorCount, interiorData)
    checkModData(vehicleName)
    -- If the data has already been migrated, do nothing
    if getInteriorModData(vehicleName).interiorCount > 0 then
        return
    end
    getInteriorModData(vehicleName).interiorCount = interiorCount
    for interiorInstance, data in pairs(interiorData) do
        setInteriorModData(vehicleName, interiorInstance, {
            vehicleX = data[1],
            vehicleY = data[2],
            vehicleZ = data[3]
        })
    end
end

------------------------------------------------------------------------------------------------------------------------
-- RVInterior Admin Commands
------------------------------------------------------------------------------------------------------------------------

adminClientCommandHandlers.clientGetAssignedNumber = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId)
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    if vehicleModData then
        sendServerCommandTo(player,"RVInteriorAdmin", "serverGetAssignedNumber",
                {vehicleModData.interiorInstance})
    else
        sendServerCommandTo(player,"RVInteriorAdmin", "serverGetAssignedNumber",{-1})
    end
end

---------------------------------------------------------------

adminClientCommandHandlers.clientPromptTeleport = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId);
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    local interiorInstance = 1;
    if vehicleModData then
        interiorInstance = vehicleModData.interiorInstance;
    end
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName());
    local options = {}
    for instance = 1, RVInterior.interiorSquare * RVInterior.interiorSquare do
        if getInteriorModData(vehicleName, instance) then
            table.insert(options, instance)
        end
    end
    sendServerCommandTo(player,'RVInteriorAdmin', 'serverPromptTeleport',
            {interiorInstance = interiorInstance, options = options, vehicleId = arguments.vehicleId});
end

adminClientCommandHandlers.clientAdminTeleport = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId);
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName());
    local interiorInstance = arguments.interiorInstance;
    local interiorData = getInteriorModData(vehicleName, interiorInstance);
    if interiorData and interiorData.vehicleX then
        sendServerCommandTo(player, "RVInterior", "serverLeaveInterior", {
            x = interiorData.vehicleX, y = interiorData.vehicleY, z = interiorData.vehicleZ,
            vehicleName = vehicleName, interiorInstance = interiorInstance,
            isBoat = RVInterior.getInteriorParameters(vehicleName).isBoat
        })
    end
end

---------------------------------------------------------------

adminClientCommandHandlers.clientPromptAssignedNumber = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId);
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    local interiorInstance = 1;
    if vehicleModData then
        interiorInstance = vehicleModData.interiorInstance;
    end
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName());
    local used = {}
    for instance = 1, RVInterior.interiorSquare * RVInterior.interiorSquare do
        if getInteriorModData(vehicleName, instance) then
            table.insert(used, instance)
        end
    end
    sendServerCommandTo(player,'RVInteriorAdmin', 'serverPromptAssignedNumber',
    {interiorInstance = interiorInstance, used = used, vehicleId = arguments.vehicleId});
end

adminClientCommandHandlers.clientSetAssignedNumber = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId);
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    if vehicleModData then
        vehicleModData.interiorInstance = arguments.interiorInstance;
    else
        vehicle:getModData().rvInterior = {interiorInstance = arguments.interiorInstance};
    end
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName());
    local interiorCount = ModData.get(modDataName).interiors[vehicleName].interiorCount;
    sendServerCommandTo(player,'RVInteriorAdmin', 'serverGetAssignedNumber',
            {arguments.interiorInstance, interiorCount});
end

---------------------------------------------------------------

adminClientCommandHandlers.clientResetVehicle = function(player, arguments)
    local vehicle = getVehicleById(arguments.vehicleId)
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    if vehicleModData and vehicle:getModData().rvInterior then
        local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName());
        local interiorInstance = vehicle:getModData().rvInterior.interiorInstance
        if getInteriorModData(vehicleName, interiorInstance) then
            getInteriorModData(vehicleName).interiorCount = getInteriorModData(vehicleName).interiorCount - 1
        end
        setInteriorModData(vehicleName, interiorInstance, nil)
        vehicle:getModData().rvInterior = nil
        sendServerCommandTo(player, "RVInteriorAdmin", "serverResetVehicle")
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Sync the battery and generator fuel on various events.
------------------------------------------------------------------------------------------------------------------------

--- Synchronise the battery charge and generator fuel if both the vehicle and its interior's generator are loaded.
local function synchBatteryAndGeneratorIfBothLoaded(vehicle)
    if not vehicle then
        return
    end
    if not RVInterior.vehicleHasInteriorParameters(vehicle) then
        -- Test in case the vehicle is towing an interior-capable trailer.
        vehicle = vehicle:getVehicleTowing()
        if not RVInterior.vehicleHasInteriorParameters(vehicle) then
            -- Nope.
            return
        end
    end
    local vehicleModData = RVInterior.getVehicleModData(vehicle)
    if not vehicleModData then
        return
    end
    local interiorInstance = vehicleModData.interiorInstance
    local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
    local generator = getInteriorGenerator(vehicleName, interiorInstance)
    if not generator then
        return
    end
    -- Ok, both the vehicle and the generator are in memory, so synch them.
    local interiorData = getInteriorModData(vehicleName, interiorInstance)
    if not interiorData then
        -- The vehicle has an interiorInstance assigned but there's no corresponding interior modData?  Perhaps an
        -- admin assigned the vehicle using the debug menu and no-one has entered yet?
        return
    end
    synchBatteryAndGenerator(interiorData, getBatteryCharge(vehicle), generator:getFuel())
    local battery = getConnectedBattery(vehicle)
    -- It's legal for a vehicle to have no battery.
    if battery ~= nil then
        battery:setUsedDelta(interiorData.batteryCharge)
    end
    generator:setFuel(interiorData.fuelLevel)
    generator:setActivated(interiorData.fuelLevel > 0)
    generator:setSurroundingElectricity()
    setInteriorModData(vehicleName, interiorInstance, interiorData)
end

--- Synch when the hood is opened (because if there is pending generator fuelUsage to apply to the battery, applying it
--- when we get the uninstallPart client command is too late to update the battery's charge.)
clientVehicleCommandHandlers.setDoorOpen = function(_player, arguments)
    -- arguments = { vehicle = vehicleId, part = partId, open = boolean }
    if arguments.part == "EngineDoor" and arguments.open then
        -- Synch when the vehicle hood has been opened
        synchBatteryAndGeneratorIfBothLoaded(getVehicleById(arguments.vehicle))
    end
end

--- Synch when a battery is removed
clientVehicleCommandHandlers.uninstallPart = function(_player, arguments)
    -- arguments = { vehicle = vehicleId, part = partId, perks = perksTable, mechanicSkill = playerSkillLevel,
    --               contentAmount = part:getContainerContentAmount() }
    if arguments.part == "Battery" then
        synchBatteryAndGeneratorIfBothLoaded(getVehicleById(arguments.vehicle))
    end
end

--- Synch when a battery is installed
clientVehicleCommandHandlers.installPart = function(_player, arguments)
    -- arguments = { vehicle = vehicleId, part = partId, perks = perksTable, mechanicSkill = playerSkillLevel,
    --               item = itemBeingInstalled }
    if arguments.part == "Battery" then
        synchBatteryAndGeneratorIfBothLoaded(getVehicleById(arguments.vehicle))
    end
end

--- Synch when a trailer is attached.
clientVehicleCommandHandlers.attachTrailer = function(_player, arguments)
    -- arguments = { vehicleA = vehicleId (towing), vehicleB = vehicleId (trailer/towed), attachmentA = string,
    --  attachmentB = string }
    synchBatteryAndGeneratorIfBothLoaded(getVehicleById(arguments.vehicleB))
end

-- list of attachment names to iterate through in pairs.
local attachments = { "trailer", "trailer", "trailerfront", "trailerfront", "trailer" }

--- Duplicate of ISVehicleTrailerUtils.getTowableVehicleNear, because it's not available on the server :(
local function getTowableVehicleNear(square, ignoreVehicle, attachmentA, attachmentB)
    for y=square:getY() - 6,square:getY()+6 do
        for x=square:getX()-6,square:getX()+6 do
            local searchSquare = getCell():getGridSquare(x, y, square:getZ())
            if searchSquare then
                for index=0, searchSquare:getMovingObjects():size() - 1 do
                    local obj = searchSquare:getMovingObjects():get(index)
                    if instanceof(obj, "BaseVehicle") and obj ~= ignoreVehicle and ignoreVehicle:canAttachTrailer(obj, attachmentA, attachmentB) then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

--- Synch when a trailer is detached.
clientVehicleCommandHandlers.detachTrailer = function(_player, arguments)
    -- arguments = { vehicle = vehicleId (towing) }
    local vehicle = getVehicleById(arguments.vehicle)
    local trailer = vehicle:getVehicleTowing()
    -- Depending on which OnClientCommand function runs first (this one or the vanilla game one), the trailer may
    -- already be detached by the time this function runs.  If vehicle:getVehicleTowing() returns nil, use the same
    -- logic the game does to find a trailer you can attach to the current vehicle, on the assumption that the
    -- just-detached trailer will be in a legal position to re-attach.
    local attachmentIndex = 1
    while not trailer and attachmentIndex < #attachments do
        trailer = getTowableVehicleNear(vehicle:getSquare(), vehicle,
                attachments[attachmentIndex], attachments[attachmentIndex + 1])
        attachmentIndex = attachmentIndex + 1
    end
    if trailer then
        synchBatteryAndGeneratorIfBothLoaded(trailer)
    end
end

-- Sync every game hour
local function syncOnTheHour()
    checkModData()
    -- We don't want to sync a potentially large number of vehicles in a single function call, so check one vehicle at
    -- a time in an OnTick closure, with a delay.
    local vehicleIndex = 0
    local delay = 0
    local hourlyClosure
    hourlyClosure = function()
        if delay > 0 then
            delay = delay - 1
            return
        end
        delay = 10
        local allVehicles = getCell():getVehicles()
        if vehicleIndex >= allVehicles:size() then
            -- We've checked all currently in-memory vehicles, so we're done.
            Events.OnTick.Remove(hourlyClosure)
        else
            synchBatteryAndGeneratorIfBothLoaded(allVehicles:get(vehicleIndex))
            vehicleIndex = vehicleIndex + 1
        end
    end
    Events.OnTick.Add(hourlyClosure)
end

Events.EveryHours.Add(syncOnTheHour)