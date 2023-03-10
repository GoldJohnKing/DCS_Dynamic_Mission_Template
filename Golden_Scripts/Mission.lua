local table = table
local math = math

-- Utils

local function get_random(tb)
    local keys = {}

    for key, vaule in pairs(tb) do
        table.insert(keys, key)
    end

    return tb[keys[math.random(#keys)]]
end

local function message_to_all(_text, _lasts_time)
    MESSAGE:New(_text, _lasts_time):ToAll()
end

local function destroy_groups(_group_names)
    SET_GROUP:New():AddGroupsByName(_group_names):ForEachGroup(
        function(_group)
            _group:Destroy(false)
        end
    )
end

-- End of Utils

message_to_all("Mission.lua Loading", 3) -- Debug

-- Enums

local SIDE = {
    BLUE = coalition.side.BLUE,
    RED = coalition.side.RED,
    NEUTRAL = coalition.side.NEUTRAL,
}

local COUNTRY = {
    [SIDE.BLUE] = country.id.CJTF_BLUE,
    [SIDE.RED] = country.id.CJTF_RED,
}

local ZONE_COLOR = {
    [SIDE.BLUE] = { 0, 0, 0.8 },
    [SIDE.RED] = { 0.8, 0, 0 },
    [SIDE.NEUTRAL] = { 0.8, 0.8, 0.8 },
}

local GROUP_TYPE = {
    GROUND = 0,
    HELI = 1, 
    PLANE = 2,
}

-- End of Enums

-- Definitions

local side_scores = {
    [SIDE.BLUE] = 0,
    [SIDE.RED] = 0,
}

local side_winning_scores = 5000

local zone_list = {
    ["Sharjah"] = SIDE.BLUE,
    ["Dubai"] = SIDE.RED,
    ["Alpha"] = SIDE.NEUTRAL,
    ["Bravo"] = SIDE.NEUTRAL,
    ["Charlie"] = SIDE.NEUTRAL,
    ["Delta"] = SIDE.NEUTRAL,
    ["Echo"] = SIDE.NEUTRAL,
    ["Foxtrot"] = SIDE.NEUTRAL,
}

local group_template = {
    [GROUP_TYPE.GROUND] = {
        -- Air Defense
        -- "HQ7",
        "Avenger",
        "Bradley",
        "Roland",
        -- "SA11",
        "SA13",
        -- "SA15",
        "SA19",
        -- "SA6",
        -- "SA8",
        "SA9",
        "Gepard",
        "M163",
        "ZSU234",
        "ZSU572",

        -- Armory
        "BTR80",
        "BTRRD",
        "HMMWV",
        "BMP3",
        "BTR82A",
        "M1126",
        "M2A2",
        "Warrior",
        "Challenger",
        "Leclerc",
        "Leopard2A6M",
        "M1A2",
        "MerkavaIV",
        "T72B3",
        "T80U",
        "T90",
        "Type59",
        "StrykerMGS",
        "ZBD04A",
        "ZTZ96B",

        -- Artillery
        "BM27",
        "BM21",
        "PLZ05",
        "2S3",
        "M109",
        "2S9",

        -- Unarmed
        "Tigr",
        "M978",
        "GAZ66",
        "KAMAZ43101",
        "KrAZ6322",
        "M939",
        "Ural375",
        "Ural4320T",

        -- Infantry
        "SA18",
        "Stinger",
    },
    [GROUP_TYPE.HELI] = {
        -- Heli
        "AH64D",
        "Ka50",
        "Ka50_3",
        "Mi24P",
    },
}

local group_template_disabled = {
    "HQ7",
    "SA11",
    "SA15",
    "SA6",
    "SA8",
}

-- End of Definitions

-- Zone Initialization

local zone_set = {
    [SIDE.BLUE] = SET_ZONE:New(),
    [SIDE.RED] = SET_ZONE:New(),
    [SIDE.NEUTRAL] = SET_ZONE:New(),
}

for key, value in pairs(zone_list) do
    zone_set[value]:AddZonesByName(key)
end

for key, value in pairs(zone_set) do
    value:DrawZone(-1, { 1, 1, 1 }, 1, ZONE_COLOR[key], 0.25, 1, true)
    
    -- TODO Draw Zone Names
    -- value:ForEachZone(
    --     function(_zone)
    --         MARKER:New(_zone:GetCoordinate(), _zone:GetName()):ToAll()
    --     end
    -- )
end

-- End of Zone Initialization

-- Group Initialization

local group_set = {
    [SIDE.BLUE] = SET_GROUP:New():FilterActive(true):FilterStart(),
    [SIDE.RED] = SET_GROUP:New():FilterActive(true):FilterStart(),
}

local group_spawn_index = {
    [SIDE.BLUE] = 0,
    [SIDE.RED] = 0,
}

-- Destroy all groups templates at mission start

for key, value in pairs(GROUP_TYPE) do
    destroy_groups(group_template[value])
end

destroy_groups(group_template_disabled)

-- End of Group Initialization

-- Group Spawn

local function on_group_spawn(_group, _side, _spawn_zone, _spawn_area, _target_zone)
    group_set[_side]:AddGroup(_group)

    -- Group Tasks
    _group:TaskRouteToZone(_target_zone, true, 100, "On Road")
    _group:EnRouteTaskEngageTargets(10000, "All")

    -- Group Options
    _group:OptionROEWeaponFree()
    _group:OptionROTEvadeFire()

    -- Handle Dead Events
    function _group:OnEventDead(EventData)
        -- group_set[_side]:RemoveGroupsByName(self:GetName())
        -- TODO Add Scores to Players
    end

    _group:HandleEvent(EVENTS.Dead)

    -- Specific Tasks, Options and Events for Air Groups
    if _group:IsAir() then
        _group:TaskLandAtZone(ZONE:FindByName(zone_set[_side]:GetRandom():GetName()), 15, true)

        _group:OptionAlarmStateRed() -- Do not assign this to SAM units as it will make them stop moving

        function _group:OnEventLand(EventData)
            TIMER:New(
                function()
                    self:Destroy(false)
                end
            ):Start(30)
        end

        _group:HandleEvent(EVENTS.Land)
    end

    -- Group Spawn as Immortal
    _group:SetCommandImmortal(true)
    TIMER:New(
        function()
            _group:SetCommandImmortal(false)
        end
    ):Start(15)

    -- Group Stuck Detection
    TIMER:New(
        function()
            if _group:IsInZone(_spawn_area) then
                env.info("Group " .. _group:GetName() .. " is stuck in zone " .. _spawn_area:GetName())
                _group:Destroy(false)
            end
        end
    ):Start(180)
end

local function group_spawn_random(_side, _type, _spawn_zone, _target_zone)
    local _alive_group_count, _alive_unit_count = group_set[_side]:CountAlive()

    if _alive_group_count > 150 or _alive_unit_count > 300 then
        local _side_name = "Blue"
        if _side == SIDE.RED then
            _side_name = "RED"
        end
        env.info("Group Spawn Limit exceed, _side = " .. _side_name ..", group = " .. _alive_group_count .. ", unit = " .. _alive_unit_count)
        return
    end

    local _group_prefix = nil

    if _side == SIDE.BLUE then
        _group_prefix = "B-"
    else
        _group_prefix = "R-"
    end

    if _spawn_zone == nil then
        _spawn_zone = zone_set[_side]:GetRandomZone()
    end

    local _spawn_area_set = SET_ZONE:New():FilterPrefixes(_spawn_zone:GetName() .. "_Spawn_"):FilterOnce()

    local _spawn_area = nil
    
    if _spawn_area_set:Count() ~= 0 then
        _spawn_area = _spawn_area_set:GetRandomZone()
    else
        _spawn_area = _spawn_zone
    end

    local _spawn_template = get_random(group_template[_type])
    local _group_spawn_index = group_spawn_index[_side]
    group_spawn_index[_side] = group_spawn_index[_side] + 1

    local _country = COUNTRY[_side]
    
    if _target_zone == nil then
        _target_zone = zone_set[SIDE.NEUTRAL]:GetRandomZone()
    end

    _group_prefix = _group_prefix .. _spawn_template .. "-" .. _spawn_zone:GetName() .. "-" .. _target_zone:GetName() .. "-" .. _group_spawn_index

    SPAWN:NewWithAlias(_spawn_template, _group_prefix)
        :InitCoalition(_side)
        :InitCountry(_country)
        :InitSkill("Excellent")
        :InitHeading(0, 359)
        :OnSpawnGroup(on_group_spawn, _side, _spawn_zone, _spawn_area, _target_zone)
        :SpawnInZone(_spawn_area, true)
end

TIMER:New(group_spawn_random, SIDE.BLUE, GROUP_TYPE.GROUND):Start(5, 60)
TIMER:New(group_spawn_random, SIDE.RED, GROUP_TYPE.GROUND):Start(5, 60)

TIMER:New(group_spawn_random, SIDE.BLUE, GROUP_TYPE.HELI):Start(90, 180)
TIMER:New(group_spawn_random, SIDE.RED, GROUP_TYPE.HELI):Start(90, 180)

-- End of Group Spawn

-- Startup Group Spawn

local function group_spawn_startup()
    local _count = 0
    zone_set[SIDE.NEUTRAL]:ForEachZone(
        function(_zone)
            local _side = SIDE.RED

            if _count < zone_set[SIDE.NEUTRAL]:Count() / 2 then
                _side = SIDE.BLUE
            end

            for i = 1, 5 do
                group_spawn_random(_side, GROUP_TYPE.GROUND, _zone, _zone)
            end

            _count = _count + 1
        end
    )
end

TIMER:New(group_spawn_startup):Start(5)

-- End of Startup Group Spawn

-- Zone Capture

local function zone_capture()
    zone_set[SIDE.NEUTRAL]:ForEachZone(
        function(_zone)
            _zone:Scan({Object.Category.UNIT}, {Unit.Category.GROUND_UNIT})

            local _side = SIDE.NEUTRAL

            if _zone:IsAllInZoneOfCoalition(SIDE.BLUE) then
                _side = SIDE.BLUE
            elseif _zone:IsAllInZoneOfCoalition(SIDE.RED) then
                _side = SIDE.RED
            end
            
            local _zone_index = _zone:GetName()

            if zone_list[_zone_index] ~= _side then
                zone_list[_zone_index] = _side
                _zone:UndrawZone()
                _zone:DrawZone(-1, { 1, 1, 1 }, 1, ZONE_COLOR[zone_list[_zone_index]], 0.25, 1, false)
            end
        end
    )
end

TIMER:New(zone_capture):Start(5, 30)

-- End of Zone Capture

-- Base Protect

local client_set = SET_CLIENT:New():FilterActive(true):FilterStart()

local function base_protect()
    local function _check_client_side(_client, _zone, _zone_side)
        if _client:GetCoalition() ~= _zone_side then
            MESSAGE:New("?????????????????????????????????????????????15????????????????????????"):ToClient(_client, 15)

            TIMER:New(
                function()
                    if _client:IsInZone(_zone) then
                        _client:Destroy(true)
                    end
                end
            ):Start(15)
        end
    end

    for key, value in pairs({SIDE.BLUE, SIDE.RED}) do
        zone_set[value]:ForEachZone(
            function(_zone)
                client_set:ForEachClientInZone(_zone, _check_client_side, _zone, value)
            end
        )
    end
end

TIMER:New(base_protect):Start(90, 30)

-- End of Base Protect

-- Side Scores

local function calculate_side_scores()
    local _captured_zones = {
        [SIDE.BLUE] = 0,
        [SIDE.RED] = 0,
        [SIDE.NEUTRAL] = 0,
    }

    for key, value in pairs(zone_list) do
        _captured_zones[value] = _captured_zones[value] + 1
    end

    for key, value in pairs(side_scores) do
        side_scores[key] = side_scores[key] + 10 * _captured_zones[key]
    end

    message_to_all(
        "=== ?????????????????? ===\n" ..
        "\n[??????]" ..
        "\n - ???????????????: " .. _captured_zones[SIDE.BLUE] ..
        "\n - ?????????????????????: " .. 5 * _captured_zones[SIDE.BLUE] ..
        "\n - ???????????????: " .. side_scores[SIDE.BLUE] ..
        "\n" ..
        "\n[??????]" ..
        "\n - ???????????????: " .. _captured_zones[SIDE.RED] ..
        "\n - ?????????????????????: " .. 5 * _captured_zones[SIDE.RED] ..
        "\n - ???????????????: " .. side_scores[SIDE.RED] ..
        "\n" ..
        "\n???????????????: " .. _captured_zones[SIDE.NEUTRAL] ..
        "\n" ..
        "\n????????????????????????: " .. side_winning_scores,
        58
    )

    local _blue_win = side_scores[SIDE.BLUE] > side_winning_scores
    local _red_win = side_scores[SIDE.RED] > side_winning_scores
    local _mission_end = true

    if _blue_win and _red_win then
        message_to_all("=== ???????????? ===", 60)
    elseif _blue_win then
        message_to_all("=== ???????????? ===", 60)
    elseif _red_win then
        message_to_all("=== ???????????? ===", 60)
    else
        _mission_end = false
    end

    if _mission_end then
        message_to_all("???????????????????????????????????????", 60)
        USERFLAG:New("FlagRestart"):Set(true, 30)
    end
end

TIMER:New(calculate_side_scores):Start(15, 60)

-- End of Side Scores

-- Scheduled Restart

local restart_time = 14400 -- 4 hours -- 10800 = 3 hours
local restart_hint_time = { 60, 180, 300, 900 }
local restart_hint_lasts_time = 90

for key, value in pairs(restart_hint_time) do -- Restart hint
	TIMER:New(message_to_all, "???????????????" .. value / 60 .. "????????????????????????", restart_hint_lasts_time):Start(restart_time - value)
end

TIMER:New(message_to_all, "??????????????????????????????", restart_hint_lasts_time):Start(restart_time - 15)

USERFLAG:New("FlagRestart"):Set(true, restart_time)

-- End of Scheduled Restart

-- Server Message

local server_message_lasts_time = 60
local server_message_delay = 30
local server_message_duration = 1800
local server_message_text = {
    "???????????? [#2?????????] <??????????????????????????????> ????????????\n\nQQ??????750508967\nKOOK(?????????)???????????????95367853\n\n??????????????????????????????KOOK?????????????????????????????????????????????????????????????????????\n",
    "===== ??????????????? =====\n\n??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????QQ???????????????????????????\n",
    "????????????????????????PvPvE??????????????????????????????????????????????????????????????????????????????PVE???PVP?????????\n????????????????????????????????????????????????????????????28????????????????????????????????????????????????????????????\n",
    "???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????\n?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????\n",
}

for key, value in pairs(server_message_text) do
    TIMER:New(message_to_all, value, server_message_lasts_time):Start(server_message_delay, server_message_duration)
    server_message_delay = server_message_delay + 5
end

-- End of Server Message

message_to_all("Mission.lua Loaded", 3) -- Debug
