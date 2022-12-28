local script_path = "D:/GitRepos/DCS_Dynamic_Mission_Template/Golden_Scripts/"

local script_list =
{
    -- Load order must be correct
    "mist_4_5_113.lua",
    "GroundUnitAutoAttack.lua",
    "Hercules_Cargo.lua",
    "Moose.lua",
    "Mission.lua",
}

local function load_scripts(path, list)
    for index, value in ipairs(list) do
        dofile(path .. value)
    end
end

if lfs then
    script_path = lfs.writedir() .. "Missions/Scripts/"

    env.info("Script Loader: LFS available, using relative script load path: " .. script_path)
else
    env.info("Script Loader: LFS not available, using default script load path: " .. script_path)
end

load_scripts(script_path, script_list)
