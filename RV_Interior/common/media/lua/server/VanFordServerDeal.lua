local vehicleName = "Base.86fordE150"

RVInterior.addInterior(vehicleName, { 24300, 12300, 0 }, {0, 13, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.86fordE150dnd",
    "Base.86fordE150mm",
    "Base.86fordE150pd",
    "Base.86fordE150slide",
    "Base.86econoline",
    "Base.86econolineflorist",
    "Base.SC_FordF700ArmoredBank",
    "Base.SC_FordF700ArmoredPolice"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end

