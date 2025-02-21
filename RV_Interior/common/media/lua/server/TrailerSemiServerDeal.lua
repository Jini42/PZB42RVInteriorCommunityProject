local vehicleName = "Base.Trailersemi"

RVInterior.addInterior(vehicleName, { 23401, 13200, 0 }, {0, 14, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.TrailerM747lowbed",
    "Rotators.SemiTruckBox"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end