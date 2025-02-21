local vehicleName = "Base.TrailerHomeHartman"

RVInterior.addInterior(vehicleName, { 22801, 12904, 0 }, {0, 11, 0})

local function migrateTrailerHomeExplorer()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().TrailerHomeHartmannum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().TrailerHomeHartmannum,
                    player:getModData().TrailerHomeHartmanpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverTrailerHomeHartmannum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverTrailerHomeHartmannum,
                    getGameTime():getModData().serverTrailerHomeHartman, getGameTime():getModData().serverTrailerHomeHartmanplayerpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverTrailerHomeHartmannum")
        end
    end
end

Events.OnGameStart.Add(migrateTrailerHomeExplorer)
Events.OnServerStarted.Add(migrateTrailerHomeExplorer)