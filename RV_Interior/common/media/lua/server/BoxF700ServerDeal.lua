local vehicleName = "Base.f700box"

RVInterior.addInterior(vehicleName, { 23401, 12900, 0 }, {0, 14, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.87macktruckbox",
    "Base.93fl70box",
    "Base.SC_FordF700BoxTruck",
    "Base.SC_FordF700GigaMart",
    "Base.SC_FordF700Greenes",
    "Base.SC_FordF700MacTools"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end
