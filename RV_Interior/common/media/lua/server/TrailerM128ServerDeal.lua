local vehicleName = "Base.TrailerM128van"

RVInterior.addInterior(vehicleName, { 22801, 13201, 0 }, {-1, 11, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.TrailerM129van"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end