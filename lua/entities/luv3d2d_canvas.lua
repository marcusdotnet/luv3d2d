AddCSLuaFile()

---@class luv3d2d.CanvasEntity : ENTITY
---@field public UseFocus boolean Whether to use the focus system for this canvas
---@field public GetRenderDistance fun():number
---@field public SetRenderDistance fun(self: luv3d2d.CanvasEntity, dist: number)
---@field public GetInputDistance fun():number
---@field public SetInputDistance fun(self: luv3d2d.CanvasEntity, dist: number)
---@field public GetSize fun():number, number
---@field public GetPanel fun(): Panel
---@field private _panel Panel
---@field private _scale number The scale of the canvas
---@field private _renderDistance number The distance at which the canvas will render
---@field private _inputDistance number The distance at which the canvas will accept input
---@field private _topLeftCorner Vector   Top left corner of the canvas
---@field private _topRightCorner Vector   Top right corner of the canvas
---@field private _bottomLeftCorner Vector Bottom left corner of the canvas
---@field private _bottomRightCorner Vector Bottom right corner of the canvas
---@field private _center Vector The center of the canvas
---@field private _isDistant boolean Whether the LocalPlayer is far from the canvas
---@field private _isInputAllowed boolean Whether the LocalPlayer is close enough to the canvas to interact with it
---@field private _isLookedAt boolean Whether the LocalPlayer is looking at the canvas
---@field private _hoveredPanel? Panel The panel that the player is hovering over
---@field private _lastHoveredPanel? Panel The last panel that the player hovered over
---@field private _isFocused boolean Whether the player is focused on the canvas

---@class luv3d2d.CanvasEntity
local ENT = ENT --[[@as luv3d2d.CanvasEntity]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Luv3D2D Canvas"
ENT.Author = "maku"
ENT.Category = ""
ENT.Purpose = "Make it easy to create 3D2D panels."
ENT.Spawnable = false
if SERVER then return end
local abs, min, max, clamp, tan, rad = math.abs, math.min, math.max, math.Clamp, math.tan, math.rad
local vgui_GetHoveredPanel = vgui.GetHoveredPanel
local gui_MouseX, gui_MouseY = gui.MouseX, gui.MouseY

---Globals
local PANEL_ANG_OFFSET = Angle(0, 90, 90)       -- The angle offset for the panel (panel rendering works weirdly so we have to do this)
local FOCUS_PANEL_ANG_OFFSET = Angle(0, 180, 0) -- The angle offset to use when focusing on the panel
local FOCUS_FOV = 30                            -- The FOV to use when focusing on the canvas
local FOCUS_DISTANCE_OFFSET = 160               -- How far away from the canvas to focus
local LERP_DURATION = 0.5                       -- How long it takes to focus on the canvas
local KEYPRESS_HOOK_DELAY_S = 0.1               -- How long to wait before allowing another key press

---Add a hook to the canvas that is removed when the canvas is removed
---@param canvas luv3d2d.CanvasEntity
---@param hookName string
---@param callback fun(...): ...
local function addCanvasHook(canvas, hookName, callback)
    local hookId = "luv3d2d." .. hookName .. "." .. tostring(canvas)
    hook.Add(hookName, hookId, callback)
    hook.Add("EntityRemoved", hookId, function(ent, isFullUpdate)
        if isFullUpdate then return end
        if ent == canvas then
            hook.Remove(hookName, hookId)
            hook.Remove("EntityRemoved", hookId)
        end
    end)
end

---Check if a position is distant from another (used for checking if the player is distant from the Canvas)
---@param vecA Vector
---@param vecB Vector
---@param maxDist number
---@return boolean isDistant Whether the distance between the two vectors is greater than the max distance
---@nodiscard
local function calcIsDistant(vecA, vecB, maxDist)
    return abs(vecA.x - vecB.x) > maxDist or
            abs(vecA.y - vecB.y) > maxDist or
            abs(vecA.z - vecB.z) > maxDist
end

---Check if the player is far from the canvas
---@param canvas luv3d2d.CanvasEntity
---@return boolean isFar
---@nodiscard
local function calcIsFarFromCanvas(canvas)
    local ply = LocalPlayer()
    local eyePos = ply:EyePos()
    local maxRenderDist = canvas._renderDistance
    return calcIsDistant(eyePos, canvas:GetPos(), maxRenderDist)
end

--- Get the parents of a panel
---@param pnl Panel
---@return table
---@nodiscard
local function findAllParents(pnl)
    local parents = {}
    local parent = pnl:GetParent()
    while parent do
        table.insert(parents, parent)
        parent = parent:GetParent()
    end
    return parents
end

---@param canvas luv3d2d.CanvasEntity
local function calcCursorPosition(canvas)
    if canvas._isFocused then
        local sTl = canvas._topLeftCorner:ToScreen()
        local sTr = canvas._topRightCorner:ToScreen()
        local sBl = canvas._bottomLeftCorner:ToScreen()
        local sBr = canvas._bottomRightCorner:ToScreen()

        local minX = min(sTl.x, sTr.x, sBl.x, sBr.x)
        local maxX = max(sTl.x, sTr.x, sBl.x, sBr.x)
        local minY = min(sTl.y, sTr.y, sBl.y, sBr.y)
        local maxY = max(sTl.y, sTr.y, sBl.y, sBr.y)

        local cursorX, cursorY = input.GetCursorPos()

        if cursorX < minX or cursorX > maxX or cursorY < minY or cursorY > maxY then
            return nil
        end

        local u = (cursorX - minX) / (maxX - minX)
        local v = (cursorY - minY) / (maxY - minY)

        local w, h = canvas:GetSize()
        return u * w, v * h
    else
        local ply = LocalPlayer()
        local eye = ply:EyePos()
        local aim = ply:GetAimVector()
        local tl = canvas._topLeftCorner
        local tr = canvas._topRightCorner
        local bl = canvas._bottomLeftCorner

        local right = tr - tl
        local down = bl - tl
        local normal = right:Cross(down):GetNormalized()
        local d = normal:Dot(tl)
        local denom = normal:Dot(aim)
        if denom == 0 then return end
        local t = (d - normal:Dot(eye)) / denom
        if t < 0 then return end
        local hit = eye + aim * t
        local rel = hit - tl
        local u = rel:Dot(right) / right:Dot(right)
        local v = rel:Dot(down) / down:Dot(down)
        if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
        local w, h = canvas:GetSize()
        return u * w, h - (v * h)
    end
end

--- Get the absolute position of a panel
---@param panel Panel
---@return number x
---@return number y
---@nodiscard
local function calcAbsolutePanelPos(panel)
    local x, y = panel:GetPos()
    local parents = findAllParents(panel)

    for _, parent in ipairs(parents) do
        local px, py = parent:GetPos()
        x = x + px
        y = y + py
    end

    return x, y
end

---Initialize
function ENT:Initialize()
    -- Set up physics, rendering
    self:PhysicsInit(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetRenderMode(EF_NODRAW)

    -- Key presses
    local nextKeyPressTime = CurTime()
    addCanvasHook(self, "KeyPress", function(_, key)
        if key == IN_ATTACK then -- Mouse press (unfocused)
            key = input.IsKeyDown(KEY_LSHIFT) and MOUSE_RIGHT or MOUSE_LEFT
            local time = CurTime()
            if time >= nextKeyPressTime then
                nextKeyPressTime = time + KEYPRESS_HOOK_DELAY_S
            else
                return
            end

            if not self._hoveredPanel or not self._hoveredPanel:IsHovered() then return end
            self:EmitPanelEvent(self._hoveredPanel, "OnMousePressed", key)
            self:EmitPanelEvent(self._hoveredPanel, "DoClick")
        elseif self.UseFocus and key == IN_USE and self._isInputAllowed then
            self:SetFocused(not self._isFocused)
        end
    end)

    -- Key releases
    addCanvasHook(self, "KeyRelease", function(_, key)
        if key == IN_ATTACK then -- Mouse release (unfocused)
            key = input.IsKeyDown(KEY_LSHIFT) and MOUSE_RIGHT or MOUSE_LEFT
            if not self._hoveredPanel or not self._hoveredPanel:IsHovered() then return end
            self:EmitPanelEvent(self._hoveredPanel, "OnMouseReleased", key)
        end
    end)

    -- Mouse press (while focused)
    addCanvasHook(self, "GUIMousePressed", function(key)
        if not self._hoveredPanel or not self._hoveredPanel:IsHovered() then return end
        self:EmitPanelEvent(self._hoveredPanel, "OnMousePressed", key)
        self:EmitPanelEvent(self._hoveredPanel, "DoClick")
    end)

    -- Mouse release (while focused)
    addCanvasHook(self, "GUIMouseReleased", function(key)
        if not self._hoveredPanel or not self._hoveredPanel:IsHovered() then return end
        self:EmitPanelEvent(self._hoveredPanel, "OnMouseReleased", key)
    end)

    ---@param ply Player
    ---@param viewOrigin Vector
    ---@param viewAng Angle
    ---@param fov number
    addCanvasHook(self, "CalcView", function(ply, viewOrigin, viewAng, fov)
        if not self._isFocused then
            if vgui.CursorVisible() then
                gui.EnableScreenClicker(false)
            end
            self._focusStartTime = nil
            self._originalFov = nil
            return
        end

        gui.EnableScreenClicker(true)
        local curTime = CurTime()

        -- First-time setup
        if not self._focusStartTime then
            self._focusStartTime = curTime
            self._originalFov = fov
            self._originalViewAng = viewAng

            -- Get true panel parameters
            local w, h = self:GetSize()
            local scale = self._scale
            self._truePanelAng = self:LocalToWorldAngles(FOCUS_PANEL_ANG_OFFSET)

            -- Calculate true center point accounting for panel rotation
            local panelCenterOffset = Vector(0, (w / 2) * scale, (h / 2) * scale)
            self._truePanelCenter = self:LocalToWorld(panelCenterOffset)

            -- Calculate optimal focus distance
            local panelHeight = h * scale
            self._focusDistance = panelHeight / (2 * tan(rad(FOCUS_FOV / 2)))
            self._focusDistance = max(self._focusDistance, FOCUS_DISTANCE_OFFSET)
        end

        local progress = clamp((curTime - self._focusStartTime) / LERP_DURATION, 0, 1)

        -- Calculate target view parameters
        local targetAng = Angle(self._truePanelAng.p, self._truePanelAng.y, 0) -- Lock roll to 0
        local targetPos = self._truePanelCenter - targetAng:Forward() * self._focusDistance

        return {
            fov = Lerp(progress, self._originalFov, FOCUS_FOV),
            origin = LerpVector(progress, viewOrigin, targetPos),
            angles = LerpAngle(progress, self._originalViewAng, targetAng)
        }
    end)

    ---Don't allow the player to move when the canvas is focused
    ---@param userCmd CUserCmd
    addCanvasHook(self, "CreateMove", function(userCmd)
        if not self._isFocused then return end
        userCmd:SetForwardMove(0)
        userCmd:SetSideMove(0)
        userCmd:SetUpMove(0)
        userCmd:SetImpulse(0)
        userCmd:SetButtons(0)

        local mouseScrollOffset = ((input.WasMousePressed(MOUSE_WHEEL_UP) and 1) or
            (input.WasMousePressed(MOUSE_WHEEL_DOWN) and -1)) or nil
        if isnumber(mouseScrollOffset) then
            for _, pnl in pairs(self._panel:GetChildren()) do
                if pnl:IsVisible() then
                    self:EmitPanelEvent(pnl, "OnMouseWheeled", mouseScrollOffset)
                end
            end
        end
    end)

    -- Hiding players when focused
    addCanvasHook(self, "PrePlayerDraw", function(_, __)
        if not self._isFocused then return end
        return true
    end)

    -- Hiding viewmodels when focused
    addCanvasHook(self, "PreDrawViewModel", function(_, __, ___, ____)
        if not self._isFocused then return end
        return true
    end)

    -- Initial values...
    self:SetInputDistance(100)
    self:SetRenderDistance(200)
    self:SetupPanel(150, 150, 0.1, false)
end

---Check if the canvas is focused
---@return boolean isFocused Whether the canvas is focused
function ENT:IsFocused()
    return self._isFocused
end

---Set the focus of the canvas
---@param focused boolean Whether the canvas is focused
function ENT:SetFocused(focused)
    self._isFocused = focused
    self._panel:SetKeyboardInputEnabled(focused)
end

---Get the render distance of the canvas
function ENT:GetRenderDistance()
    return self._renderDistance
end

---Set the render distance of the canvas
---@param dist number
function ENT:SetRenderDistance(dist)
    self._renderDistance = dist
end

---Get the distance at which the canvas will accept input
---@return number
---@nodiscard
function ENT:GetInputDistance()
    return self._inputDistance
end

---Set the distance at which the canvas will accept input
---@param dist number
function ENT:SetInputDistance(dist)
    self._inputDistance = dist
end

---Get the size of the canvas
---@return number|nil x
---@return number|nil y
---@nodiscard
function ENT:GetSize()
    if not self._panel then return nil, nil end
    return self._panel:GetSize()
end

---Get the panel of the canvas
---@return Panel panel The panel of the canvas
function ENT:GetPanel()
    return self._panel
end

---Create(or re-create) the panel for the canvas
---@param w number The width of the canvas
---@param h number The height of the canvas
---@param scale? number = 10 How much to scale the canvas by
---@param useFocus? boolean = false Whether to use the focus system
function ENT:SetupPanel(w, h, scale, useFocus)
    if IsValid(self._panel) then
        self._panel:Remove()
    end

    self._panel = vgui.Create("DPanel")
    self._panel:SetSize(w, h)
    self._panel.OnKeyCodePressed = function(_, keyCode)
        if keyCode == KEY_E or keyCode == KEY_ESCAPE then
            self:SetFocused(false)
        end
    end

    self.UseFocus = useFocus or false
    self._scale = (scale or 10) / 10
end

---Get the player's cursor position relative to the canvas
---@return number|nil x, number|nil y
---@nodiscard
function ENT:GetCursorPosition()
    return self._cursorX, self._cursorY
end

---Get the top-most hovered panel under the cursor
---@param canvas luv3d2d.CanvasEntity
---@return Panel|nil
local function getHoveredPanel(canvas)
    local cursorX, cursorY = canvas._cursorX, canvas._cursorY
    if not cursorX or not cursorY then return nil end

    local function findHovered(pnl)
        if not pnl:IsVisible() or not pnl:IsMouseInputEnabled() then return nil end

        -- Get panel's absolute position and size
        local x, y = calcAbsolutePanelPos(pnl)
        local w, h = pnl:GetSize()

        -- Check if cursor is within panel bounds
        if cursorX < x or cursorX > x + w or cursorY < y or cursorY > y + h then
            return nil
        end

        -- Check children in reverse order (top-most first)
        local children = pnl:GetChildren()
        for i = #children, 1, -1 do
            local child = children[i]
            local hoveredChild = findHovered(child)
            if hoveredChild then return hoveredChild end
        end

        -- Return this panel if no children are hovered
        return pnl
    end

    return findHovered(canvas._panel)
end

---Get the hovered panel under the cursor
---@return Panel hoveredPanel
function ENT:GetHoveredPanel()
    return self._hoveredPanel
end

---Send a panel event to the canvas
---@param panel Panel
---@param event string
---@param ... unknown
---@return boolean
function ENT:EmitPanelEvent(panel, event, ...)
    if not IsValid(panel) or not panel:IsVisible() then
        return false
    end

    if panel[event] then
        panel[event](panel, ...)
        return true
    end
    return false
end

---Draw
function ENT:Draw()
    local panel = self._panel
    if not IsValid(panel) or not self._topLeftCorner then return end
    if not panel:IsVisible() then
        panel:Show()
    end

    local panelPos = self._panelVector
    local ang = self._panelAng
    local scale = self._scale

    cam.Start3D2D(panelPos, ang, scale)
    panel:SetPaintedManually(true)
    panel:PaintManual(true)
    cam.End3D2D()
end

---Cleanup
function ENT:OnRemove()
    if IsValid(self._panel) then
        self._panel:Remove()
    end

    vgui.GetHoveredPanel = vgui_GetHoveredPanel -- Reset the hovered panel getter
end

---All states are kept up to date here
function ENT:Think()
    local panelW, panelH = self:GetSize()
    local scale = self._scale
    panelW = panelW * scale
    panelH = panelH * scale

    -- Key positions
    self._topLeftCorner = self:LocalToWorld(Vector(0, 0, 0))
    self._topRightCorner = self:LocalToWorld(Vector(0, panelW, 0))
    self._bottomLeftCorner = self:LocalToWorld(Vector(0, 0, panelH))
    self._bottomRightCorner = self:LocalToWorld(Vector(0, panelW, panelH))
    self._center = self:LocalToWorld(Vector(0, panelW * 0.5, panelH * 0.5))
    self._panelVector = self._topLeftCorner + (self:GetUp() * panelH)
    self._panelAng = self:LocalToWorldAngles(PANEL_ANG_OFFSET)

    -- Update input state
    self._isDistant = calcIsFarFromCanvas(self)
    local cursorX, cursorY
    if self._isDistant then
        -- Don't render if too far
        if IsValid(self._panel) then
            self._panel:Hide()
        end
    else
        if IsValid(self._panel) and not self._panel:IsVisible() then
            self._panel:Show() -- Show if not too far
        end

        cursorX, cursorY = calcCursorPosition(self)
    end
    self._cursorX = cursorX
    self._cursorY = cursorY

    local wasLookedAt = self._isLookedAt
    self._isLookedAt = self._cursorX != nil
    self._isInputAllowed = not self._isDistant
            and self._isLookedAt
            and not calcIsDistant(LocalPlayer():EyePos(), self:GetPos(), self._inputDistance)

    self._hoveredPanel = self._isInputAllowed and getHoveredPanel(self) or nil

    if self._isLookedAt then
        -- Hover over a new panel
        if self._hoveredPanel != self._lastHoveredPanel then
            -- Exit old panel
            if IsValid(self._lastHoveredPanel) then
                self:EmitPanelEvent(self._lastHoveredPanel, "OnCursorExited")
            end

            -- Enter new panel
            if IsValid(self._hoveredPanel) then
                self:EmitPanelEvent(self._hoveredPanel, "OnCursorEntered")
                vgui.GetHoveredPanel = function() return self._hoveredPanel end
            end

            -- Update last hovered panel
            self._lastHoveredPanel = self._hoveredPanel
        end

        function gui.MouseX()
            return (cursorX or 0) / scale
        end

        function gui.MouseY()
            return (cursorY or 0) / scale
        end
    elseif wasLookedAt then -- Was looked at but no longer
        -- Force clear all states when losing focus
        if IsValid(self._lastHoveredPanel) then
            self:EmitPanelEvent(self._lastHoveredPanel, "OnCursorExited")
            self:EmitPanelEvent(self._lastHoveredPanel, "OnMouseReleased", MOUSE_LEFT)
            self:EmitPanelEvent(self._lastHoveredPanel, "OnMouseReleased", MOUSE_RIGHT)
        end
        self._lastHoveredPanel = nil
        vgui.GetHoveredPanel = vgui_GetHoveredPanel

        gui.MouseX = gui_MouseX
        gui.MouseY = gui_MouseY
    end
end
