--- all credits to original author and his credits and the ones mentioned in comments
--- trying to port RV Interior mod to B42 Project Zomboid
--- a lot of inspiration from Doomsday MH and Flip Vehicles authors
--- 
--- for simplicity, trying only to enter from inside vehicle first
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--- singleplayer only
if isServer() then return end


--- threshold for "stationary"
local stationaryThreshold = 0.2

--- radial menu like flip vehicle did
local rv_showRadialMenu = ISVehicleMenu.showRadialMenu

local RVModData
local id = nil
local seat

--- map positions, would mean 12 different interiors in total (maps from Doomsday Motor Home)
--- would be identical interiors but the mapping tool is not working on my end to create new ones 
local interior_mappos = {}
interior_mappos[1] = {20100,300}
interior_mappos[2] = {20150,300}
interior_mappos[3] = {20200,300}
interior_mappos[4] = {20250,300}
interior_mappos[5] = {20300,300}
interior_mappos[6] = {20350,300}
interior_mappos[7] = {20100,400}
interior_mappos[8] = {20150,400}
interior_mappos[9] = {20200,400}
interior_mappos[10] = {20250,400}
interior_mappos[11] = {20300,400}
interior_mappos[12] = {20350,400}

local allowed_vehicles = {
    "Base.Van",
    "Base.StepVan",
    "Base.VanAmbulance"
}


--- Loads the textures, thought about using local var instead of a function
local function loadRVInteriorTextures()
    getTexture("media/textures/rvInteriorEnter.png")       -- Radial Menu UI - enter (normal)
    getTexture("media/textures/rvInteriorEnterGrey.png")   -- Radial Menu UI - enter (disabled)
end
Events.OnGameBoot.Add(loadRVInteriorTextures)

--- moves player to interior
local function moveToInterior(player, pos)
    player:setX(20101)
    player:setY(307)
    player:setZ(0)

    player:setLastX(pos[1]+1)
    player:setLastY(pos[2]+7)
    player:setLastZ(0)
end

--- modified from Doomsday MH, but for now this sets fuel and condition to 99999, want it to sync with battery later
local function syncHourly()
    for i,v in pairs(interior_mappos) do
        local square=getCell():getGridSquare(interior_mappos[i][1]+1,interior_mappos[i][2],2)
        if square then
            local objects=square:getObjects()
            if objects then
                local hasGenerator = false
                for k=1,objects:size() do
                    if instanceof(objects:get(k-1), "IsoGenerator") then
                        objects:get(k-1):setFuel(99999)
                        objects:get(k-1):setCondition(99999)
                        hasGenerator = true
                    end
                end
                if not hasGenerator then
                    local genItem = instanceItem("Base.Generator")

                    local NewGenerator = IsoGenerator.new(genItem,getCell(),square)
                    NewGenerator:setConnected(true)
                    NewGenerator:setFuel(99999)
                    NewGenerator:setCondition(99999)
                    NewGenerator:setActivated(true)
                    NewGenerator:setSurroundingElectricity()
                end
            end
        end
    end
end

Events.EveryHours.Add(syncHourly)



--- check if player cant enter interior, returns the UI Text if player can't enter, nil otherwise
local function checkIfPlayerCantEnter(vehicle, player)
    --- if sandbox setting NotWhenChased is on, zombies are chasing and the vehicle is not moving, can not enter
    if SandboxVars.RVInterior.NotWhenChased and player:getStats():getNumChasingZombies() > 0 then
        return getText("UI_zombiesChasing")
    end
    --- if nearest zombie is closer than safe distance from sandbox settings, can not enter
    local zombie = getCell():getNearestVisibleZombie(player:getPlayerNum())
    if SandboxVars.RVInterior.SafeZombieDistance > 0 and zombie and
            zombie:getSquare():getMovingObjects():indexOf(zombie) >= 0 then -- to ignore deleted zombies
        local distance = IsoUtils.DistanceToSquared(zombie:getX(), zombie:getY(), zombie:getZ(),
                player:getX(), player:getY(), player:getZ())
        if distance < SandboxVars.RVInterior.SafeZombieDistance * SandboxVars.RVInterior.SafeZombieDistance then
            return getText("UI_zombiesNearby")
        end
    end

    --- if vehicle is moving, can not enter
    if math.abs(vehicle:getCurrentSpeedKmHour()) >= stationaryThreshold then
        return getText("UI_vehicleMoving")
    end

    --- if none of the above, then player can safely enter 
    --- no zombies chasing, no zombies nearby, no trespassing (MP), vehicle not moving
    return nil
end


--- entering interior, update event
local function leaveInterior(player)
    local square = player:getCurrentSquare()
    if square == nil then return end

    for i = -1, 1 do
        for j = -1, 1 do
            local square_p = getCell():getGridSquare(player:getX() + i, player:getY() + j, player:getZ())
            if square_p then
                local vehicle = square_p:getVehicleContainer()
                if vehicle ~= nil then
                    vehicle:enter(seat, player)
                    triggerEvent("OnEnterVehicle", player)
                    Events.OnPlayerUpdate.Remove(leaveInterior)
                end
            end
        end
    end
end


--- exiting interior, update event
local function onPlayerSelectExit(player)
    local position = RVModData.RVInterior.interior_outsidepos[1]
    if position == nil then
        player:setX(10614)
        player:setY(9299)
        player:setZ(0)
        player:setLastX(10614)
        player:setLastY(9299)
        player:setLastZ(0)
        Events.OnPlayerUpdate.Add(leaveInterior)
    else
        player:setX(position[1])
        player:setY(position[2])
        player:setZ(position[3])
        player:setLastX(position[1])
        player:setLastY(position[2])
        player:setLastZ(position[3])
        Events.OnPlayerUpdate.Add(leaveInterior)
    end
end


--- enter interior and create/load mod data
local function enterInterior(player)
    local vehicle = player:getVehicle()
    if not vehicle then return end

    if RVModData == nil then RVModData = getGameTime():getModData() end

    if RVModData.RVInterior == nil then
        RVModData.RVInterior = {}
        RVModData.RVInterior.interior_index = 1
        RVModData.RVInterior.vehicles = allowed_vehicles
        RVModData.RVInterior.interior_maps = interior_mappos
        RVModData.RVInterior.interior_outsidepos = {}
    end

    --- check if interior already exists
    -- local vehicle_rv = vehicle:getModData()
    -- if vehicle_rv.RVInterior_index == nil then
    --     vehicle_rv.RVInterior_index = RVModData.RVInterior.interior_index
    -- end
    -- local cantEnter = checkIfPlayerCantEnter(vehicle, player)
    -- if cantEnter then
    --     player:Say(getText("UI_cantEnter"))
    --     player:Say(cantEnter)
    -- else
    --- save coordinates and move player to interior
    RVModData.RVInterior.interior_outsidepos[1] = {player:getX(), player:getY(), player:getZ()}
    seat = vehicle:getSeat(player)
    vehicle:exit(player)
    moveToInterior(player, interior_mappos[1])
    -- end
end


--- add exit option for rightclick menu
local function addExitOption(player, context)
    local playerObj = getSpecificPlayer(player)
    local square = ISWorldObjectContextMenu.fetchVars.clickedSquare
    if playerObj then
        local x = square:getX()
        local y = square:getY()
        local z = square:getZ()
        if z ~= 0 then return end
        for i, s in pairs(interior_mappos) do
            if i ~= -9 then
                if x <= s[1]+5 and x >= s[1] and y >= s[2] and y<= s[2]+ 10 then
                    context:addOption(getText("UI_exitrvinterior"), playerObj, onPlayerSelectExit, playerObj, id)
                end
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(addExitOption)


--- radial menu
function ISVehicleMenu.showRadialMenu(player, ...)
    rv_showRadialMenu(player, ...)
    local vehicle = player:getVehicle()
    if vehicle then
        local vehicleName = vehicle:getScript():getFullName()
        local allowed = false
        for _, v in pairs(allowed_vehicles) do
            if v == vehicleName then
                allowed = true
                break
            end
        end
        if player:isSeatedInVehicle() and allowed then
            local menu = getPlayerRadialMenu(player:getPlayerNum())
            menu:addSlice(getText("UI_enterrvinterior"), getTexture("media/textures/rvInteriorEnter.png"), enterInterior, player)
        end
    end
end
