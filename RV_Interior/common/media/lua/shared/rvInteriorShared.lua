if RVInterior == nil then
    RVInterior = {
        interior = {},
        interiorStride = 60,
        interiorSquare = 5
    }
end

--- Associate a set of 25 interior maps with the given vehicle baseName.  The interior maps should be arranged in a 5x5
--- grid, repeating every 60 tiles.
---@param vehicleName string The vehicle name, as returned by vehicle:getScript():getFullName.
---@param entryPoint table The `{x, y, z}` coordinates where the player should appear in the first vehicle instance
--- (the north-westernmost one of the 5x5 grid of vehicle interior maps for this vehicle type.)
---@param generatorOffset table (Optional) If set, defines the `{x, y, z}` offset from the entry point where the
--- interior's hidden generator should be placed.  If omitted, defaults to `{0, 9, 0}`
RVInterior.addInterior = function(vehicleName, entryPoint, generatorOffset)
    -- Check that we're not overlapping an existing interior
    local margin = RVInterior.interiorStride / 3
    local max = (RVInterior.interiorSquare - 1) * RVInterior.interiorStride + margin
    for otherVehicleName, params in pairs(RVInterior.interior) do
        if params.entryPoint and
                entryPoint[1] + max > params.entryPoint[1] - margin and
                entryPoint[1] - margin < params.entryPoint[1] + max and
                entryPoint[2] + max > params.entryPoint[2] - margin and
                entryPoint[2] - margin < params.entryPoint[2] + max then
            error("RVInterior ERROR: new region for " .. vehicleName .. " overlaps with existing maps for " .. otherVehicleName)
        end
    end
    RVInterior.interior[vehicleName] = {
        entryPoint = entryPoint,
        generatorOffset = generatorOffset or {0, 9, 0}
    }
end

--- Flag certain vehicles/interiors as being boats, so the mod can take additional steps when transitioning from the
--- vehicle to the interior map and vice versa (otherwise, the player spends a moment in the water and gets soaked)
RVInterior.setInteriorIsBoat = function(vehicleName)
    if not RVInterior.interior[vehicleName] or not RVInterior.interior[vehicleName].entryPoint then
        error("RVInterior ERROR: addInterior(\"" .. vehicleName .. "\") must be called before calling setInteriorIsBoat function.")
    end
    RVInterior.interior[vehicleName].isBoat = true
end

--- Register an additional vehicle type that shares the interiors with a previously-added interior.
RVInterior.shareInterior = function(vehicleName, sharedInteriorVehicleName)
    if not RVInterior.interior[sharedInteriorVehicleName] then
        error("RVInterior ERROR: Shared interior " .. sharedInteriorVehicleName .. " must be defined before calling shareInterior function.")
    end
    RVInterior.interior[vehicleName] = {
        sharedInterior = sharedInteriorVehicleName
    }
end

--- Add an alternative field name for looking up a vehicle's interiorInstance
RVInterior.addVehicleInteriorInstanceAlias = function(vehicleName, fieldName)
    if not RVInterior.interior[vehicleName] then
        error("RVInterior ERROR: interior for " .. vehicleName .. " must be added before calling addInteriorAlias function.")
    end
    if RVInterior.interior[vehicleName].interiorInstanceAlias then
        table.insert(RVInterior.interior[vehicleName].interiorInstanceAlias, fieldName)
    else
        RVInterior.interior[vehicleName].interiorInstanceAlias = { fieldName }
    end
end

--- Set a generator offset whose only purpose is to specify a location to remove old generator instances
RVInterior.addVehicleDeleteGeneratorOffset = function(vehicleName, deleteGeneratorOffset)
    if not RVInterior.interior[vehicleName] or not RVInterior.interior[vehicleName].entryPoint then
        error("RVInterior ERROR: addInterior(\"" .. vehicleName .. "\") must be called before calling addVehicleDeleteGeneratorOffset function.")
    end
    if not RVInterior.interior[vehicleName].deleteGeneratorOffset then
        RVInterior.interior[vehicleName].deleteGeneratorOffsets = { deleteGeneratorOffset }
    else
        table.insert(RVInterior.interior[vehicleName].deleteGeneratorOffsets, deleteGeneratorOffset)
    end
end

--- Get the canonical vehicle name, to handle vehicles which share an existing set of interior maps.
RVInterior.getVehicleName = function(vehicleName, nilOnUnknown)
    while RVInterior.interior[vehicleName] and RVInterior.interior[vehicleName].sharedInterior do
        vehicleName = RVInterior.interior[vehicleName].sharedInterior
    end
    if not RVInterior.interior[vehicleName] then
        if nilOnUnknown then
            return nil
        else
            error("RVInterior ERROR: unknown vehicle type: " .. vehicleName)
        end
    end
    return vehicleName
end

RVInterior.hasInteriorParameters = function(vehicleName)
    return (RVInterior.interior[vehicleName] ~= nil)
end

RVInterior.vehicleHasInteriorParameters = function(vehicle)
    return (vehicle and RVInterior.interior[vehicle:getScript():getFullName()] ~= nil)
end

RVInterior.getInteriorParameters = function(vehicleName)
    return RVInterior.interior[RVInterior.getVehicleName(vehicleName)]
end

RVInterior.getInteriorCoordinates = function(vehicleName, interiorInstance)
    local interiorParams = RVInterior.getInteriorParameters(vehicleName)
    local interiorX = (interiorInstance - 1) % RVInterior.interiorSquare;
    local interiorY = math.floor((interiorInstance - 1) / RVInterior.interiorSquare);
    local x = interiorParams.entryPoint[1] + RVInterior.interiorStride * interiorX
    local y = interiorParams.entryPoint[2] + RVInterior.interiorStride * interiorY
    local z = interiorParams.entryPoint[3]
    return { x = x, y = y, z = z }
end

RVInterior.getGeneratorCoordinates = function(vehicleName, interiorInstance)
    local entryPoint = RVInterior.getInteriorCoordinates(vehicleName, interiorInstance)
    local interiorParams = RVInterior.getInteriorParameters(vehicleName)
    return {
        x = entryPoint.x + interiorParams.generatorOffset[1],
        y = entryPoint.y + interiorParams.generatorOffset[2],
        z = entryPoint.z + interiorParams.generatorOffset[3]
    }
end

RVInterior.getDeleteGeneratorCoordinates = function(vehicleName, interiorInstance)
    local interiorParams = RVInterior.getInteriorParameters(vehicleName)
    local result = {}
    if interiorParams.deleteGeneratorOffsets then
        local entryPoint = RVInterior.getInteriorCoordinates(vehicleName, interiorInstance)
        for index, offset in pairs(interiorParams.deleteGeneratorOffsets) do
            result[index] = {
                x = entryPoint.x + offset[1],
                y = entryPoint.y + offset[2],
                z = entryPoint.z + offset[3]
            }
        end
    end
    return result
end

-- Iterate over all added interiors and return the vehicleName of the map region the player's X & Y coords are inside.
RVInterior.playerInsideInterior = function(player)
    local x = player:getX()
    local y = player:getY()
    local margin = RVInterior.interiorStride / 3
    local max = (RVInterior.interiorSquare - 1) * RVInterior.interiorStride + margin
    for vehicleName, params in pairs(RVInterior.interior) do
        if params.entryPoint and
                x > params.entryPoint[1] - margin and x < params.entryPoint[1] + max and
                y > params.entryPoint[2] - margin and y < params.entryPoint[2] + max then
            return vehicleName
        end
    end
    return nil
end

--- Calculate a player's interiorInstance and vehicleName (if not provided) based on their coordinates.
RVInterior.calculatePlayerInteriorInstance = function(player, vehicleName)
    if not vehicleName then
        vehicleName = RVInterior.playerInsideInterior(player)
        if not vehicleName then
            return nil
        end
    else
        vehicleName = RVInterior.getVehicleName(vehicleName)
    end
    local interiorParams = RVInterior.getInteriorParameters(vehicleName)
    local instanceX = math.floor(0.5 + (player:getX() - interiorParams.entryPoint[1]) / RVInterior.interiorStride)
    local instanceY = math.floor(0.5 + (player:getY() - interiorParams.entryPoint[2]) / RVInterior.interiorStride)
    if instanceX < 0 or instanceX >= RVInterior.interiorSquare or
            instanceY < 0 or instanceY >= RVInterior.interiorSquare then
        return nil
    end
    local interiorInstance = 1 + instanceX + instanceY * RVInterior.interiorSquare
    return { vehicleName = vehicleName, interiorInstance = interiorInstance }
end

--- Get the rvInterior modData associated with a vehicle, potentially migrating legacy modData.  Turns out vehicle
--- modData is available on both the client and server in MP.
RVInterior.getVehicleModData = function(vehicle, interiorParams)
    if not interiorParams then
        local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
        interiorParams = RVInterior.getInteriorParameters(vehicleName)
    end
    local result = vehicle:getModData().rvInterior
    if not result and interiorParams.interiorInstanceAlias then
        for _, alias in pairs(interiorParams.interiorInstanceAlias) do
            if vehicle:getModData()[alias] then
                vehicle:getModData().rvInterior = {
                    interiorInstance = vehicle:getModData()[alias]
                }
                return vehicle:getModData().rvInterior
            end
        end
    end
    return result
end

--- Test if a player would be considered to be trespassing in a vehicle interior, based on whether they're in a
--- multiplayer game or not and whether someone has created a safehouse in the interior.
RVInterior.isPlayerTrespassingInInterior = function(vehicle, player)
    if getWorld():getGameMode() == "Multiplayer" and not player:isAccessLevel("admin") then
        local vehicleName = RVInterior.getVehicleName(vehicle:getScript():getFullName())
        local vehicleModData = RVInterior.getVehicleModData(vehicle, RVInterior.getInteriorParameters(vehicleName))
        if vehicleModData then
            local interiorInstance = vehicleModData.interiorInstance
            local coords = RVInterior.getInteriorCoordinates(vehicleName, interiorInstance)
            local square = getCell():getOrCreateGridSquare(coords.x, coords.y, coords.z)
            if SafeHouse.isSafeHouse(square, player:getUsername(), true) then
                -- The interior is a non-friendly safehouse.
                return true
            end
        end
    end
    return false
end

--- Flag certain vehicle as being able to be entered from the back.
--- Add new vehicles by adding "RVInterior.canEnterFromBack(vehicleName,true)" in their ServerDeal file
--- A restart is necessary to apply changes
RVInterior.canEnterFromBackList = {}
RVInterior.canEnterFromBack = function(vehicleName, canEnter)
    if not vehicleName then return end
    if not canEnter then
        canEnter = false
    end
    RVInterior.canEnterFromBackList[vehicleName] = canEnter
end