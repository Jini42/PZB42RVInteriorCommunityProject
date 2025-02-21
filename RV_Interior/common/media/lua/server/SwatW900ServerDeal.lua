local vehicleName = "Base.88W900swat"

RVInterior.addInterior(vehicleName, { 23701, 12600, 0 }, {0, 14, 0})

local sharedVehicles = {
    "Base.88w900firedept"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end