local rcm = {}
rcm.__index = rcm

local function vec(x, y)
    return {x = x or 0, y = y or 0}
end

-- theme
rcm.theme = {
    bg = vec(0.023, 0.023),
    border = vec(0.104, 0.104),
    text = vec(1, 1),
    pink = vec(0.8039, 0.0),
    gray = vec(0.588, 0.588),
}

local FONT = 13
local LH = 16
local INDENT = 20

local wins = {}
local active = nil
local sel = nil
local curPage = nil

local function rgb(c)
    return {c.x * 255, c.y * 255, 0}
end

local function txt(x, y, str, col)
    dx9.DrawString({x, y}, rgb(col), str)
end

local function wdt(str)
    return dx9.CalcTextWidth(str)
end

local function line(y, col)
    local s = dx9.size()
    dx9.DrawLine({0, y}, {s.width, y}, rgb(col))
end

local function bracket(x, y, str, col, bracketCol)
    bracketCol = bracketCol or rcm.theme.gray
    txt(x, y, "[", bracketCol)
    txt(x + wdt("["), y, str, col)
    txt(x + wdt("[" .. str), y, "]", bracketCol)
end

local Item = {}
Item.__index = Item

function Item:new(d)
    local self = setmetatable({}, Item)
    self.name = d.Name or ""
    self.comment = d.Comment or ""
    self.typ = d.Type or "item"
    self.x = 0
    self.y = 0
    self.h = LH
    self.sel = false
    return self
end

function Item:draw(x, y, selected)
    self.x = x
    self.y = y
    self.sel = selected
    local col = selected and rcm.theme.pink or rcm.theme.text
    
    if self.typ == "toggle" then
        local val = self.val and "ON" or "OFF"
        txt(x, y, self.name .. " -> ", rcm.theme.text)
        txt(x + wdt(self.name .. " -> "), y, val, selected and rcm.theme.pink or rcm.theme.gray)
    elseif self.typ == "slider" then
        local disp = string.format("<%d/%d>", self.cur, self.max)
        txt(x, y, self.name .. " -> ", rcm.theme.text)
        txt(x + wdt(self.name .. " -> "), y, disp, selected and rcm.theme.pink or rcm.theme.gray)
    elseif self.typ == "button" then
        txt(x, y, self.name .. " ", rcm.theme.text)
        if self.comment ~= "" then
            txt(x + wdt(self.name .. " "), y, self.comment, rcm.theme.gray)
        end
    elseif self.typ == "section" and self.parent then
        local pre = self.open and "[-]" or "[+]"
        bracket(x, y, pre, rcm.theme.gray, rcm.theme.gray)
        txt(x + wdt("[" .. pre .. "] "), y, self.name, col)
    end
end

function Item:activate()
    if self.typ == "toggle" then
        self.val = not self.val
        if self.cb then self.cb(self.val) end
    elseif self.typ == "slider" then
        self.cur = self.cur + self.inc
        if self.cur > self.max then self.cur = self.min end
        if self.cb then self.cb(self.cur) end
    elseif self.typ == "button" then
        if self.cb then self.cb() end
    end
end

local Section = {}
Section.__index = Section
setmetatable(Section, {__index = Item})

function Section:new(d)
    local self = setmetatable(Item:new(d), Section)
    self.typ = "section"
    self.open = false
    self.items = {}
    self.y = 0
    self.h = LH
    return self
end

function Section:add(i)
    i.parent = self
    table.insert(self.items, i)
    return i
end

function Section:toggle(d)
    local i = {typ = "toggle", name = d.Name, val = d.Default or false, cb = d.Callback}
    setmetatable(i, Item)
    return self:add(i)
end

function Section:slider(d)
    local i = {typ = "slider", name = d.Name, cur = d.Default or 0, min = d.Min or 0, max = d.Max or 100, inc = d.Increment or 1, cb = d.Callback}
    setmetatable(i, Item)
    return self:add(i)
end

function Section:button(d)
    local i = {typ = "button", name = d.Name, comment = d.Comment or "", cb = d.Callback}
    setmetatable(i, Item)
    return self:add(i)
end

function Section:draw(x, y)
    self.x = x
    self.y = y
    local col = self.sel and rcm.theme.pink or rcm.theme.gray
    local pre = self.open and "[-]" or "[+]"
    bracket(x, y, pre, rcm.theme.gray, rcm.theme.gray)
    txt(x + wdt("[" .. pre .. "] "), y, self.name, col)
    local curY = y + LH
    if self.open then
        for _, i in ipairs(self.items) do
            if i.draw then
                i:draw(x + INDENT, curY, self.sel and i == sel)
                curY = curY + LH
            end
        end
    end
    self.h = curY - y
    return curY
end

function Section:toggleOpen()
    self.open = not self.open
end

function Section:getItems()
    if not self.open then return {} end
    return self.items
end

local Page = {}
Page.__index = Page

function Page:new(d)
    local self = setmetatable({}, Page)
    self.name = d.Name
    self.sections = {}
    return self
end

function Page:section(d)
    local s = Section:new(d)
    table.insert(self.sections, s)
    return s
end

function Page:draw(x, y)
    self.x = x
    self.y = y
    local curY = y
    txt(x, curY, self.name, rcm.theme.pink)
    curY = curY + LH + 5
    line(curY - 3, rcm.theme.pink)
    for _, s in ipairs(self.sections) do
        curY = s:draw(x, curY)
    end
    self.h = curY - y
    return curY
end

function Page:getAll()
    local items = {}
    for _, s in ipairs(self.sections) do
        table.insert(items, s)
        if s.open then
            for _, i in ipairs(s.items) do
                table.insert(items, i)
            end
        end
    end
    return items
end

local Window = {}
Window.__index = Window

function Window:new(d)
    local self = setmetatable({}, Window)
    self.name = d.Name or "rcm"
    self.pos = d.Position or vec(50, 80)
    self.toggleKey = d.ToggleKey or "F1"
    self.pages = {}
    self.vis = true
    self.w = 300
    self.curPage = nil
    self.selIdx = 1
    table.insert(wins, self)
    if not active then active = self end
    return self
end

function Window:page(d)
    local p = Page:new(d)
    table.insert(self.pages, p)
    if not self.curPage then self.curPage = p end
    return p
end

function Window:updateSel()
    if not self.curPage then return end
    local all = self.curPage:getAll()
    if self.selIdx < 1 then self.selIdx = 1 end
    if self.selIdx > #all then self.selIdx = #all end
    for _, s in ipairs(self.curPage.sections) do
        s.sel = false
        for _, i in ipairs(s.items) do i.sel = false end
    end
    if #all > 0 and self.selIdx > 0 then
        sel = all[self.selIdx]
        if sel then sel.sel = true end
    end
end

function Window:navigate(dir)
    if not self.curPage then return end
    local all = self.curPage:getAll()
    if #all == 0 then return end
    self.selIdx = dir == "up" and self.selIdx - 1 or self.selIdx + 1
    if self.selIdx < 1 then self.selIdx = #all
    elseif self.selIdx > #all then self.selIdx = 1 end
    self:updateSel()
end

function Window:activate()
    if sel and sel.typ == "section" then
        sel:toggleOpen()
        self:updateSel()
    elseif sel then
        sel:activate()
    end
end

function Window:draw()
    if not self.vis then return end
    local x, y = self.pos.x, self.pos.y
    local s = dx9.size()
    local h = math.min(400, s.height - y - 10)
    dx9.DrawFilledBox({x, y}, {x + self.w, y + h}, rgb(rcm.theme.bg))
    dx9.DrawBox({x, y}, {x + self.w, y + h}, rgb(rcm.theme.border))
    local titleX = x + (self.w / 2) - (wdt(self.name) / 2)
    txt(titleX, y + 2, self.name, rcm.theme.pink)
    line(y + LH, rcm.theme.pink)
    local curY = y + LH + 8
    if self.curPage then self.curPage:draw(x + 10, curY) end
    local tabY = y + h - LH - 5
    local tabX = x + 10
    for i, p in ipairs(self.pages) do
        local col = (p == self.curPage) and rcm.theme.pink or rcm.theme.gray
        txt(tabX, tabY, "[" .. i .. "] " .. p.name, col)
        tabX = tabX + wdt("[" .. i .. "] " .. p.name) + 10
    end
end

function Window:handle()
    local k = dx9.GetKey()
    if k == "" then return end
    if k == "[" .. self.toggleKey .. "]" then
        self.vis = not self.vis
        return
    end
    if not self.vis then return end
    if k == "[UP]" then
        self:navigate("up")
    elseif k == "[DOWN]" then
        self:navigate("down")
    elseif k == "[LEFT]" or k == "[RIGHT]" then
        if sel and sel.typ == "slider" then
            if k == "[LEFT]" then
                sel.cur = sel.cur - sel.inc
                if sel.cur < sel.min then sel.cur = sel.min end
            else
                sel.cur = sel.cur + sel.inc
                if sel.cur > sel.max then sel.cur = sel.max end
            end
            if sel.cb then sel.cb(sel.cur) end
        end
    elseif k == "[RETURN]" then
        self:activate()
    elseif k == "[TAB]" then
        for i, p in ipairs(self.pages) do
            if p == self.curPage then
                local nxt = (i % #self.pages) + 1
                self.curPage = self.pages[nxt]
                self.selIdx = 1
                self:updateSel()
                break
            end
        end
    end
end

local lib = {}

function lib:window(d)
    return Window:new(d)
end

local function render()
    for _, w in ipairs(wins) do
        w:handle()
        w:draw()
    end
end


return lib
