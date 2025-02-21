local vehicleName = "Base.Trailercamperscamp"

RVInterior.addInterior(vehicleName, { 22501, 12004, 0 }, {-1, 11, 0})

local function migrateTrailerCampersCamp()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().trailercampernum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().trailercampernum,
                    player:getModData().trailercamperpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().servertrailercampernum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().servertrailercampernum,
                    getGameTime():getModData().servertrailercamper)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "servertrailercampernum")
        end
    end
end

Events.OnGameStart.Add(migrateTrailerCampersCamp)
Events.OnServerStarted.Add(migrateTrailerCampersCamp)