local vehicleName = "Base.TrailerHome"

RVInterior.addInterior(vehicleName, { 23101, 12604, 0 }, {0, 11, 0})

local function migrateTrailerHome()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().TrailerHomenum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().TrailerHomenum,
                    player:getModData().TrailerHomepos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverTrailerHomenum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverTrailerHomenum,
                    getGameTime():getModData().serverTrailerHome, getGameTime():getModData().serverTrailerHomeplayerpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverTrailerHomenum")
        end
    end
end

Events.OnGameStart.Add(migrateTrailerHome)
Events.OnServerStarted.Add(migrateTrailerHome)