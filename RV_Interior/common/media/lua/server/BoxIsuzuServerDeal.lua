local vehicleName = "Base.isuzubox"

RVInterior.addInterior(vehicleName, { 23701, 12300, 0 }, {0, 14, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.isuzuboxelec",
    "Base.isuzuboxfood",
    "Base.ATA_Luton"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end