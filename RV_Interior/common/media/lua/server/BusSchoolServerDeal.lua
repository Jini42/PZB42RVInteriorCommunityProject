local vehicleName = "Base.schoolbus"

RVInterior.addInterior(vehicleName, { 22801, 12010, 0 })
-- We've changed the generator offset - clean up anything at the old location
RVInterior.addVehicleDeleteGeneratorOffset(vehicleName, {0, 5, 0})
local sharedVehicles = {
    "Base.prisonbus_jefferson",
    "Base.prisonbus_meade",
    "Base.87rtsbus",
    "Base.87fordB700military",
    "Base.87fordB700prison",
    "Base.87fordB700school"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end

local function migrateSchoolbus()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().schoolbusnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().schoolbusnum,
                    player:getModData().schoolbuspos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverschoolbusnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverschoolbusnum,
                    getGameTime():getModData().serverschoolbus)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverschoolbusnum")
        end
    end
end

Events.OnGameStart.Add(migrateSchoolbus)
Events.OnServerStarted.Add(migrateSchoolbus)