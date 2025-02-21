local vehicleName = "Base.86econolinerv"

RVInterior.addInterior(vehicleName, { 22801, 12306, 0 })

local function migrateEconolineRV()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().econolinervnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().econolinervnum,
                    player:getModData().econolinervpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().servereconolinenum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().servereconolinenum,
                    getGameTime():getModData().servereconoline)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "servereconolinenum")
        end
    end
end

Events.OnGameStart.Add(migrateEconolineRV)
Events.OnServerStarted.Add(migrateEconolineRV)