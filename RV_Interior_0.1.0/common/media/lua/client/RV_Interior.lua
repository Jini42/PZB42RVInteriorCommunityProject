-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- https://steamcommunity.com/workshop/filedetails/discussion/2822286426/592888629473342040/?tscn=1740219172 ---
--- credits to original author and his credits and the ones mentioned below                                   ---
--- Community Project, trying to update RV Interior for build 42                                              ---
--- a lot of inspiration and material from Doomsday MH author, especially maps for interiors                  ---
--- referenced Flip Vehicles for radial menu                                                                  ---
---                                                                                                           ---
--- 23. Feb 2025, version 0.1.0                                                                               ---
--- author: Ry                                                                                                ---
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------





-----------------------------------------------------------------------------------------------------------------
--- Game Boot and Game Start ------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--- singleplayer only
if isServer() then return end

--- threshold for "stationary"
local stationaryThreshold = 0.2

--- radial menu like flip vehicle did
local rv_showRadialMenu = ISVehicleMenu.showRadialMenu

--- mod data
local RVModData

--- map positions, would mean 12 different interiors in total (maps from Doomsday Motor Home)
--- would be identical interiors but the mapping tool is not working on my end to create new ones 
--- TODO: add more maps if possible
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


--- vehicles that can have an interior
--- if sandbox option is enabled, use specified vehicles for allowed_vehicles
--- else use the default ones
local allowed_vehicles = {}
local function setVehiclesWithInteriors()
    if SandboxVars.RVInterior.Vehicles then
        for i = 1, 12 do
            local vehicle = SandboxVars.RVInterior["vehicle" .. i]
            if vehicle and vehicle ~= "" then
                table.insert(allowed_vehicles, vehicle)
            end
        end
    else
        allowed_vehicles = {
            "Base.Van",
            "Base.StepVan",
            "Base.VanAmbulance"
        }
    end
end
Events.OnGameStart.Add(setVehiclesWithInteriors)


--- Loads the textures
local function loadRVInteriorTextures()
    getTexture("media/textures/rvInteriorEnter.png")       -- Radial Menu UI - enter (normal)
    getTexture("media/textures/rvInteriorEnterGrey.png")   -- Radial Menu UI - enter (disabled)
end
Events.OnGameBoot.Add(loadRVInteriorTextures)

--- Initialise mod data or create new if it doesnt exist
local function initModData()
    local modData = getGameTime():getModData()
    if modData.RVInterior == nil then
        modData.RVInterior = {}
        modData.RVInterior.interior_index = 1
        modData.RVInterior.interior_index_current = nil
        modData.RVInterior.interior_vehicles = {}
        modData.RVInterior.seat_index = nil
        modData.RVInterior.vehicles = allowed_vehicles
        modData.RVInterior.interior_maps = interior_mappos
        modData.RVInterior.interior_outsidepos = {}
    end
    RVModData = modData
end
Events.OnGameStart.Add(initModData)



-----------------------------------------------------------------------------------------------------------------
--- Interior Data -----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- put index with vehicle name in a list for a maximum of 12 different interiors
--- but same name vehicles would share same interior instance
--- dynamically assigns index, so might differ between savegames
--- savegame1: Enter interior in Van, StepVan, VanAmbulance --> Van: Interior 1, StepVan: Interior 2, VanAmbulance: Interior 3
--- savegame2: Enter interior in VanAmbulance, Van, StepVan --> Van: Interior 2, StepVan: Interior 3, VanAmbulance: Interior 1
local function assignInteriorIndex(vehicle)
    if not RVModData then initModData() end
    if not vehicle then return end
    local vehicleName = vehicle:getScript():getFullName()
    for index, name in pairs(RVModData.RVInterior.interior_vehicles) do
        if name == vehicleName then
            return index
        end
    end
    if RVModData.RVInterior.interior_index > 12 then return end
    local index = RVModData.RVInterior.interior_index
    RVModData.RVInterior.interior_vehicles[index] = vehicleName
    RVModData.RVInterior.interior_index = index + 1
    return index
end



-----------------------------------------------------------------------------------------------------------------
--- Generator and Battery ---------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- TODO: add functions to sync interior generator with car battery, also plumbing sink
--- TODO: ...

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



-----------------------------------------------------------------------------------------------------------------
--- Enter Interior ----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- TODO: add function to enter from the back
--- TODO: for MP, check if trespassing
--- TODO: ...


--- check if player cant enter interior, returns the UI Text if player can't enter, nil otherwise
local function checkIfPlayerCantEnter(vehicle, player)
    --- if sandbox setting NotWhenChased is on and zombies are chasing, can not enter
    if SandboxVars.RVInterior.NotWhenChased and player:getStats():getNumChasingZombies() > 0 then
        return getText("UI_zombiesChasing")
    end

    --- if nearest zombie is closer than safe distance from sandbox settings, can not enter (feels like doesn't work correctly, at least with RenderLessZombies mod?)
    local zombie = getCell():getNearestVisibleZombie(player:getPlayerNum())
    if SandboxVars.RVInterior.SafeZombieDistance > 0 and zombie and
            zombie:getSquare():getMovingObjects():indexOf(zombie) >= 0 then -- to ignore deleted zombies
        local distance = IsoUtils.DistanceToSquared(zombie:getX(), zombie:getY(), player:getX(), player:getY())
        if distance < SandboxVars.RVInterior.SafeZombieDistance * SandboxVars.RVInterior.SafeZombieDistance then
            return getText("UI_zombiesNearby")
        end
    end

    --- if vehicle is moving, can not enter
    if math.abs(vehicle:getCurrentSpeedKmHour()) >= stationaryThreshold then
        return getText("UI_vehicleMoving")
    end

    --- if none of the above, then player can safely enter 
    --- no zombies chasing, no zombies nearby, vehicle not moving
    return nil
end


--- teleports player to interior, finish entering
local function enterInteriorFinish(player, pos)
    player:setX(pos[1]+1)
    player:setY(pos[2]+5)
    player:setZ(0)
    player:setLastX(pos[1]+1)
    player:setLastY(pos[2]+5)
    player:setLastZ(0)
end


--- start entering interior, check mod data and assign index, also check if player can enter or not
--- if player can't enter, say the reason
local function enterInteriorStart(player)
    local vehicle = player:getVehicle()
    if not vehicle then return end
    if not RVModData then initModData() end
    local index = assignInteriorIndex(vehicle)
    local check = checkIfPlayerCantEnter(vehicle, player)
    if index ~= nil then
        if check == nil then
            RVModData.RVInterior.interior_outsidepos[index] = {player:getX(), player:getY(), player:getZ()}
            RVModData.RVInterior.seat_index = vehicle:getSeat(player)
            RVModData.RVInterior.interior_index_current = index
            vehicle:exit(player)
            enterInteriorFinish(player, interior_mappos[index])
        else
            player:Say(getText("UI_cantEnter"))
            player:Say(check)
        end
    else
        player:Say(getText("UI_noFreeInteriors"))
    end
end

-----------------------------------------------------------------------------------------------------------------
--- Leave Interior ----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- TODO: for vehicles enter from back, move player to the back

--- leave interior and back to car
local function leaveInteriorFinish(player)
    local square = player:getCurrentSquare()
    if square == nil then return end
    if not RVModData then initModData() end
    for i = -1, 1 do
        for j = -1, 1 do
            local square_p = getCell():getGridSquare(player:getX() + i, player:getY() + j, player:getZ())
            if square_p then
                local vehicle = square_p:getVehicleContainer()
                if vehicle ~= nil then
                    local seat = RVModData.RVInterior.seat_index
                    vehicle:enter(seat, player)
                    triggerEvent("OnEnterVehicle", player)
                    Events.OnPlayerUpdate.Remove(leaveInteriorFinish)
                end
            end
        end
    end
end

--- start exiting interior
local function leaveInteriorStart(player)
    if not RVModData then initModData() end
    local currentIndex = RVModData.RVInterior.interior_index_current
    if currentIndex and RVModData.RVInterior.interior_outsidepos[currentIndex] then
        local position = RVModData.RVInterior.interior_outsidepos[currentIndex]
        player:setX(position[1])
        player:setY(position[2])
        player:setZ(position[3])
        player:setLastX(position[1])
        player:setLastY(position[2])
        player:setLastZ(position[3])
    else --- fallback coords, in case outdoor position is missing
        player:setX(10614)
        player:setY(9299)
        player:setZ(0)
        player:setLastX(10614)
        player:setLastY(9299)
        player:setLastZ(0)
    end
    Events.OnPlayerUpdate.Add(leaveInteriorFinish)
end



-----------------------------------------------------------------------------------------------------------------
---- Radial Menu and Context Menu -------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--- TODO: add Radial Menu Outside for vehicles entering from back
--- TODO: exit for vehicles entering from back, should move player to the back of vehicle
--- TODO: ...


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
                    context:addOption(getText("UI_exitrvinterior"), playerObj, leaveInteriorStart, playerObj)
                end
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(addExitOption)


--- add radial menu option, depending on cantEnter
local function addRadialOption(player, menu, cantEnter)
    local texture = cantEnter and getTexture("media/textures/rvInteriorEnterGrey.png") or getTexture("media/textures/rvInteriorEnter.png")
    menu:addSlice(getText("UI_enterrvinterior"), texture, enterInteriorStart, player)
end

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
            local check = checkIfPlayerCantEnter(vehicle, player)
            addRadialOption(player, menu, check ~= nil)
        end
    end
end