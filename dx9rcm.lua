-- rcm ui for dx9
local library = {}
local d = dx9

local theme = {
    inline = {6,6,6},
    dark = {24,24,24},
    text = {255,255,255},
    accent = {139,0,0},
    section = {150,150,150},
}

local function txt(x,y,s,c,center)
    if center then x = x - d.CalcTextWidth(s)/2 end
    d.DrawString({x,y}, c, s)
end

local function rect(x,y,w,h,c)
    d.DrawFilledBox({x,y}, {x+w,y+h}, c)
end

function library:Window(p)
    local w = {
        vis = true,
        x = (p.Position or {x=50,y=80}).x,
        y = (p.Position or {x=50,y=80}).y,
        sel = 1,
        pages = {},
        open = {},
        key = p.ToggleKey or "F2",
        name = p.Name or "rcm",
        ww = 280,
        lastKey = "",
        list = {},
    }
    
    function w:rebuild()
        local lst = {}
        for i,pg in ipairs(self.pages) do
            table.insert(lst, {typ="pg", idx=i})
            if self.open[i] then
                for _,s in ipairs(pg.secs) do
                    for _,it in ipairs(s.items) do
                        table.insert(lst, {typ="it", data=it})
                    end
                end
            end
        end
        self.list = lst
        if self.sel > #lst and #lst>0 then self.sel = #lst end
        if self.sel < 1 and #lst>0 then self.sel = 1 end
        return lst
    end
    
    function w:draw()
        if not self.vis then return end
        
        local h = 19
        for i,pg in ipairs(self.pages) do
            h = h + 17
            if self.open[i] then
                for _,s in ipairs(pg.secs) do
                    h = h + 17 + (#s.items * 17)
                end
            end
        end
        h = h + 4
        
        rect(self.x,self.y,self.ww,h,theme.inline)
        rect(self.x+1,self.y+3,self.ww-2,h-4,theme.dark)
        rect(self.x,self.y,self.ww,2,theme.accent)
        txt(self.x+self.ww/2,self.y+5,self.name,theme.text,true)
        
        local cy = self.y + 23
        local idx = 0
        
        for i,pg in ipairs(self.pages) do
            idx = idx + 1
            local pre = self.open[i] and "[-]" or "[+]"
            local col = (self.sel == idx) and theme.accent or theme.text
            txt(self.x+5,cy+3,pre.." "..pg.name,col)
            cy = cy + 17
            
            if self.open[i] then
                for _,s in ipairs(pg.secs) do
                    txt(self.x+22,cy+3,"["..s.name.."]",theme.section)
                    cy = cy + 17
                    for _,it in ipairs(s.items) do
                        idx = idx + 1
                        local selIt = (self.sel == idx)
                        local colIt = selIt and theme.accent or theme.text
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
                        txt(self.x+22,cy+3,str,colIt)
                        cy = cy + 17
                    end
                end
            end
        end
    end
    
    function w:input()
        local k = d.GetKey()
        if k == "" then
            self.lastKey = ""
            return
        end
        if k == self.lastKey then return end
        self.lastKey = k
        
        if k == "["..self.key.."]" then
            self.vis = not self.vis
            return
        end
        if not self.vis then return end
        
        if #self.list == 0 then return end
        
        if k == "[UP]" then
            self.sel = self.sel - 1
            if self.sel < 1 then self.sel = #self.list end
        elseif k == "[DOWN]" then
            self.sel = self.sel + 1
            if self.sel > #self.list then self.sel = 1 end
        elseif k == "[LEFT]" then
            local cur = self.list[self.sel]
            if cur and cur.typ == "it" and cur.data.typ == "slider" then
                local new = cur.data.val - 1
                if new >= cur.data.min then
                    cur.data.val = new
                    if cur.data.cb then cur.data.cb(cur.data.val) end
                end
            end
        elseif k == "[RIGHT]" then
            local cur = self.list[self.sel]
            if cur and cur.typ == "it" and cur.data.typ == "slider" then
                local new = cur.data.val + 1
                if new <= cur.data.max then
                    cur.data.val = new
                    if cur.data.cb then cur.data.cb(cur.data.val) end
                end
            end
        elseif k == "[RETURN]" then
            local cur = self.list[self.sel]
            if cur then
                if cur.typ == "pg" then
                    self.open[cur.idx] = not self.open[cur.idx]
                    self:rebuild()
                elseif cur.typ == "it" then
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
    
    function w:Page(pageData)
        local pg = {name = pageData.Name or "Page", secs = {}}
        function pg:Section(sectionData)
            local sec = {name = sectionData.Name or "Section", items = {}}
            function sec:Toggle(toggleData)
                local it = {typ="toggle", name=toggleData.Name or "Toggle", val=toggleData.Default or false, cb=toggleData.Callback}
                table.insert(sec.items, it)
                return it
            end
            function sec:Slider(sliderData)
                local it = {typ="slider", name=sliderData.Name or "Slider", val=sliderData.Default or 0, min=sliderData.Min or 0, max=sliderData.Max or 100, cb=sliderData.Callback}
                table.insert(sec.items, it)
                return it
            end
            function sec:Button(buttonData)
                local it = {typ="button", name=buttonData.Name or "Button", com=buttonData.Comment or "", cb=buttonData.Callback}
                table.insert(sec.items, it)
                return it
            end
            table.insert(pg.secs, sec)
            return sec
        end
        table.insert(self.pages, pg)
        return pg
    end
    
    w:rebuild()
    return w
end

return library
