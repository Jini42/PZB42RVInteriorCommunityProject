local vehicleName = "Rotators.SemiTruck"

RVInterior.addInterior(vehicleName, { 23401, 12001, 0 }, {-1, 12, 0})

local sharedVehicles = {
    "Base.ATAPetyarbuiltSleeper",
    "Base.ATAPetyarbuiltSleeperLong"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
end