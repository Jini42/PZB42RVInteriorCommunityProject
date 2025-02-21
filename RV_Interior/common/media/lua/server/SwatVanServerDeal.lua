local vehicleName = "Base.chevystepvanswat"

RVInterior.addInterior(vehicleName, { 23700, 13200, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.97bushmaster"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end