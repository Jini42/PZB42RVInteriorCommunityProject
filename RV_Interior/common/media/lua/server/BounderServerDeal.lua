--local vehicleName = "Base.86bounder"
local vehicleName = "Base.fr_fl_bounder_86"


--RVInterior.addInterior(vehicleName, { 10000, 10000, 0 })
RVInterior.addInterior(vehicleName, { 22501, 12306, 0 })

local function migrate86bounder()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().boundernum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().boundernum,
                    player:getModData().bounderpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverboundernum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverboundernum,
                    getGameTime():getModData().serverbounder)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverboundernum")
        end
    end
end

Events.OnGameStart.Add(migrate86bounder)
Events.OnServerStarted.Add(migrate86bounder)