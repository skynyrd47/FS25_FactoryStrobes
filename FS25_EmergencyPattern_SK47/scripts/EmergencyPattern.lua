EmergencyPattern = {}

function EmergencyPattern.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Lights, specializations)
end

function EmergencyPattern.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", EmergencyPattern)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", EmergencyPattern)
end

function EmergencyPattern:onLoad(savegame)
    self.spec_emergencyPattern = {
        timer = 0,
        channel = 1,
        pattern = 0,
        active = false,
        actionEvents = {},
        flashInterval = 150,
        notificationTimer = 0,  -- Timer for status notifications
        notificationInterval = 3000  -- Show status every 3 seconds
    }
end

function EmergencyPattern:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_emergencyPattern
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            local _, toggleId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_EMERGENCY_PATTERN, self, EmergencyPattern.actionTogglePattern, false, true, false, true, nil)
            local _, cycleId = self:addActionEvent(spec.actionEvents, InputAction.CYCLE_EMERGENCY_PATTERN, self, EmergencyPattern.actionCyclePattern, false, true, false, true, nil)
            local _, speedUpId = self:addActionEvent(spec.actionEvents, InputAction.EMERGENCY_SPEED_UP, self, EmergencyPattern.actionSpeedUp, false, true, false, true, nil)
            local _, speedDownId = self:addActionEvent(spec.actionEvents, InputAction.EMERGENCY_SPEED_DOWN, self, EmergencyPattern.actionSpeedDown, false, true, false, true, nil)
            
            if toggleId then
                g_inputBinding:setActionEventTextPriority(toggleId, GS_PRIO_VERY_HIGH)
                g_inputBinding:setActionEventText(toggleId, "Toggle Emergency Lights")
            end
            if cycleId then
                g_inputBinding:setActionEventTextPriority(cycleId, GS_PRIO_HIGH)
                g_inputBinding:setActionEventText(cycleId, "Cycle Pattern")
            end
            if speedUpId then
                g_inputBinding:setActionEventTextPriority(speedUpId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(speedUpId, "Flash Speed: Faster")
            end
            if speedDownId then
                g_inputBinding:setActionEventTextPriority(speedDownId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(speedDownId, "Flash Speed: Slower")
            end
        end
    end
end

function EmergencyPattern:actionTogglePattern()
    local spec = self.spec_emergencyPattern
    spec.active = not spec.active
    if not spec.active then 
        EmergencyPattern.cleanUpLights(self)
        g_currentMission:showBlinkingWarning("Emergency Mode: OFF", 2000)
    else
        spec.timer = 0
        spec.channel = 1
        spec.notificationTimer = 0
        local patternNames = {
            "Turn Signals", 
            "Turns + Beams + Brake", 
            "Full Wig-Wag + Reverse", 
            "Maximum Emergency"
        }
        g_currentMission:showBlinkingWarning(string.format("🚨 EMERGENCY ON | Pattern %d: %s | Speed: %dms", 
            spec.pattern + 1, 
            patternNames[spec.pattern + 1], 
            spec.flashInterval), 3000)
    end
    EmergencyPattern.syncAttachments(self, spec.active)
end

function EmergencyPattern:showStatus()
    local spec = self.spec_emergencyPattern
    
    if spec.active then
        local patternNames = {
            "Turn Signals", 
            "Turns + Beams + Brake", 
            "Full Wig-Wag + Reverse", 
            "Maximum Emergency"
        }
        
        local statusMsg = string.format("🚨 EMERGENCY | Pattern %d: %s | Speed: %dms", 
            spec.pattern + 1, 
            patternNames[spec.pattern + 1], 
            spec.flashInterval)
        
        -- Show for 8 seconds
        g_currentMission:addExtraPrintText(statusMsg, 8000)
        
        -- Also print to console (press ~ to see)
        print(statusMsg)
    end
end

function EmergencyPattern:actionCyclePattern()
    local spec = self.spec_emergencyPattern
    spec.pattern = (spec.pattern + 1) % 4
    EmergencyPattern.syncAttachments(self, spec.active, spec.pattern, nil)
    if spec.active then
        local patternNames = {
            "Turn Signals", 
            "Turns + Beams + Brake", 
            "Full Wig-Wag + Reverse", 
            "Maximum Emergency"
        }
        g_currentMission:showBlinkingWarning(string.format("Pattern %d: %s", spec.pattern + 1, patternNames[spec.pattern + 1]), 2000)
    end
end

function EmergencyPattern:actionSpeedUp()
    local spec = self.spec_emergencyPattern
    spec.flashInterval = math.max(50, spec.flashInterval - 50)
    EmergencyPattern.syncAttachments(self, spec.active, nil, spec.flashInterval)
    if spec.active then
        g_currentMission:showBlinkingWarning(string.format("Speed: %dms (Faster)", spec.flashInterval), 2000)
    end
end

function EmergencyPattern:actionSpeedDown()
    local spec = self.spec_emergencyPattern
    spec.flashInterval = math.min(1000, spec.flashInterval + 50)
    EmergencyPattern.syncAttachments(self, spec.active, nil, spec.flashInterval)
    if spec.active then
        g_currentMission:showBlinkingWarning(string.format("Speed: %dms (Slower)", spec.flashInterval), 2000)
    end
end

function EmergencyPattern:updateHelpText()
    local spec = self.spec_emergencyPattern
    
    if spec.active then
        local patternNames = {
            "[1] Turn Signals", 
            "[2] Turns + Beams + Brake", 
            "[3] Full Wig-Wag + Reverse", 
            "[4] Maximum Emergency"
        }
        
        -- Update the action event text to show in F1 help
        for _, actionEvent in pairs(spec.actionEvents) do
            local actionIndex = actionEvent.actionEventId
            if g_inputBinding:getActionEventAction(actionIndex) == InputAction.TOGGLE_EMERGENCY_PATTERN then
                g_inputBinding:setActionEventText(actionIndex, string.format("🚨 EMERGENCY ACTIVE - %s - Speed: %dms", patternNames[spec.pattern + 1], spec.flashInterval))
            end
        end
    else
        -- Reset to default when off
        for _, actionEvent in pairs(spec.actionEvents) do
            local actionIndex = actionEvent.actionEventId
            if g_inputBinding:getActionEventAction(actionIndex) == InputAction.TOGGLE_EMERGENCY_PATTERN then
                g_inputBinding:setActionEventText(actionIndex, "Toggle Emergency Lights")
            end
        end
    end
end

function EmergencyPattern:syncAttachments(active, pattern, speed)
    if self.getAttachedImplements then
        local attachedImplements = self:getAttachedImplements()
        for _, implement in ipairs(attachedImplements) do
            local attachedVehicle = implement.object
            if attachedVehicle ~= nil and attachedVehicle.spec_emergencyPattern ~= nil then
                local attachedSpec = attachedVehicle.spec_emergencyPattern
                attachedSpec.active = active
                if pattern ~= nil then
                    attachedSpec.pattern = pattern
                end
                if speed ~= nil then
                    attachedSpec.flashInterval = speed
                end
                attachedSpec.timer = 0
                attachedSpec.channel = 1
                if not active then
                    EmergencyPattern.cleanUpLights(attachedVehicle)
                end
                EmergencyPattern.syncAttachments(attachedVehicle, active, pattern, speed)
            end
        end
    end
end

function EmergencyPattern:onUpdate(dt)
    local spec = self.spec_emergencyPattern
    if not spec or not spec.active then return end

    spec.timer = spec.timer + dt
    
    if spec.timer >= spec.flashInterval then
        spec.timer = 0
        spec.channel = spec.channel + 1
        if spec.channel > 3 then
            spec.channel = 1
        end
        EmergencyPattern.applyPattern(self)
    end
end

function EmergencyPattern:onUpdateTick(dt)
    local spec = self.spec_emergencyPattern
    if not spec or not spec.active then return end

    spec.timer = spec.timer + dt
    
    if spec.timer >= spec.flashInterval then
        spec.timer = 0
        spec.channel = spec.channel + 1
        if spec.channel > 3 then
            spec.channel = 1
        end
        EmergencyPattern.applyPattern(self)
    end
end

function EmergencyPattern:applyPattern()
    local spec = self.spec_emergencyPattern
    
    EmergencyPattern.cleanUpLights(self)
    
    if spec.pattern == 0 then
        if spec.channel == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
        elseif spec.channel == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
        end
        
    elseif spec.pattern == 1 then
        if spec.channel == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask)
            end
        elseif spec.channel == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask + 4)
            end
        elseif spec.channel == 3 then
            if self.setBrakeLightsVisibility then
                self:setBrakeLightsVisibility(true)
            end
        end
        
    elseif spec.pattern == 2 then
        if spec.channel == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask)
            end
        elseif spec.channel == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask + 4)
            end
        elseif spec.channel == 3 then
            if self.setBrakeLightsVisibility then
                self:setBrakeLightsVisibility(true)
            end
            if self.setReverseLightsVisibility then
                self:setReverseLightsVisibility(true)
            end
        end
        
    elseif spec.pattern == 3 then
        if spec.channel == 1 then
            self:setTurnLightState(Lights.TURNLIGHT_LEFT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask)
            end
        elseif spec.channel == 2 then
            self:setTurnLightState(Lights.TURNLIGHT_RIGHT, true)
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask + 4)
            end
        elseif spec.channel == 3 then
            if self.setBrakeLightsVisibility then
                self:setBrakeLightsVisibility(true)
            end
            if self.setReverseLightsVisibility then
                self:setReverseLightsVisibility(true)
            end
            if self.setLightsTypesMask then
                local currentMask = self:getLightsTypesMask()
                self:setLightsTypesMask(currentMask + 1)
            end
        end
    end
end

function EmergencyPattern:cleanUpLights()
    self:setTurnLightState(Lights.TURNLIGHT_OFF, true)
    
    if self.setBrakeLightsVisibility then
        self:setBrakeLightsVisibility(false)
    end
    
    if self.setReverseLightsVisibility then
        self:setReverseLightsVisibility(false)
    end
end

function EmergencyPattern:onDelete()
    local spec = self.spec_emergencyPattern
    if spec and spec.active then
        EmergencyPattern.cleanUpLights(self)
    end
end

function EmergencyPattern:onDraw()
    local spec = self.spec_emergencyPattern
    
    -- Only draw if active and in this vehicle
    if not spec.active or self ~= g_currentMission.controlledVehicle then
        return
    end
    
    local patternNames = {
        "Turn Signals", 
        "Turns + Beams + Brake", 
        "Full Wig-Wag + Reverse", 
        "Maximum Emergency"
    }
    
    -- Super simple text rendering - top left corner
    setTextBold(true)
    setTextColor(1, 0, 0, 1)
    
    -- Line 1
    renderText(0.02, 0.95, 0.025, "EMERGENCY ACTIVE")
    
    -- Line 2
    setTextColor(1, 1, 0, 1)
    renderText(0.02, 0.92, 0.020, "Pattern " .. (spec.pattern + 1) .. ": " .. patternNames[spec.pattern + 1])
    
    -- Line 3
    setTextColor(1, 1, 1, 1)
    renderText(0.02, 0.89, 0.018, "Speed: " .. spec.flashInterval .. "ms")
    
    setTextBold(false)
end

local function init()
    local myModName = "FS25_EmergencyPattern_SK47"
    local specName = "emergencyPattern"
    
    local modData = g_modManager:getModByName(myModName)
    if modData == nil then return end

    if g_specializationManager:getSpecializationByName(specName) == nil then
        g_specializationManager:addSpecialization(specName, "EmergencyPattern", modData.modDir .. "scripts/EmergencyPattern.lua", nil)
    end

    for typeName, typeDef in pairs(g_vehicleTypeManager.types) do
        if typeDef ~= nil and typeName ~= "base" then
            if SpecializationUtil.hasSpecialization(Lights, typeDef.specializations) then
                if not SpecializationUtil.hasSpecialization(EmergencyPattern, typeDef.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, myModName .. "." .. specName)
                end
            end
        end
    end
end

TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, init)
