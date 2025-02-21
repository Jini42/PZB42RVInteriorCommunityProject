local vehicleName = "Base.chevystepvan"

RVInterior.addInterior(vehicleName, { 24600, 12300, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.93vandura",
    "Base.93vanduraKnoxDisti",
    "Base.93vanduraScarlet",
    "Base.93vandurafossoil",
    "Base.93vanduramassgenfacvo",
    "Base.93vanduraspiffo"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end