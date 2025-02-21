local vehicleName = "Base.93G10van"

RVInterior.addInterior(vehicleName, { 24600, 12000, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.93G10KnoxDisti",
    "Base.93G10Scarlet",
    "Base.93G10fossoil",
    "Base.93G10massgenfacvo",
    "Base.93G10vanlectromax",
    "Base.86fordE150long"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end