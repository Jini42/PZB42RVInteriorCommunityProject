# PZB42RVInteriorCommunityProject
Fork of Community ran Project Zomboid B42 RV Interior Mod from Janger

All credits to original mod author Maxwell, his credits as well as the author of Doomsday Motorhome mod
Steam Workshop Discussion Page: https://steamcommunity.com/workshop/filedetails/discussion/2822286426/592888629473342040/

Manual installation required, put folder in:
Windows: ..\Users\YOURNAME\Zomboid\mods
Linux: ..\home\YOURNAME\Zomboid\mods

23.02.2025 -
Updated and assigned version number 0.1.0
Changed mod folder structure, now shouldn't have duplicate files (at first I didn't know where to put what, so I put stuff everywhere)
A lot of corrections, renaming functions, code & comment cleaning and error fixing
Changes:
- (potentially) fixed adding radial menu slice multiple times
- changed mod data saving and loading, should be able to leave after logging out inside interior now
- added sandbox options back in, safe distance and chasing zombies will prevent from entering interior
- added sandbox options to change vehicles that can have interior (else it will default to Van, StepVan and VanAmbulance)
- now can have up to 12 vehicles with interiors, but same name vehicles will share the same interior instance
- the way the interiors are assigned is by the order of entering it (the first time you enter an interior, it will always be the first interior map layout, no matter the vehicle)

Potential issues: 
I have no idea what would happen if you enter an interior and then go into sandbox settings, remove the vehicle and add back in, repeating the process
Also since the interiors are assigned in order, switching the vehicle order in sandbox settings would maybe lead to "wrong" interiors? havent tested
Something with Zombie distance did not work correctly on my end, for chasing Zombies entering is disabled, that worked for me
I do have RenderLessZombies mod (overwriting files), so maybe that caused some issues with the original zombie distance code from build 41
Maybe Zombie can still spawn inside interior, have seen it happen once with _simpl version but haven't seen since, but also didn't change anything regarding that in the code so it might happen still




21.02.2025 -
RV_Interior_simpl is a very simple working version, manual installation required 
Current status v simpl:
- hardcoded vehicles that have an interior (for now I have put some vanilla vehicles in a list)
- can only enter from inside vehicle via radial menu
- exit via context menu while inside interior, going back to previous seat in vehicle
- only using one map, so multiple vehicles share the same interior
- generator not sync with car battery, for now it is always set to max fuel max condition
- the sandbox options check (if zombies nearby or chasing) exist but not used (should work though)
- sink / plumbing not implemented yet
- no multiplayer
- no hotkeys
- i have seen a zombie spawn inside interior once


Planned: adding features from original mod bit by bit 
