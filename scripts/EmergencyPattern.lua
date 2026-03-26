EmergencyPattern = {}

-- Light mask constants
EmergencyPattern.LIGHT_MASK_LOW_BEAM = 0
EmergencyPattern.LIGHT_MASK_HIGH_BEAM = 4
EmergencyPattern.LIGHT_MASK_RUNNING = 1

local PATTERN_NAMES = {
    "Turn Signals",
    "Turns + Beams + Brake",
    "Full Wig-Wag + Reverse",
    "Maximum Emergency"
}

function EmergencyPattern.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Lights, specializations)
end

function EmergencyPattern.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad",                 EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate",               EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw",                 EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete",               EmergencyPattern)
end

function EmergencyPattern:onLoad(savegame)
    self.spec_emergencyPattern = {
        active        = false,
        pattern       = 0,
        flashInterval = 150,
        phase         = 1,
        phaseTimer    = 0,
        lastLightMask = -1,
        actionEvents  = {}
    }
end

function EmergencyPattern:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_emergencyPattern
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            local _, toggleId  = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_EMERGENCY_PATTERN, self, EmergencyPattern.actionTogglePattern, false, true, false, true, nil)
            local _, cycleId   = self:addActionEvent(spec.actionEvents, InputAction.CYCLE_EMERGENCY_PATTERN,  self, EmergencyPattern.actionCyclePattern,  false, true, false, true, nil)
            local _, speedUpId = self:addActionEvent(spec.actionEvents, InputAction.EMERGENCY_SPEED_UP,       self, EmergencyPattern.actionSpeedUp,        false, true, false, true, nil)
            local _, speedDnId = self:addActionEvent(spec.actionEvents, InputAction.EMERGENCY_SPEED_DOWN,     self, EmergencyPattern.actionSpeedDown,       false, true, false, true, nil)

            if toggleId then
                g_inputBinding:setActionEventTextPriority(toggleId, GS_PRIO_VERY_HIGH)
                g_inputBinding:setActionEventText(toggleId, "Emergency Lights On/Off  [Shift + PgUp]")
            end
            if cycleId then
                g_inputBinding:setActionEventTextPriority(cycleId, GS_PRIO_HIGH)
                g_inputBinding:setActionEventText(cycleId, "Cycle Pattern  [Shift + PgDn]")
            end
            if speedUpId then
                g_inputBinding:setActionEventTextPriority(speedUpId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(speedUpId, "Flash Speed: Faster  [Ctrl + Shift + PgUp]")
            end
            if speedDnId then
                g_inputBinding:setActionEventTextPriority(speedDnId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(speedDnId, "Flash Speed: Slower  [Ctrl + Shift + PgDn]")
            end
        end
    end
end

function EmergencyPattern:actionTogglePattern()
    local spec = self.spec_emergencyPattern
    spec.active = not spec.active

    if not spec.active then
        EmergencyPattern.cleanUpLights(self)
    else
        spec.phase      = 1
        spec.phaseTimer = 0
    end

    EmergencyPattern.syncAttachments(self, spec.active)
end

function EmergencyPattern:actionCyclePattern()
    local spec = self.spec_emergencyPattern
    spec.pattern = (spec.pattern + 1) % 4
    EmergencyPattern.syncAttachments(self, spec.active, spec.pattern, nil)
end

function EmergencyPattern:actionSpeedUp()
    local spec = self.spec_emergencyPattern
    spec.flashInterval = math.max(50, spec.flashInterval - 50)
    EmergencyPattern.syncAttachments(self, spec.active, nil, spec.flashInterval)
end

function EmergencyPattern:actionSpeedDown()
    local spec = self.spec_emergencyPattern
    spec.flashInterval = math.min(1000, spec.flashInterval + 50)
    EmergencyPattern.syncAttachments(self, spec.active, nil, spec.flashInterval)
end

function EmergencyPattern:syncAttachments(active, pattern, speed)
    if self.getAttachedImplements then
        for _, implement in ipairs(self:getAttachedImplements()) do
            local v = implement.object
            if v and v.spec_emergencyPattern then
                local s = v.spec_emergencyPattern
                s.active = active
                if pattern ~= nil then s.pattern = pattern end
                if speed   ~= nil then s.flashInterval = speed end

                s.phase      = 1
                s.phaseTimer = 0

                if not active then
                    EmergencyPattern.cleanUpLights(v)
                end

                EmergencyPattern.syncAttachments(v, active, pattern, speed)
            end
        end
    end
end

function EmergencyPattern:onUpdate(dt)
    local spec = self.spec_emergencyPattern
    if not spec or not spec.active then return end

    spec.phaseTimer = spec.phaseTimer + dt

    local base = spec.flashInterval
    local phaseDurations = {
        base * 0.4,
        base * 0.4,
        base * 0.8,
        base * 1.2
    }

    if spec.phaseTimer >= phaseDurations[spec.phase] then
        spec.phaseTimer = 0
        spec.phase = spec.phase + 1

        if spec.phase > #phaseDurations then
            spec.phase = 1
        end

        EmergencyPattern.applyPattern(self)
    end
end

function EmergencyPattern:applyPattern()
    local spec = self.spec_emergencyPattern

    EmergencyPattern.cleanUpLights(self)

    local function setMask(mask)
        if self.setLightsTypesMask and spec.lastLightMask ~= mask then
            self:setLightsTypesMask(mask)
            spec.lastLightMask = mask
        end
    end

    if spec.pattern == 0 then
        if spec.phase == 1 or spec.phase == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
        elseif spec.phase == 3 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
        end
        -- phase 4: intentional dark pause

    elseif spec.pattern == 1 then
        if spec.phase == 1 or spec.phase == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            setMask(EmergencyPattern.LIGHT_MASK_LOW_BEAM)
        elseif spec.phase == 3 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            setMask(EmergencyPattern.LIGHT_MASK_HIGH_BEAM)
        elseif spec.phase == 4 then
            if self.setBrakeLightsVisibility then self:setBrakeLightsVisibility(true) end
        end

    elseif spec.pattern == 2 then
        if spec.phase == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            setMask(EmergencyPattern.LIGHT_MASK_LOW_BEAM)
        elseif spec.phase == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            setMask(EmergencyPattern.LIGHT_MASK_HIGH_BEAM)
        elseif spec.phase == 3 then
            if self.setBrakeLightsVisibility then self:setBrakeLightsVisibility(true) end
            if self.setReverseLightsVisibility then self:setReverseLightsVisibility(true) end
        end
        -- phase 4: intentional dark pause

    elseif spec.pattern == 3 then
        if spec.phase == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            setMask(EmergencyPattern.LIGHT_MASK_LOW_BEAM)
        elseif spec.phase == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            setMask(EmergencyPattern.LIGHT_MASK_HIGH_BEAM)
        elseif spec.phase == 3 then
            if self.setBrakeLightsVisibility then self:setBrakeLightsVisibility(true) end
            if self.setReverseLightsVisibility then self:setReverseLightsVisibility(true) end
        elseif spec.phase == 4 then
            setMask(EmergencyPattern.LIGHT_MASK_RUNNING)
        end
    end
end

function EmergencyPattern:cleanUpLights()
    self:setTurnLightState(Lights.TURNLIGHT_OFF, true)
    if self.setBrakeLightsVisibility   then self:setBrakeLightsVisibility(false) end
    if self.setReverseLightsVisibility then self:setReverseLightsVisibility(false) end
    -- Reset light mask to avoid stale beam state between patterns or on toggle off
    if self.setLightsTypesMask then self:setLightsTypesMask(EmergencyPattern.LIGHT_MASK_LOW_BEAM) end
    self.spec_emergencyPattern.lastLightMask = -1
end

function EmergencyPattern:onDelete()
    local spec = self.spec_emergencyPattern
    if spec and spec.active then
        EmergencyPattern.cleanUpLights(self)
    end
end

function EmergencyPattern:onDraw()
    local spec = self.spec_emergencyPattern
    if not spec.active or self ~= g_currentMission.controlledVehicle then return end

    setTextBold(true)

    setTextColor(1, 0, 0, 1)
    renderText(0.02, 0.95, 0.025, "EMERGENCY ACTIVE")

    setTextColor(1, 1, 0, 1)
    renderText(0.02, 0.92, 0.020, "Pattern " .. (spec.pattern + 1) .. ": " .. PATTERN_NAMES[spec.pattern + 1])

    setTextColor(1, 1, 1, 1)
    renderText(0.02, 0.89, 0.018, "Speed: " .. spec.flashInterval .. "ms")

    setTextBold(false)
end

local function init()
    local myModName = "FS25_EmergencyPattern_SK47"
    local specName  = "emergencyPattern"

    local modData = g_modManager:getModByName(myModName)
    if modData == nil then return end

    if g_specializationManager:getSpecializationByName(specName) == nil then
        g_specializationManager:addSpecialization(specName, "EmergencyPattern", modData.modDir .. "scripts/EmergencyPattern.lua", nil)
    end

    for typeName, typeDef in pairs(g_vehicleTypeManager.types) do
        if typeDef and typeName ~= "base" then
            if SpecializationUtil.hasSpecialization(Lights, typeDef.specializations) then
                if not SpecializationUtil.hasSpecialization(EmergencyPattern, typeDef.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, myModName .. "." .. specName)
                end
            end
        end
    end
end

TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, init)
