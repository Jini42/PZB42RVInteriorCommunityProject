local vehicleName = "Base.93c10boxambulance"

RVInterior.addInterior(vehicleName, { 24001, 12000, 0 }, {0, 14, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.87gmcc7000ambulance",
    "Base.93frieghtlignerambulance",
    "Base.93frieghtlignerambulancefire"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end