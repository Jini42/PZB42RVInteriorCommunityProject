local vehicleName = "Base.ATAPrisonBus"

RVInterior.addInterior(vehicleName, { 22801, 12606, 0 })

local function migrateATAPrisonBus()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().ATAPrisonBusnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().ATAPrisonBusnum,
                    player:getModData().ATAPrisonBuspos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverATAPrisonBusnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverATAPrisonBusnum,
                    getGameTime():getModData().serverATAPrisonBus)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverATAPrisonBusnum")
        end
    end
end

Events.OnGameStart.Add(migrateATAPrisonBus)
Events.OnServerStarted.Add(migrateATAPrisonBus)