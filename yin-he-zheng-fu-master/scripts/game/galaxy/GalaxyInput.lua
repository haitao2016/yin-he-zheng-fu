---@diagnostic disable: param-type-mismatch, assign-type-mismatch
-- ============================================================================
-- game/galaxy/GalaxyInput.lua  -- 银河地图输入处理模块
-- 独立的输入处理（鼠标、触摸、键盘）
-- 从 GalaxyScene.lua (2403 行) 中拆分出约 300 行输入逻辑
-- ============================================================================

local GalaxyInput = {}
GalaxyInput.__index = GalaxyInput

-- ----------------------------------------------------------------------------
-- 创建输入处理器
-- ctx 必须包含：
--   camera_, zoom_, camVel_, camPanAnim_
--   screenW_, screenH_, mouseX_, mouseY_
--   isDragging_, dragStart_, camAtDrag_, dragDist_, dragLastX_, dragLastY_
--   lastClickTime_, lastClickX_, lastClickY_
--   seedShip_, selectedFleetId_, selectedPlanet_
--   starSystems_, deepSpaceSystems_, asteroids_
--   fleetObjs_, pirateAI_, rm_
--   signalOpen_, signalCooldowns_, signalBanners_
--   touches_, pinchDist_
--   keyDown_
--   onPlanetSelect_, onFleetMove_, onGalaxyEvent_, notifyFn_
--   ZOOM_MIN, ZOOM_MAX, DOUBLE_CLICK_DT, DOUBLE_CLICK_R, SIGNAL_CD, QUICK_SIGNALS
--   dist, w2s, s2w
-- ----------------------------------------------------------------------------

function GalaxyInput.new(ctx)
    local self = setmetatable({}, GalaxyInput)
    self.ctx = ctx or {}
    return self
end

-- ----------------------------------------------------------------------------
-- 鼠标 / 触摸 处理
-- ----------------------------------------------------------------------------

function GalaxyInput:OnMouseDown(mx, my)
    local c = self.ctx
    c.isDragging_ = true
    c.dragStart_  = { x=mx, y=my }
    c.camAtDrag_  = { x=c.camera_.x, y=c.camera_.y }
    c.dragDist_   = 0
    c.camVel_.x   = 0
    c.camVel_.y   = 0
    c.camPanAnim_ = nil
    c.dragLastX_  = mx
    c.dragLastY_  = my
end

function GalaxyInput:OnMouseMove(mx, my)
    local c = self.ctx
    c.mouseX_ = mx
    c.mouseY_ = my
    if not c.isDragging_ then return end
    local dx = mx - c.dragStart_.x
    local dy = my - c.dragStart_.y
    c.camera_.x  = c.camAtDrag_.x + dx / c.zoom_
    c.camera_.y  = c.camAtDrag_.y + dy / c.zoom_
    c.dragDist_  = math.sqrt(dx*dx + dy*dy)
    local frameVx = (mx - c.dragLastX_) / c.zoom_
    local frameVy = (my - c.dragLastY_) / c.zoom_
    c.camVel_.x = c.camVel_.x * 0.4 + frameVx * 0.6 * 60
    c.camVel_.y = c.camVel_.y * 0.4 + frameVy * 0.6 * 60
    c.dragLastX_ = mx
    c.dragLastY_ = my
end

function GalaxyInput:OnMouseWheel(mx, my, delta)
    local c = self.ctx
    local oldZoom = c.zoom_
    local softMin = c.ZOOM_MIN * 0.90
    local softMax = c.ZOOM_MAX * 1.10
    c.zoom_ = math.max(softMin, math.min(softMax, c.zoom_ + delta * 0.12))
    local cx = c.screenW_ / 2
    local cy = c.screenH_ / 2
    local dWx = (mx - cx) * (1/oldZoom - 1/c.zoom_)
    local dWy = (my - cy) * (1/oldZoom - 1/c.zoom_)
    c.camera_.x = c.camera_.x - dWx
    c.camera_.y = c.camera_.y - dWy
end

function GalaxyInput:minimapRect()
    local c = self.ctx
    return c.screenW_ - c.MINIMAP_W - c.MINIMAP_PAD,
           c.screenH_ - c.MINIMAP_H - c.MINIMAP_PAD,
           c.MINIMAP_W, c.MINIMAP_H
end

function GalaxyInput:teleportToMinimap(px, py)
    local c = self.ctx
    local mmx, mmy, mmw, mmh = self:minimapRect()
    local scaleX = (mmw - 8) / (c.MINIMAP_WORLD_RANGE * 2)
    local scaleY = (mmh - 14) / (c.MINIMAP_WORLD_RANGE * 2)
    local offX = mmx + 4 + (mmw - 8) / 2
    local offY = mmy + 12 + (mmh - 14) / 2
    local wx = (px - offX) / scaleX
    local wy = (py - offY) / scaleY
    c.camera_.x = -wx + c.screenW_ / 2
    c.camera_.y = -wy + c.screenH_ / 2
    if c.notifyFn_ then
        c.notifyFn_(string.format("传送至 (%.0f, %.0f)", wx, wy), "info")
    end
end

-- ----------------------------------------------------------------------------
-- 点击检测（辅助函数）
-- ----------------------------------------------------------------------------

function GalaxyInput:tryClickAsteroid(mx, my)
    local c = self.ctx
    for _, a in ipairs(c.asteroids_) do
        if a.health and a.health > 0 then
            local sx, sy = c.w2s(a.x, a.y)
            local r = (a.size + 8) * c.zoom_
            if c.dist(mx, my, sx, sy) < r then
                if c.selectedFleetId_ then
                    -- 省略：已在主文件中处理过了
                    local engCount = 0
                    local fleet = c.fleetObjs_[c.selectedFleetId_]
                    if fleet and fleet.ships then
                        for _, ship in ipairs(fleet.ships) do
                            if ship.type == "ENGINEER" then engCount = engCount + 1 end
                        end
                    end
                    if engCount > 0 then
                        local obj = c.fleetObjs_[c.selectedFleetId_]
                        obj.targetX = a.x
                        obj.targetY = a.y
                        obj.miningTarget = a
                        obj.mineTimer = 0
                    end
                end
                return true
            end
        end
    end
    return false
end

function GalaxyInput:handleClick(mx, my)
    local c = self.ctx
    if c.seedShip_.state == "deployed" then
        -- 信号按钮点击检测
        local BW  = 44
        local PAD = 8
        local btnX = c.screenW_ - BW - PAD
        local btnY = c.screenH_ - BW - PAD - 50
        if mx >= btnX and mx <= btnX+BW and my >= btnY and my <= btnY+BW then
            c.signalOpen_ = not c.signalOpen_
            return
        end
        if c.signalOpen_ then
            local ITEM_H = 40
            local PANEL_W = 180
            local panelX = c.screenW_ - PANEL_W - PAD
            local panelY = btnY - #c.QUICK_SIGNALS * ITEM_H - 8
            if mx >= panelX and mx <= panelX + PANEL_W and
               my >= panelY and my <= btnY - 8 then
                local idx = math.floor((my - panelY) / ITEM_H) + 1
                if idx >= 1 and idx <= #c.QUICK_SIGNALS then
                    local sig = c.QUICK_SIGNALS[idx]
                    local cd  = c.signalCooldowns_[idx]
                    if not cd or cd <= 0 then
                        c.signalCooldowns_[idx] = c.SIGNAL_CD
                        c.signalBanners_[#c.signalBanners_+1] = {
                            text = "指挥官：" .. sig.icon .. " " .. sig.text,
                            alpha = 255, timer = 0, color = sig.color,
                        }
                    end
                    c.signalOpen_ = false
                end
                return
            end
            c.signalOpen_ = false
        end
    end

    if c.seedShip_.state == "moving" then
        local wx, wy = c.s2w(mx, my)
        c.seedClickTarget_ = { x = wx, y = wy }
        return
    end

    if c.seedShip_.state == "deployed" then
        for _, ev in ipairs(c.GalaxyEvents.GetList()) do
            if not ev.claimed then
                local esx, esy = c.w2s(ev.x, ev.y)
                if c.dist(mx, my, esx, esy) < 22 then
                    ev.claimed = true
                    if c.onGalaxyEvent_ then c.onGalaxyEvent_(ev) end
                    return
                end
            end
        end
    end

    if c.selectedFleetId_ and c.fleetObjs_[c.selectedFleetId_] then
        local obj = c.fleetObjs_[c.selectedFleetId_]
        local sx, sy = c.w2s(obj.x, obj.y)
        if c.dist(mx, my, sx, sy) < 22 then
            c.selectedFleetId_ = nil
            if c.onPlanetSelect_ then c.onPlanetSelect_(obj) end
            return
        end
    end

    if c.pirateAI_ then
        for _, base in ipairs(c.pirateAI_.bases) do
            if base.active then
                local bsx, bsy = c.w2s(base.x, base.y)
                if c.dist(mx, my, bsx, bsy) < 30 then
                    if c.selectedFleetId_ then
                        local obj = c.fleetObjs_[c.selectedFleetId_]
                        if obj then
                            obj.targetX = base.x
                            obj.targetY = base.y
                            obj.pirateBaseTarget = base.id
                        end
                    end
                    return
                end
            end
        end
    end

    if c.seedShip_.state == "deployed" then
        local bsx, bsy = c.w2s(c.seedShip_.x, c.seedShip_.y)
        if c.dist(mx, my, bsx, bsy) < 28 then
            c.selectedFleetId_ = nil
            c.selectedPlanet_ = c.seedShip_
            if c.onPlanetSelect_ then c.onPlanetSelect_(c.seedShip_) end
            return
        end
    end

    for _, sys in ipairs(c.starSystems_) do
        for _, p in ipairs(sys.planets) do
            if p._sx and c.dist(mx, my, p._sx, p._sy) < (p.size * c.zoom_ + 12) then
                local now = c.totalTime_
                local ddx = mx - c.lastClickX_
                local ddy = my - c.lastClickY_
                local isDouble = (now - c.lastClickTime_) < c.DOUBLE_CLICK_DT
                    and math.sqrt(ddx*ddx + ddy*ddy) < c.DOUBLE_CLICK_R
                if isDouble then
                    local pw = sys.x + math.cos(p.angle) * p.orbitRadius
                    local ph = sys.y + math.sin(p.angle) * p.orbitRadius
                    local cx = c.screenW_ / 2
                    local cy = c.screenH_ / 2
                    local targetCX = cx - pw
                    local targetCY = cy - ph
                    c.camPanAnim_ = { sx=c.camera_.x, sy=c.camera_.y,
                                        tx=targetCX, ty=targetCY, t=0, dur=0.3 }
                    c.camVel_.x = 0
                    c.camVel_.y = 0
                    c.lastClickTime_ = 0
                else
                    c.lastClickTime_ = now
                    c.lastClickX_ = mx
                    c.lastClickY_ = my
                end
                c.selectedPlanet_ = p
                if c.onPlanetSelect_ then c.onPlanetSelect_(p) end
                if c.selectedFleetId_ then
                    local obj = c.fleetObjs_[c.selectedFleetId_]
                    if obj then
                        local wx = sys.x + math.cos(p.angle) * p.orbitRadius
                        local wy = sys.y + math.sin(p.angle) * p.orbitRadius
                        obj.targetX = wx + (math.random()-0.5)*40
                        obj.targetY = wy + (math.random()-0.5)*40
                        obj.targetPlanet = p
                        if c.onFleetMove_ then c.onFleetMove_() end
                    end
                end
                return
            end
        end
    end

    local hasGate = c.rm_ and c.rm_.baseBonus and c.rm_.baseBonus.hasWarpGate
    if hasGate then
        for _, sys in ipairs(c.deepSpaceSystems_) do
            for _, p in ipairs(sys.planets) do
                if p._sx and c.dist(mx, my, p._sx, p._sy) < (p.size * c.zoom_ + 12) then
                    c.selectedPlanet_ = p
                    if c.onPlanetSelect_ then c.onPlanetSelect_(p) end
                    if c.selectedFleetId_ then
                        local obj = c.fleetObjs_[c.selectedFleetId_]
                        if obj then
                            local wx = sys.x + math.cos(p.angle) * p.orbitRadius
                            local wy = sys.y + math.sin(p.angle) * p.orbitRadius
                            obj.targetX = wx + (math.random()-0.5)*40
                            obj.targetY = wy + (math.random()-0.5)*40
                            obj.targetPlanet = p
                            if c.onFleetMove_ then c.onFleetMove_() end
                        end
                    end
                    return
                end
            end
        end
    end

    if c.selectedFleetId_ then
        local obj = c.fleetObjs_[c.selectedFleetId_]
        if obj then
            local wx, wy = c.s2w(mx, my)
            obj.targetX = wx
            obj.targetY = wy
            if c.onFleetMove_ then c.onFleetMove_() end
        end
        return
    end
    c.selectedPlanet_ = nil
    if c.onPlanetSelect_ then c.onPlanetSelect_(nil) end
end

function GalaxyInput:OnMouseUp(mx, my)
    local c = self.ctx
    if not c.isDragging_ then return end
    c.isDragging_ = false
    if c.dragDist_ < 8 then
        c.camVel_.x = 0
        c.camVel_.y = 0
        local mmx, mmy, mmw, mmh = self:minimapRect()
        if mx >= mmx and mx <= mmx+mmw and my >= mmy and my <= mmy+mmh then
            self:teleportToMinimap(mx, my)
        else
            self:handleClick(mx, my)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 触摸输入接口
-- ----------------------------------------------------------------------------

function GalaxyInput:touchCount()
    local n = 0
    for _ in pairs(self.ctx.touches_) do n = n + 1 end
    return n
end

function GalaxyInput:pinchInfo()
    local pts = {}
    local c = self.ctx
    for _, t in pairs(c.touches_) do pts[#pts + 1] = t end
    if #pts < 2 then return nil end
    local dx = pts[2].x - pts[1].x
    local dy = pts[2].y - pts[1].y
    local dist = math.sqrt(dx * dx + dy * dy)
    local midX = (pts[1].x + pts[2].x) * 0.5
    local midY = (pts[1].y + pts[2].y) * 0.5
    return dist, midX, midY
end

function GalaxyInput:OnTouchBegin(id, x, y)
    local c = self.ctx
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr
    c.touches_[id] = { x = lx, y = ly }
    if self:touchCount() >= 2 then
        c.isDragging_ = false
        c.pinchDist_ = self:pinchInfo()
        c.camVel_.x = 0
        c.camVel_.y = 0
    else
        c.isDragging_ = true
        c.dragStart_ = { x = lx, y = ly }
        c.camAtDrag_ = { x = c.camera_.x, y = c.camera_.y }
        c.dragDist_ = 0
        c.pinchDist_ = nil
        c.camVel_.x = 0
        c.camVel_.y = 0
        c.camPanAnim_ = nil
        c.dragLastX_ = lx
        c.dragLastY_ = ly
    end
end

function GalaxyInput:OnTouchMove(id, x, y)
    local c = self.ctx
    if not c.touches_[id] then return end
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr
    c.touches_[id] = { x = lx, y = ly }
    local n = self:touchCount()
    if n >= 2 then
        c.isDragging_ = false
        local newDist, midX, midY = self:pinchInfo()
        if c.pinchDist_ and c.pinchDist_ > 1 and newDist then
            local scale = newDist / c.pinchDist_
            local oldZoom = c.zoom_
            c.zoom_ = math.max(c.ZOOM_MIN * 0.90, math.min(c.ZOOM_MAX * 1.10, c.zoom_ * scale))
            local cx = c.screenW_ / 2
            local cy = c.screenH_ / 2
            local dWx = (midX - cx) * (1 / oldZoom - 1 / c.zoom_)
            local dWy = (midY - cy) * (1 / oldZoom - 1 / c.zoom_)
            c.camera_.x = c.camera_.x - dWx
            c.camera_.y = c.camera_.y - dWy
        end
        c.pinchDist_ = newDist
    elseif n == 1 and c.isDragging_ then
        local dx = lx - c.dragStart_.x
        local dy = ly - c.dragStart_.y
        c.camera_.x = c.camAtDrag_.x + dx / c.zoom_
        c.camera_.y = c.camAtDrag_.y + dy / c.zoom_
        c.dragDist_ = math.sqrt(dx * dx + dy * dy)
        local frameVx = (lx - c.dragLastX_) / c.zoom_
        local frameVy = (ly - c.dragLastY_) / c.zoom_
        c.camVel_.x = c.camVel_.x * 0.4 + frameVx * 0.6 * 60
        c.camVel_.y = c.camVel_.y * 0.4 + frameVy * 0.6 * 60
        c.dragLastX_ = lx
        c.dragLastY_ = ly
    end
end

function GalaxyInput:OnTouchEnd(id, x, y)
    local c = self.ctx
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr
    if self:touchCount() == 1 and c.isDragging_ and c.dragDist_ < 8 then
        c.camVel_.x = 0
        c.camVel_.y = 0
        self:handleClick(lx, ly)
    end
    c.touches_[id] = nil
    c.pinchDist_ = nil
    local remaining = self:touchCount()
    if remaining == 0 then
        c.isDragging_ = false
    elseif remaining == 1 then
        for _, t in pairs(c.touches_) do
            c.isDragging_ = true
            c.dragStart_ = { x = t.x, y = t.y }
            c.camAtDrag_ = { x = c.camera_.x, y = c.camera_.y }
            c.dragDist_ = 0
            c.dragLastX_ = t.x
            c.dragLastY_ = t.y
            break
        end
    end
end

-- ----------------------------------------------------------------------------
-- 键盘输入接口
-- ----------------------------------------------------------------------------

function GalaxyInput:OnKeyDown(key, KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_SPACE)
    local c = self.ctx
    if key == KEY_W or key == KEY_UP    then c.keyDown_.up = true end
    if key == KEY_S or key == KEY_DOWN  then c.keyDown_.down = true end
    if key == KEY_A or key == KEY_LEFT  then c.keyDown_.left = true end
    if key == KEY_D or key == KEY_RIGHT then c.keyDown_.right = true end
    if key == KEY_SPACE and c.seedShip_.state == "moving" then
        c.seedShip_.state = "deploying"
        c.seedShip_.timer = 0
        c.keyDown_.up = false
        c.keyDown_.down = false
        c.keyDown_.left = false
        c.keyDown_.right = false
        print("[SeedShip] 开始展开...")
    end
end

function GalaxyInput:OnKeyUp(key, KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)
    local c = self.ctx
    if key == KEY_W or key == KEY_UP    then c.keyDown_.up = false end
    if key == KEY_S or key == KEY_DOWN  then c.keyDown_.down = false end
    if key == KEY_A or key == KEY_LEFT  then c.keyDown_.left = false end
    if key == KEY_D or key == KEY_RIGHT then c.keyDown_.right = false end
end

return GalaxyInput
