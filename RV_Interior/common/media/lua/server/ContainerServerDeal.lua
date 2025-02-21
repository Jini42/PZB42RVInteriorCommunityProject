local vehicleName = "Base.isoContainer2"

RVInterior.addInterior(vehicleName, { 24001, 13200, 0 }, {0, 14, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.isoContainer4"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end