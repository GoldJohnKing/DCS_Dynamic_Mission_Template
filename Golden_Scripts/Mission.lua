local table = table
local math = math

-- Enums

local SIDE = {
    BLUE = coalition.side.BLUE,
    RED = coalition.side.RED,
    NEUTRAL = coalition.side.NEUTRAL,
}

local SIDE_ENEMY = {
    [SIDE.BLUE] = SIDE.RED,
    [SIDE.RED] = SIDE.BLUE,
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
    GROUND_ATTACK = 0,
    GROUND_DEFENSE = 1,
    GROUND_TRANSPORT = 2,
    GROUND_ARMED = 3,
    GROUND_UNARMED = 4,
    HELI_ATTACK = 5,
    HELI_TRANSPORT = 6,
    PLANE = 7,
}

local NAME_PREFIX = {
    [SIDE.BLUE] = "B",
    [SIDE.RED] = "R",
}

local EVENT_TYPE = {
    EVENTS.Dead,
    EVENTS.Hit,
    EVENTS.Land,
}

-- End of Enums

-- Utils

local function get_random(tb)
    local keys = {}

    for key, vaule in pairs(tb) do
        table.insert(keys, key)
    end

    return tb[keys[math.random(#keys)]]
end

local function table_merge(_table_destination, _table_source)
    for key, value in pairs(_table_source) do
        table.insert(_table_destination, value)
    end

    return _table_destination
end

local function message_to_all(_text, _lasts_time)
    if _lasts_time == nil then
        _lasts_time = 90
    end

    MESSAGE:New(_text, _lasts_time):ToAll()
end

local log_enabled = true

local function log(_string)
    if log_enabled == true then
        env.info("[GJK] " .. _string)
    end
end

local function draw_zones(_zones)
    for key, value in pairs(_zones) do
        ZONE:FindByName(key):DrawZone(-1, { 1, 1, 1 }, 1, ZONE_COLOR[value], 0.25, 1, false)
    end
end

local function get_all_zones(_zones)
    local _set_zones = {
        [SIDE.BLUE] = SET_ZONE:New(),
        [SIDE.RED] = SET_ZONE:New(),
        [SIDE.NEUTRAL] = SET_ZONE:New(),
    }

    for key, value in pairs(_zones) do
        _set_zones[value]:AddZonesByName(key)
    end

    return _set_zones
end

local function combine_set_zones(_set_zones_table)
    local _set_zones = SET_ZONE:New()
    for key, value in pairs(_set_zones_table) do
        value:ForEachZone(
            function(_zone)
                _set_zones:AddZone(_zone)
            end
        )
    end
    return _set_zones
end

local function destroy_groups(_group_names)
    SET_GROUP:New():AddGroupsByName(_group_names):ForEachGroup(
        function(_group)
            _group:Destroy(false)
        end
    )
end

local function group_task_land_at_zone(_group, _landing_zone)
    local _task_land = _group:TaskLandAtZone(_landing_zone, nil, true)
    local _waypoint = _landing_zone:GetCoordinate():WaypointAirTurningPoint()

    _group:SetTaskWaypoint(_waypoint, _task_land)
    _group:Route({ _waypoint }, 1)
end

local function group_task_orbit_at_zone(_group, _target_zone, _altitude, _speed)
    local _task_orbit = _group:TaskOrbitCircleAtVec2(_target_zone:GetRandomVec2(), _altitude, _speed)
    local _waypoint = _target_zone:GetCoordinate():WaypointAirTurningPoint()

    _group:SetTaskWaypoint(_waypoint, _task_orbit)
    _group:Route({ _waypoint }, 1)
end

local function group_is_alive(_group)
    return _group ~= nil and _group:IsAlive() == true and _group:CountAliveUnits() ~= 0
end

local function group_is_dead(_group)
    return not group_is_alive(_group)
end

local function group_is_damaged(_group)
    return _group:GetLife() < _group:GetLife0() - 1
end

-- End of Utils

message_to_all("Mission.lua Loading", 3) -- Debug

-- Definitions

local side_scores = {
    [SIDE.BLUE] = 0,
    [SIDE.RED] = 0,
}

local side_winning_scores = 5000
local scores_per_zone = 10

local airports = {
    ["Dubai"] = SIDE.RED,
    ["Minhad"] = SIDE.BLUE,
}

local zones = {
    ["Alpha"] = SIDE.RED,
    ["Bravo"] = SIDE.RED,
    ["Charlie"] = SIDE.NEUTRAL,
    ["Delta"] = SIDE.BLUE,
    ["Echo"] = SIDE.BLUE,
}

-- End of Definitions

-- Airports

-- Draw airport zones
draw_zones(airports)

-- Airport protection
local client_set = SET_CLIENT:New():FilterActive(true):FilterStart()

local function airport_protect()
    local function _check_client_side(_client, _airport, _airport_side)
        if _client:GetCoalition() ~= _airport_side then
            MESSAGE:New("请立即离开敌军基地！否则您将在15秒后被强制摧毁！"):ToClient(_client, 15)

            TIMER:New(
                function()
                    if _client:IsInZone(_airport) then
                        _client:Destroy(true)
                    end
                end
            ):Start(15)
        end
    end

    for key, value in pairs(airports) do
        local _airport = ZONE:FindByName(key)
        client_set:ForEachClientInZone(_airport, _check_client_side, _airport, value)
    end
end

TIMER:New(airport_protect):Start(30, 30)

-- End of Airports

-- Zones

-- Draw zones
draw_zones(zones)

local function draw_zone_names(_zones)
    for key, value in pairs(_zones) do
        local _zone = ZONE:FindByName(key)
        _zone:GetCoordinate():TextToAll(_zone:GetName(), -1, { 0, 0, 0 }, 0.75, nil, 0, 18, true)
    end
end

draw_zone_names(zones)

-- Zone status update
local function zone_update()
    local _set_zones = get_all_zones(zones)

    for key, value in pairs(_set_zones) do
        value:ForEachZone(
            function(_zone)
                _zone:Scan({ Object.Category.UNIT }, { Unit.Category.GROUND_UNIT })

                local _side = SIDE.NEUTRAL

                if _zone:IsAllInZoneOfCoalition(SIDE.BLUE) then
                    _side = SIDE.BLUE
                elseif _zone:IsAllInZoneOfCoalition(SIDE.RED) then
                    _side = SIDE.RED
                end

                local _zone_index = _zone:GetName()

                if zones[_zone_index] ~= _side then
                    zones[_zone_index] = _side
                    _zone:UndrawZone()
                    _zone:DrawZone(-1, { 1, 1, 1 }, 1, ZONE_COLOR[zones[_zone_index]], 0.25, 1, false)
                end
            end
        )
    end
end

TIMER:New(zone_update):Start(2, 30)

-- Scores
local function calculate_side_scores()
    local _captured_zones = {
        [SIDE.BLUE] = 0,
        [SIDE.RED] = 0,
        [SIDE.NEUTRAL] = 0,
    }

    for key, value in pairs(zones) do
        _captured_zones[value] = _captured_zones[value] + 1
    end

    local _scores_increment = {
        [SIDE.BLUE] = 0,
        [SIDE.RED] = 0,
    }

    for key, value in pairs(side_scores) do
        _scores_increment[key] = scores_per_zone * _captured_zones[key]
        side_scores[key] = side_scores[key] + _scores_increment[key]
    end

    message_to_all(
        "=== 阵营得分状态 ===\n" ..
        "\n[蓝方]" ..
        "\n - 占领区数量: " .. _captured_zones[SIDE.BLUE] ..
        "\n - 每分钟固定收益: " .. _scores_increment[SIDE.BLUE] ..
        "\n - 当前总得分: " .. side_scores[SIDE.BLUE] ..
        "\n" ..
        "\n[红方]" ..
        "\n - 占领区数量: " .. _captured_zones[SIDE.RED] ..
        "\n - 每分钟固定收益: " .. _scores_increment[SIDE.RED] ..
        "\n - 当前总得分: " .. side_scores[SIDE.RED] ..
        "\n" ..
        "\n中立区数量: " .. _captured_zones[SIDE.NEUTRAL] ..
        "\n" ..
        "\n阵营胜利所需得分: " .. side_winning_scores,
        58
    )

    local _blue_win = side_scores[SIDE.BLUE] > side_winning_scores
    local _red_win = side_scores[SIDE.RED] > side_winning_scores
    local _mission_end = true

    if _blue_win and _red_win then
        message_to_all("=== 双方平局 ===", 60)
    elseif _blue_win then
        message_to_all("=== 蓝方胜利 ===", 60)
    elseif _red_win then
        message_to_all("=== 红方胜利 ===", 60)
    else
        _mission_end = false
    end

    if _mission_end then
        message_to_all("任务完成！服务器即将重启！", 60)
        USERFLAG:New("FlagRestart"):Set(true, 30)
    end
end

TIMER:New(calculate_side_scores):Start(15, 60)

-- End of Zones

-- Groups

-- Group template
local group_template = {
    [GROUP_TYPE.GROUND_ATTACK] = {
        -- Armory
        "BTR80",
        "BTR82A",
        "M1126",
        "Warrior",
        "Challenger",
        "Leclerc",
        "Leopard2A6M",
        "M1A2",
        "MerkavaIV",
        "T72B3",
        "Type59",
        "StrykerMGS",

        -- Artillery
        "PLZ05",
        "2S3",
        "M109",
        "2S9",
    },
    [GROUP_TYPE.GROUND_DEFENSE] = {
        -- Air Defense
        "Avenger",
        "Roland",
        "SA13",
        "SA9",
        "Gepard",
        "M163",
        "ZSU234",
        "ZSU572",

        -- Infantry
        "SA18",
        "Stinger",
    },
    [GROUP_TYPE.GROUND_TRANSPORT] = {
        -- Unarmed
        "Tigr",
        "M978",
        "GAZ66",
        "KAMAZ43101",
        "KrAZ6322",
        "M939",
        "Ural375",
        "Ural4320T",
    },
    [GROUP_TYPE.GROUND_ARMED] = {},
    [GROUP_TYPE.GROUND_UNARMED] = {},
    [GROUP_TYPE.HELI_ATTACK] = {
        "AH1W",
        "AH64D",
        "Ka50_3",
        "Mi24P",
    },
    [GROUP_TYPE.HELI_TRANSPORT] = {
        "CH47D",
        "Mi26",
        "Mi8",
        "UH1H",
        "UH60A",
    },
}

local group_template_disabled = {
    -- Air Defense
    "HQ7",
    "SA11",
    "SA15",
    "SA19",
    "SA6",
    "SA8",

    -- Armory
    "Bradley",
    "BTRRD",
    "HMMWV",
    "BMP3",
    "M2A2",
    "T80U",
    "T90",
    "ZBD04A",
    "ZTZ96B",

    -- Artillery
    "BM27",
    "BM21",

    -- Helicopter
    "Mi28N",
    "Ka50",
}

table_merge(group_template[GROUP_TYPE.GROUND_ARMED], group_template[GROUP_TYPE.GROUND_ATTACK])
table_merge(group_template[GROUP_TYPE.GROUND_ARMED], group_template[GROUP_TYPE.GROUND_DEFENSE])
table_merge(group_template[GROUP_TYPE.GROUND_UNARMED], group_template[GROUP_TYPE.GROUND_TRANSPORT])

-- Destroy all groups templates at mission start
for key, value in pairs(GROUP_TYPE) do
    destroy_groups(group_template[value])
end

destroy_groups(group_template_disabled)

local group_spawn_index = {
    [SIDE.BLUE] = 0,
    [SIDE.RED] = 0,
}

local on_group_spawn = nil

-- Spawn random group
local function group_spawn_random(_side, _type, _spawn_zone, _target_zone)
    -- TODO move to caller
    if _spawn_zone == nil then
        local _set_airports = get_all_zones(airports)
        _spawn_zone = _set_airports[_side]:GetRandomZone()
    end

    local _set_spawn_area = SET_ZONE:New():FilterPrefixes(_spawn_zone:GetName() .. "_Spawn_"):FilterOnce()

    local _spawn_area = nil

    if _set_spawn_area:Count() ~= 0 then
        _spawn_area = _set_spawn_area:GetRandomZone()
    else
        _spawn_area = _spawn_zone
    end

    if _target_zone == nil then
        local _set_zones = get_all_zones(zones)
        local _set_zones_target = combine_set_zones({ _set_zones[SIDE_ENEMY[_side]], _set_zones[SIDE.NEUTRAL] })

        if _type == GROUP_TYPE.HELI_TRANSPORT then
            _set_zones_target = combine_set_zones({ _set_zones_target, _set_zones[_side] })
        end

        _target_zone = _set_zones_target:GetRandomZone()
    end

    local _set_target_area = SET_ZONE:New():FilterPrefixes("LZ_" .. _target_zone:GetName() .. "_" .. NAME_PREFIX[_side])
        :FilterOnce()

    local _target_area = nil

    if _set_target_area:Count() ~= 0 then
        _target_area = _set_target_area:GetRandomZone()
    else
        _target_area = _target_zone
    end

    local _spawn_template = get_random(group_template[_type])

    local _group_spawn_index = group_spawn_index[_side]
    group_spawn_index[_side] = group_spawn_index[_side] + 1

    local _group_name = NAME_PREFIX[_side] ..
        "-" ..
        _spawn_template .. "-" .. _spawn_zone:GetName() .. "-" .. _target_zone:GetName() .. "-" .. _group_spawn_index

    SPAWN:NewWithAlias(_spawn_template, _group_name)
        :InitCoalition(_side)
        :InitCountry(COUNTRY[_side])
        :InitSkill("Excellent")
        :InitHeading(0, 359)
        :OnSpawnGroup(on_group_spawn, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        :SpawnInZone(_spawn_area, true)
end

-- Specific tasks for different types of groups

local group_tasks = {
    [GROUP_TYPE.GROUND_ATTACK] = nil,
    [GROUP_TYPE.GROUND_DEFENSE] = nil,
    [GROUP_TYPE.GROUND_TRANSPORT] = nil,
    [GROUP_TYPE.GROUND_ARMED] = nil,
    [GROUP_TYPE.GROUND_UNARMED] = nil,
    [GROUP_TYPE.HELI_ATTACK] = nil,
    [GROUP_TYPE.HELI_TRANSPORT] = nil,
}


group_tasks[GROUP_TYPE.GROUND_ATTACK] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone,
                                                 _target_area)
    _group:TaskRouteToZone(_target_zone, true, 100, "On Road")
    _group:PatrolZones({ _target_zone }, 100, "On Road", 30, 180)
end

group_tasks[GROUP_TYPE.GROUND_DEFENSE] = group_tasks[GROUP_TYPE.GROUND_ATTACK]
group_tasks[GROUP_TYPE.GROUND_TRANSPORT] = group_tasks[GROUP_TYPE.GROUND_ATTACK]
group_tasks[GROUP_TYPE.GROUND_ARMED] = group_tasks[GROUP_TYPE.GROUND_ATTACK]
group_tasks[GROUP_TYPE.GROUND_UNARMED] = group_tasks[GROUP_TYPE.GROUND_ATTACK]

group_tasks[GROUP_TYPE.HELI_ATTACK] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
    group_task_orbit_at_zone(_group, _target_zone, 100, 100)
end

group_tasks[GROUP_TYPE.HELI_TRANSPORT] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone,
                                                  _target_area)
    group_task_land_at_zone(_group, _target_area)
end

local group_events = {
    [GROUP_TYPE.HELI_ATTACK] = nil,
    [GROUP_TYPE.HELI_TRANSPORT] = nil,
    default = nil,
}

group_events.default = {
    [EVENTS.Dead] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        _group:UnHandleEvent(EVENTS.Dead)

        function _group:OnEventDead(EventData)
            -- TODO Add Scores to Players
        end

        _group:HandleEvent(EVENTS.Dead)
    end,
}

group_events[GROUP_TYPE.HELI_ATTACK] = {
    [EVENTS.Land] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        function _group:OnEventLand(EventData)
            _group:UnHandleEvent(EVENTS.Land)

            TIMER:New(
                function()
                    self:Destroy(false)
                end
            ):Start(90)
        end

        _group:HandleEvent(EVENTS.Land)
    end,

    [EVENTS.Hit] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        function _group:OnEventHit(EventData)
            if group_is_damaged(_group) then
                _group:UnHandleEvent(EVENTS.Hit)

                local _set_airports = get_all_zones(airports)
                local _landing_zone = _set_airports[_side]:GetRandomZone()

                TIMER:New(group_task_land_at_zone, _group, _landing_zone):Start(5)
            end
        end

        _group:HandleEvent(EVENTS.Hit)
    end,
}

group_events[GROUP_TYPE.HELI_TRANSPORT] = {
    [EVENTS.Land] = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        function _group:OnEventLand(EventData)
            _group:UnHandleEvent(EVENTS.Land)

            TIMER:New(
                function()
                    if group_is_dead(self) then
                        return
                    end

                    if self:IsInZone(_target_area) then
                        local _group_spawn_type = GROUP_TYPE.GROUND_ATTACK

                        if zones[_target_zone:GetName()] == _side then
                            _group_spawn_type = GROUP_TYPE.GROUND_ARMED
                        end

                        local _side_name = "blue"
                        if _side == SIDE.RED then
                            _side_name = "red"
                        end

                        -- TODO Decide target zone before spawning transport helicopters
                        local _set_groups_in_zones = SET_GROUP:New()
                            :FilterZones({ _target_zone })
                            :FilterCoalitions(_side_name)
                            :FilterCategoryGround()
                            :FilterActive(true)
                            :FilterStart()

                        local _count_groups, _count_units = _set_groups_in_zones:CountAlive()

                        if _count_groups <= 5 then
                            group_spawn_random(_side, _group_spawn_type, _target_area, _target_zone)
                        end
                    end

                    self:Destroy(false)
                end
            ):Start(90)
        end

        _group:HandleEvent(EVENTS.Land)
    end,

    [EVENTS.Hit] = group_events[GROUP_TYPE.HELI_ATTACK][EVENTS.Hit],
}

local function group_options(_group)
    if not _group:IsGround() then
        -- Do not assign this to AA units as it will make them stop moving
        _group:OptionAlarmStateRed()
    end

    if _group:OptionROEWeaponFreePossible() then
        _group:OptionROEWeaponFree()
    end

    if _group:OptionROTEvadeFirePossible() then
        _group:OptionROTEvadeFire()
    end
end

local group_status_check = {
    ground = nil,
    air = nil,
}

group_status_check.air = function(_group, _previous_landed)
    -- Exit if group is dead
    if group_is_dead(_group) then
        log("group_status_check.air: group is dead") -- Debug
        return
    end

    -- Check if group is landed
    local _current_landed = _group:AllOnGround()

    if _previous_landed and _current_landed then
        _group:Destroy(false)

        return
    end

    TIMER:New(group_status_check.air, _group, _current_landed):Start(90)
end

group_status_check.ground = function(_group, _target_zone, _previous_coordinate, _previous_stuck)
    -- Exit if group is dead
    if group_is_dead(_group) then
        log("group_status_check.air: group is dead")
        return
    end

    -- Check if group is stuck
    local _current_coordinate = _group:GetCoordinate()
    local _current_stuck = false

    if _current_coordinate:Get2DDistance(_previous_coordinate) < 15 then
        _current_stuck = true
    end

    if _previous_stuck then
        if _current_stuck then
            _group:ClearTasks()
            _group:TaskRouteToVec2(_group:GetCoordinate():GetRandomVec2InRadius(150, 300), 25, "Off Road")
        else
            _group:TaskRouteToZone(_target_zone, true, 100, "On Road")
            _group:PatrolZones({ _target_zone }, 100, "On Road", 30, 180)
        end
    end

    TIMER:New(group_status_check.ground, _group, _target_zone, _current_coordinate, _current_stuck):Start(90)
end

-- On group spawn
on_group_spawn = function(_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
    if group_tasks[_type] ~= nil then
        group_tasks[_type](_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
    end

    for key, value in pairs(EVENT_TYPE) do
        if group_events[_type] ~= nil and group_events[_type][value] ~= nil then
            group_events[_type][value](_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        elseif group_events.default[value] ~= nil then
            group_events.default[value](_group, _side, _type, _spawn_zone, _spawn_area, _target_zone, _target_area)
        end
    end

    group_options(_group)

    if _group:IsAir() and group_status_check.air ~= nil then
        TIMER:New(group_status_check.air, _group, false):Start(180)
    elseif _group:IsGround() and group_status_check.ground ~= nil then
        TIMER:New(group_status_check.ground, _group, _target_zone, _group:GetCoordinate(), false):Start(180)
    end
end

TIMER:New(group_spawn_random, SIDE.BLUE, GROUP_TYPE.HELI_TRANSPORT):Start(90, 90)
TIMER:New(group_spawn_random, SIDE.RED, GROUP_TYPE.HELI_TRANSPORT):Start(90, 90)

TIMER:New(group_spawn_random, SIDE.BLUE, GROUP_TYPE.HELI_ATTACK):Start(300, 300)
TIMER:New(group_spawn_random, SIDE.RED, GROUP_TYPE.HELI_ATTACK):Start(300, 300)

-- Spawn groups in zones at startup
local function group_spawn_startup()
    local _set_zones = get_all_zones(zones)

    for key, value in pairs({ SIDE.BLUE, SIDE.RED }) do
        _set_zones[value]:ForEachZone(
            function(_zone)
                for i = 1, 2 do
                    group_spawn_random(value, GROUP_TYPE.GROUND_ATTACK, _zone, _zone)
                end
                for i = 1, 3 do
                    group_spawn_random(value, GROUP_TYPE.GROUND_DEFENSE, _zone, _zone)
                end
            end
        )
    end
end

TIMER:New(group_spawn_startup):Start(1)

-- End of Groups

-- Scheduled Restart

local restart_time = 14400 -- 4 hours -- 10800 = 3 hours
local restart_hint_time = { 60, 180, 300, 900 }
local restart_hint_lasts_time = 90

for key, value in pairs(restart_hint_time) do -- Restart hint
    TIMER:New(message_to_all, "服务器将于" .. value / 60 .. "分钟后定时重启！", restart_hint_lasts_time):
        Start(restart_time - value)
end

TIMER:New(message_to_all, "服务器即将定时重启！", restart_hint_lasts_time):Start(restart_time - 15)

USERFLAG:New("FlagRestart"):Set(true, restart_time)

-- End of Scheduled Restart

-- Server Message

local server_message_lasts_time = 60
local server_message_delay = 30
local server_message_duration = 1800
local server_message_text = {
    "欢迎来到 [#2金家寨] <波斯湾：直升机大混战> 服务器！\n\nQQ群：750508967\nKOOK(开黑啦)语音频道：95367853\n\n强烈建议各位玩家加入KOOK语音频道，加强沟通，相互配合，以提升作战效率！\n",
    "===== 服务器公告 =====\n\n本服务器设有自动封禁系统，攻击友军后请尽快道歉并获取谅解。如果您不幸被自动封禁，请在QQ群内联系老金解封。\n",
    "本服务器以大规模PvPvE作战为主要玩法，服务端的运算压力显著高于其他轻量化的PVE或PVP玩法。\n由于硬件性能的限制，本服务器难以承载超过28名玩家同时在线，否则极易发生卡顿和异常。\n",
    "服务器的日常运营和硬件迭代都离不开庞大的资金支持。如果您觉得本服务器很好玩，欢迎进行赞助！\n请注意，捐助本服务器不会为您带来任何意义上的特权，请理性捐赠，量力而行，谢谢！\n",
}

for key, value in pairs(server_message_text) do
    TIMER:New(message_to_all, value, server_message_lasts_time):Start(server_message_delay, server_message_duration)
    server_message_delay = server_message_delay + 5
end

-- End of Server Message

message_to_all("Mission.lua Loaded", 3) -- Debug
