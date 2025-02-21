local vehicleName = "Base.87macktruckswat"

RVInterior.addInterior(vehicleName, { 23701, 12900, 0 }, {0, 14, 0})

local sharedVehicles = {
    "Base.93FL70swat"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end