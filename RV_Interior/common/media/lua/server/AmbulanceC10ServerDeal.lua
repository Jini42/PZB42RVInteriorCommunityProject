local vehicleName = "Base.93c10vanambulance"

RVInterior.addInterior(vehicleName, { 24000, 12600, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.97bushAmbulance",
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end