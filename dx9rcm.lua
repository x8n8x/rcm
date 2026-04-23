-- rcm for dx9ware
local lib = {}
local d = dx9
local theme = {
    bg = {0.023,0.023,0.023},
    dark = {0.104,0.104,0.104},
    txt = {1,1,1},
    pink = {0.8039,0.0,0.4980},
    gray = {0.588,0.588,0.588},
}

local function rgb(t)
    return {t[1]*255, t[2]*255, 0}
end

local function txt(x,y,s,c,center)
    if center then
        local w = d.CalcTextWidth(s)
        x = x - w/2
    end
    d.DrawString({x,y}, rgb(c), s)
end

local function rect(x,y,w,h,c)
    d.DrawFilledBox({x,y}, {x+w,y+h}, rgb(c))
end

local function line(y,c)
    local s = d.size()
    d.DrawLine({0,y}, {s.width,y}, rgb(c))
end

function lib:Window(p)
    local w = {
        vis = true,
        pos = p.Position or {x=50,y=60},
        selIdx = 1,
        pages = {},
        open = {},
        last = 0,
        cd = 0.12,
        key = p.ToggleKey or "F1",
        name = p.Name or "rcm",
        ww = 280,
    }
    
    function w:getKey()
        local k = d.GetKey()
        if k and k ~= "" then return k end
        return nil
    end
    
    function w:total()
        local c = 0
        for i,p in ipairs(self.pages) do
            c = c + 1
            if self.open[i] then
                for _,s in ipairs(p.secs) do
                    c = c + #s.items
                end
            end
        end
        return c
    end
    
    function w:cur()
        local n = 0
        for i,p in ipairs(self.pages) do
            n = n + 1
            if n == self.selIdx then return {type="page", idx=i} end
            if self.open[i] then
                for si,s in ipairs(p.secs) do
                    for ii,it in ipairs(s.items) do
                        n = n + 1
                        if n == self.selIdx then 
                            return {type="item", pIdx=i, sIdx=si, iIdx=ii, data=it}
                        end
                    end
                end
            end
        end
        return nil
    end
    
    function w:draw()
        if not self.vis then return end
        local x,y = self.pos.x, self.pos.y
        local h = 19
        for i,p in ipairs(self.pages) do
            h = h + 17
            if self.open[i] then
                for _,s in ipairs(p.secs) do
                    h = h + 17 + (#s.items * 17)
                end
            end
        end
        h = h + 4
        
        rect(x,y,self.ww,h,theme.bg)
        rect(x+1,y+3,self.ww-2,h-4,theme.dark)
        rect(x,y,self.ww,2,theme.pink)
        txt(x+self.ww/2,y+5,self.name,theme.txt,true)
        
        local cy = y + 23
        local n = 0
        for i,p in ipairs(self.pages) do
            n = n + 1
            local sel = (self.selIdx == n)
            local pre = self.open[i] and "[-]" or "[+]"
            local col = sel and theme.pink or theme.txt
            txt(x+5,cy+3,pre.." "..p.name,col)
            cy = cy + 17
            
            if self.open[i] then
                for _,s in ipairs(p.secs) do
                    txt(x+22,cy+3,"["..s.name.."]",theme.gray)
                    cy = cy + 17
                    for _,it in ipairs(s.items) do
                        n = n + 1
                        local selIt = (self.selIdx == n)
                        local colIt = selIt and theme.pink or theme.txt
                        local str
                        if it.typ == "toggle" then
                            str = it.name.." -> "..(it.val and "ON" or "OFF")
                        elseif it.typ == "slider" then
                            str = it.name.." -> <"..math.floor(it.val).."/"..it.max..">"
                        else
                            str = it.name
                            if it.com and it.com ~= "" then
                                str = str.." "..it.com
                            end
                        end
                        txt(x+22,cy+3,str,colIt)
                        cy = cy + 17
                    end
                end
            end
        end
    end
    
    function w:input()
        local now = d.Tick()
        if now - self.last < self.cd then return end
        
        local k = self:getKey()
        if not k then return end
        self.last = now
        
        if k == "["..self.key.."]" then
            self.vis = not self.vis
            return
        end
        if not self.vis then return end
        
        local total = self:total()
        local cur = self:cur()
        
        if k == "[UP]" then
            self.selIdx = math.max(1, self.selIdx - 1)
        elseif k == "[DOWN]" then
            self.selIdx = math.min(total, self.selIdx + 1)
        elseif k == "[LEFT]" or k == "[RIGHT]" then
            if cur and cur.type == "item" and cur.data.typ == "slider" then
                local delta = (k == "[LEFT]") and -1 or 1
                cur.data.val = math.clamp(cur.data.val + delta, cur.data.min, cur.data.max)
                if cur.data.cb then cur.data.cb(cur.data.val) end
            end
        elseif k == "[RETURN]" then
            if cur then
                if cur.type == "page" then
                    self.open[cur.idx] = not self.open[cur.idx]
                elseif cur.type == "item" then
                    local it = cur.data
                    if it.typ == "toggle" then
                        it.val = not it.val
                        if it.cb then it.cb(it.val) end
                    elseif it.typ == "button" then
                        if it.cb then it.cb() end
                    end
                end
            end
        end
    end
    
    function w:Page(p)
        local pg = {name = p.Name or "Page", secs = {}}
        function pg:Section(s)
            local sec = {name = s.Name or "Section", items = {}}
            function sec:Toggle(t)
                local it = {typ="toggle", name=t.Name or "Toggle", val=t.Default or false, cb=t.Callback}
                table.insert(sec.items, it)
                return it
            end
            function sec:Slider(sl)
                local it = {typ="slider", name=sl.Name or "Slider", val=sl.Default or 0, min=sl.Min or 0, max=sl.Max or 100, cb=sl.Callback}
                table.insert(sec.items, it)
                return it
            end
            function sec:Button(b)
                local it = {typ="button", name=b.Name or "Button", com=b.Comment or "", cb=b.Callback}
                table.insert(sec.items, it)
                return it
            end
            table.insert(pg.secs, sec)
            return sec
        end
        table.insert(self.pages, pg)
        return pg
    end
    
    d.ShowConsole(true)
    return w
end

return lib
