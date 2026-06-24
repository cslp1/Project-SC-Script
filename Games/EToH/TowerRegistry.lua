local Categories = {
    Ring1 = 9070657865,
    Ring2 = 9070979698,
    Ring3 = 9070980083,
    Ring4 = 9070980555,
    Ring5 = 9070980846,
    Ring6 = 9070981164,
    Ring7 = 9070981409,
    Ring9 = 9070982474,
    Zone1 = 9071001075,
    Zone2 = 9071001366,
    Zone3 = 9071001563,
    Zone7 = 9071002677,
    Zone8 = 9071002915,
    Zone9 = 9071004505,
    ["Pit-of-Misery"] = 15639952229,
    ["100M-Event-Replay"] = 115856553162061,
}

return {
    Categories = Categories,
    Towers = {
        --Ring 1
        { name = "ToIG",  category = "Ring1", suggestedTime = { min = "5", sec = "0" } },
        --Ring 2
        { name = "ToDC",  category = "Ring2", suggestedTime = { min = "3", sec = "0" } },
        --Ring 3
        { name = "ToC",  category = "Ring3", suggestedTime = { min = "3", sec = "0" } },
        --Ring 4
        { name = "ToVS",  category = "Ring4", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToI",  category = "Ring4", suggestedTime = { min = "3", sec = "0" } },
        --Ring 5
        { name = "ToIB",  category = "Ring5", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToFN",  category = "Ring5", suggestedTime = { min = "3", sec = "0" } },
        --Ring 6
        { name = "ToIM",  category = "Ring6", suggestedTime = { min = "3", sec = "0" } },
        --Ring 7
        { name = "ToER",  category = "Ring7", suggestedTime = { min = "3", sec = "30" } },
        --Ring 9
        { name = "ToHA",  category = "Ring9", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToBT",  category = "Ring9", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToCA",  category = "Ring9", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToNS",  category = "Ring9", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToCP",  category = "Ring9", suggestedTime = { min = "3", sec = "0" } },
        --Zone 1
        { name = "ToTL",  category = "Zone1", suggestedTime = { min = "1", sec = "0" } },
        --Zone 2
        { name = "ToDT",  category = "Zone2", suggestedTime = { min = "5", sec = "0" } },
        --Zone 3
        { name = "ToHH",  category = "Zone3", suggestedTime = { min = "3", sec = "0" } },
        --Zone 7
        { name = "ToFM",  category = "Zone7", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToUA",  category = "Zone7", suggestedTime = { min = "3", sec = "0" } },
        --Zone 8
        { name = "ToDIE",  category = "Zone8", suggestedTime = { min = "3", sec = "0" } },
        --Zone 9
        { name = "ToEMP",  category = "Zone9", suggestedTime = { min = "3", sec = "0" } },
        --Pit of Misery
        { name = "ToVH",  category = "Pit-of-Misery", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToTRP",  category = "Pit-of-Misery", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToEV",  category = "Pit-of-Misery", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToWM",  category = "Pit-of-Misery", suggestedTime = { min = "3", sec = "0" } },
        { name = "ToBF",  category = "Pit-of-Misery", suggestedTime = { min = "3", sec = "0" } },
    },
 }
    TowerRush = {
        { name = "PoMTR", category = "Pit-of-Misery", suggestedTime = { min = "200", sec = "0" }, isTowerRush = true, },
    },
}
