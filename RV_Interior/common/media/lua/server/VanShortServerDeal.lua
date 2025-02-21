local vehicleName = "Base.93vandurashort"

RVInterior.addInterior(vehicleName, { 24300, 12600, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.93c10vanshortlectromax",
    "Base.93vandurashortspiffo",
    "Base.87gmcarmouredcar",
    "Base.ATA_VanDeRumba",
    "Base.SC_G30BoxVan",
    "Base.SC_G30Mail",
    "Base.SC_G30McCoy",
    "Base.SC_G30VanNormal",
    "Base.SC_G30VanWindowless",
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end