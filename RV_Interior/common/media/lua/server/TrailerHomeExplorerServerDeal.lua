local vehicleName = "Base.TrailerHomeExplorer"

RVInterior.addInterior(vehicleName, { 22501, 12904, 0 }, {0, 11, 0})

local function migrateTrailerHomeExplorer()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().trailerHomeExplorernum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().trailerHomeExplorernum,
                    player:getModData().trailerHomeExplorerpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverTrailerHomeExplorernum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverTrailerHomeExplorernum,
                    getGameTime():getModData().serverTrailerHomeExplorer, getGameTime():getModData().serverTrailerHomeExplorerplayerpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverTrailerHomeExplorernum")
        end
    end
end

Events.OnGameStart.Add(migrateTrailerHomeExplorer)
Events.OnServerStarted.Add(migrateTrailerHomeExplorer)