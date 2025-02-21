local vehicleName = "Base.ATASchoolBus"

RVInterior.addInterior(vehicleName, { 22501, 12606, 0 })

local function migrateATASchoolBus()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().ATASchoolBusnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().ATASchoolBusnum,
                    player:getModData().ATASchoolBuspos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverATASchoolBusnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverATASchoolBusnum,
                    getGameTime():getModData().serverATASchoolBus)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverATASchoolBusnum")
        end
    end
end

Events.OnGameStart.Add(migrateATASchoolBus)
Events.OnServerStarted.Add(migrateATASchoolBus)