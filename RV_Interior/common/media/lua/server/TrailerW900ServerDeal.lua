local vehicleName = "Base.88w900"

RVInterior.addInterior(vehicleName, { 23401, 12300, 0 }, {0, 19, 0})
RVInterior.canEnterFromBack(vehicleName,true)

local sharedVehicles = {
    "Base.88w900fossoil",
    "Base.88w900massgenfacvo",
    "Base.88w900scarletdist",
    "Rotators.SemiTrailerVan"
}

for i=1,#sharedVehicles do
    RVInterior.shareInterior(sharedVehicles[i], vehicleName)
    RVInterior.canEnterFromBack(sharedVehicles[i], true)
end