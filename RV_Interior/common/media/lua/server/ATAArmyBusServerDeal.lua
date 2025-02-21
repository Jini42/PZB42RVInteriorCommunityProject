local vehicleName = "Base.ATAArmyBus"

RVInterior.addInterior(vehicleName, { 23101, 12006, 0 })

local function migrateATAArmyBus()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().ATAArmyBusnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().ATAArmyBusnum,
                    player:getModData().ATAArmyBuspos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverATAArmyBusnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverATAArmyBusnum,
                    getGameTime():getModData().serverATAArmyBus)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverATAArmyBusnum")
        end
    end
end

Events.OnGameStart.Add(migrateATAArmyBus)
Events.OnServerStarted.Add(migrateATAArmyBus)