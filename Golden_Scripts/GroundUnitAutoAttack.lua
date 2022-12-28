local timer = timer
local coalition = coalition
local Group = Group
local mist = mist

local MoveToNearestEnemy = nil
local IsEnemyLeaderUnitDead = nil

function EnableAutoAttackForGroup(currentGroupName, searchRange, searchDuration, initialDelay)
    mist.scheduleFunction(MoveToNearestEnemy, { currentGroupName, searchRange, searchDuration }, timer.getTime() + initialDelay)
end

MoveToNearestEnemy = function(currentGroupName, searchRange, searchDuration)
    local currentGroup = Group.getByName(currentGroupName)
    if currentGroup == nil then return end

    local enemyCoalition = (currentGroup:getCoalition() == 1 and 2) or 1
    local enemyGroupList = coalition.getGroups(enemyCoalition, Group.Category.GROUND)

    local currentGroupPosition = mist.getLeadPos(currentGroupName)
    local nearestEnemyGroupName = nil

    for index, value in pairs(enemyGroupList) do
        local enemyGroupDistance = mist.utils.get2DDist(currentGroupPosition, mist.getLeadPos(value))
        local closestTargetDistance = searchRange
        if enemyGroupDistance <= closestTargetDistance then
            closestTargetDistance = enemyGroupDistance
            nearestEnemyGroupName = value:getName()
        end
    end

    if nearestEnemyGroupName == nil or mist.groupIsDead(nearestEnemyGroupName) == true then return end

    local enemyGroup = Group.getByName(nearestEnemyGroupName)
    if enemyGroup == nil then return end

    local enemyLeaderUnit = enemyGroup:getUnit(1)
    if enemyLeaderUnit == nil then return end

    local nearestEnemyGroupPosition = mist.getLeadPos(nearestEnemyGroupName)
    local path = {}
    path[#path + 1] = mist.ground.buildWP(currentGroupPosition, 'Rank', 15)
    path[#path + 1] = mist.ground.buildWP(nearestEnemyGroupPosition, 'Rank', 15)

    mist.goRoute(currentGroupName, path)

    mist.scheduleFunction(IsEnemyLeaderUnitDead,
        { enemyLeaderUnit, currentGroupName, nearestEnemyGroupName, searchRange, searchDuration },
        timer.getTime() + searchDuration)
end

IsEnemyLeaderUnitDead = function(enemyLeaderUnit, currentGroupName, nearestEnemyGroupName, searchRange, searchDuration)
    if enemyLeaderUnit == nil or mist.groupIsDead(currentGroupName) == true then return end

    if enemyLeaderUnit:isExist() == true then
        local currentGroupPosition = mist.getLeadPos(currentGroupName)
        local nearestEnemyGroupPosition = mist.getLeadPos(nearestEnemyGroupName)

        local path = {}
        path[#path + 1] = mist.ground.buildWP(currentGroupPosition, 'Rank', 15)
        path[#path + 1] = mist.ground.buildWP(nearestEnemyGroupPosition, 'Rank', 15)

        mist.goRoute(currentGroupName, path)

        mist.scheduleFunction(IsEnemyLeaderUnitDead,
            { enemyLeaderUnit, currentGroupName, nearestEnemyGroupName, searchRange, searchDuration },
            timer.getTime() + searchDuration)
    else
        MoveToNearestEnemy(currentGroupName, searchRange, searchDuration)
    end
end
