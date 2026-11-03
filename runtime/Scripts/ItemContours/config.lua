-- User-editable settings. Values are normalized RGBA (0..1).
return {
 colors={weapons={1,0,0,1},valuables={0,1,0,1},mission={1,1,0,1}},
 categories={weapons=true,valuables=true,mission=true},
 -- Exact worlds from the game's Maps_Data soft references; excludes menu/lobby.
 missionMaps={['World /Game/Maps/SpaceShip.SpaceShip']=true,['World /Game/Maps/PolarMap.PolarMap']=true},
 scanIntervalMs=1000,
 maxItems=1024,
 maxActorsPerScan=2048,
 thickness=2,
 opacity=1,
}
