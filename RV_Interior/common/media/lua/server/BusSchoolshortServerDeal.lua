local vehicleName = "Base.schoolbusshort"

RVInterior.addInterior(vehicleName, { 23101, 12306, 0 })

local sharedVehicles = {
    "Base.87rtsbusshort",
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end

local function migrateSchoolbusShort()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().schoolbusshortnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().schoolbusshortnum,
                    player:getModData().schoolbusshortpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverschoolbusshortnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverschoolbusshortnum,
                    getGameTime():getModData().serverschoolbusshort)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverschoolbusshortnum")
        end
    end
end

Events.OnGameStart.Add(migrateSchoolbusShort)
Events.OnServerStarted.Add(migrateSchoolbusShort)