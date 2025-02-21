local vehicleName = "Base.88navistarbox"

RVInterior.addInterior(vehicleName, { 23401, 12600, 0 }, {0, 17, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.88navistarboxknoxdistillery",
    "Base.88navistarboxlectromax",
    "Base.88navistarboxmail",
    "Base.88navistarboxspiffo"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end