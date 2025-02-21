local vehicleName = "Base.BoatSailingYacht"

RVInterior.addInterior(vehicleName, { 22502, 13208, 0 }, {-1, 7, 0})
RVInterior.setInteriorIsBoat(vehicleName)
-- There was a discrepancy between the SP and MP offsets of the generator.  Delete generator(s) in the closer location.
RVInterior.addVehicleDeleteGeneratorOffset(vehicleName, {-1, 4, 0})
-- Make the grounded version of the yacht share the same interiors as the normal version.
local sharedVehicles = {
    "Base.BoatSailingYacht_Ground"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end

local function migrateBoatSailingYacht()
    if getWorld():getGameMode() ~= "Multiplayer" then
        if getGameTime():getModData().BoatSailingYachtnum then
            -- Migrate old single player data
            local player = getPlayer()
            RVInterior.migrateSinglePlayer(vehicleName, getGameTime():getModData().BoatSailingYachtnum,
                    player:getModData().BoatSailingYachtpos)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "carishousenum")
        end
    elseif isServer() then
        if getGameTime():getModData().serverBoatSailingYachtnum then
            -- Migrate old multiplayer data
            RVInterior.migrateMultiPlayer(vehicleName, getGameTime():getModData().serverBoatSailingYachtnum,
                    getGameTime():getModData().serverBoatSailingYacht)
            RVInterior.addVehicleInteriorInstanceAlias(vehicleName, "serverBoatSailingYachtnum")
        end
    end
end

Events.OnGameStart.Add(migrateBoatSailingYacht)
Events.OnServerStarted.Add(migrateBoatSailingYacht)