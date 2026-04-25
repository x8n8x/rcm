-- cache
if _G.rcm_cache == nil then
    _G.rcm_cache = {}
end

local _oldGet = _G.rcm_cache.oldGet or dx9.Get
local _oldLoadstring = _G.rcm_cache.oldLoadstring or loadstring

if not _G.rcm_cache.hooked then
    _G.rcm_cache.hooked = true
    _G.rcm_cache.oldGet = dx9.Get
    _G.rcm_cache.oldLoadstring = loadstring

    dx9.Get = function(url)
        if _G.rcm_cache[url] == nil then
            _G.rcm_cache[url] = _oldGet(url)
        end
        return _G.rcm_cache[url]
    end

    loadstring = function(src)
        if _G.rcm_cache["ls_"..src] == nil then
            _G.rcm_cache["ls_"..src] = _oldLoadstring(src)
        end
        return _G.rcm_cache["ls_"..src]
    end
end


if _G.rcm == nil then
    _G.rcm = {
        col = {
            accent = {140, 0, 40},
            sel    = {200, 0, 55},
            bg     = {14, 14, 14},
            white  = {255, 255, 255},
            gray   = {100, 100, 100},
        },
 
        mx=8, my=8, mw=230,
        lh=17, px=8, ix=18,
 
        visible  = true,
        sel      = 0,
 
        prev_key = "",
        prev_lmb = false,
        prev_rmb = false,
 
        hold = {key="", t=0, ticks=0},
 
        wm = {
            visible = true,
            x=0, y=0, tx=0, ty=0,
            ox=0, oy=0,
            drag=false, snap=false, init=false,
        },
 
        fps    = {val=0, frames=0, acc=0},
        notifs = {},
 
        listen_key     = nil,
        listen_pending = nil,
        listen_armed   = false,
 
        items = {},
        pages = {},
 
        t_prev = os.clock(),
    }
end
 
local G   = _G.rcm
local col = G.col
 

KEY      = dx9.GetKey() or ""
LMB      = dx9.isLeftClick()
RMB      = dx9.isRightClick()
LMB_HELD = dx9.isLeftClickHeld()

local now = os.clock()
local dt  = math.min(now - G.t_prev, 0.1)
G.t_prev  = now
 
local function fill(x1,y1,x2,y2,c) dx9.DrawFilledBox({x1,y1},{x2,y2},c) end
local function str(x,y,c,t)        dx9.DrawString({x,y},c,t)            end
 
function send_notif(txt)
    local nh = 2 + G.lh + 4
    for _,n in ipairs(G.notifs) do n.ty = n.ty - (nh+4) end
    G.notifs[#G.notifs+1] = {
        txt  = txt,
        prog = 1.0,
        y    = dx9.size().height - 10,
        ty   = dx9.size().height - 10,
    }
end
 
local function has(t, v)
    for _,x in ipairs(t) do if x==v then return true end end
    return false
end
 
-- lib
 
library = {}
 
function library:Window(cfg)
    local w = {
        _name  = cfg.Name or "rcm",
        _tkey  = cfg.ToggleKey and ("["..cfg.ToggleKey:upper().."]") or "[F1]",
        _pages = {},
    }
 
    if cfg.Position then
        G.mx = cfg.Position.x or G.mx
        G.my = cfg.Position.y or G.my
    end
 
    local function add(id, default)
        if G.items[id] == nil then
            G.items[id] = default
        else
            G.items[id].cb = default.cb
        end
        return G.items[id]
    end
 
    function w:Page(cfg2)
        local pk = cfg2.Name
        if G.pages[pk] == nil then
            G.pages[pk] = {open=false, sections={}}
        end
        if G.pages[pk].sections == nil then
            G.pages[pk].sections = {}
        end
        if not has(w._pages, pk) then
            w._pages[#w._pages+1] = pk
        end
 
        local p = {_key=pk}
 
        function p:Section(cfg3)
            local sk = pk.."__"..cfg3.Name
            local pd = G.pages[pk]
 
            local sect = nil
            for _,s in ipairs(pd.sections) do
                if s._key==sk then sect=s; break end
            end
            if sect == nil then
                sect = {_key=sk, _name=cfg3.Name, _items={}}
                pd.sections[#pd.sections+1] = sect
            end
            if sect._items == nil then sect._items = {} end
 
            function sect:Toggle(c)
                local id = "tog_"..sk.."_"..c.Name
                if not has(sect._items, id) then sect._items[#sect._items+1]=id end
                return add(id, {type="toggle", label=c.Name,
                    val=c.Default or false, cb=c.Callback})
            end
            function sect:Slider(c)
                local id = "sld_"..sk.."_"..c.Name
                if not has(sect._items, id) then sect._items[#sect._items+1]=id end
                return add(id, {type="slider", label=c.Name,
                    val=c.Default or c.Min or 0,
                    min=c.Min or 0, max=c.Max or 10, cb=c.Callback})
            end
            function sect:Keybind(c)
                local id = "kb_"..sk.."_"..c.Name
                if not has(sect._items, id) then sect._items[#sect._items+1]=id end
                return add(id, {type="keybind", label=c.Name,
                    key=c.Default and c.Default:upper() or "NONE", cb=c.Callback})
            end
            function sect:Button(c)
                local id = "btn_"..sk.."_"..c.Name
                if not has(sect._items, id) then sect._items[#sect._items+1]=id end
                return add(id, {type="button", label=c.Name,
                    comment=c.Comment or "-> press enter", cb=c.Callback})
            end
 
            return sect
        end
 
        return p
    end
 
    return w
end
 
 
local function flat_list(w)
    local out = {}
    for _,pk in ipairs(w._pages) do
        local pd = G.pages[pk]
        out[#out+1] = {kind="page", key=pk, pd=pd}
        if pd.open then
            for _,sect in ipairs(pd.sections) do
                out[#out+1] = {kind="section", sect=sect}
                for _,ik in ipairs(sect._items) do
                    out[#out+1] = {kind="item", key=ik, it=G.items[ik]}
                end
            end
        end
    end
    return out
end
 
local function sel_list(flat)
    local s = {}
    for i,e in ipairs(flat) do
        if e.kind=="page" or (e.kind=="item" and e.it.type~="comment") then
            s[#s+1] = i
        end
    end
    return s
end
 
local function clamp_sel(flat)
    local s = sel_list(flat)
    if #s==0 then return end
    for _,i in ipairs(s) do if i-1==G.sel then return end end
    G.sel = s[1]-1
end
 
local function nav(flat, dir)
    local s = sel_list(flat)
    if #s==0 then return end
    local pos=1
    for i,v in ipairs(s) do if v-1==G.sel then pos=i; break end end
    pos = ((pos-1+dir) % #s)+1
    G.sel = s[pos]-1
end
 
-- input
 
local function process_input(flat, w)
    local key_idle = (KEY == "" or KEY == "[None]")
    local key_new  = (not key_idle and KEY ~= G.prev_key)
    local lmb_new = (LMB and not G.prev_lmb)
    local rmb_new = (RMB and not G.prev_rmb)
 
    -- toggle menu
    if key_new and KEY == w._tkey then
        G.visible = not G.visible
    end
 

    if G.listen_pending ~= nil then
        if key_idle then
            G.listen_key     = G.listen_pending
            G.listen_pending = nil
            G.listen_armed   = false
        end
        G.prev_key=KEY; G.prev_lmb=LMB; G.prev_rmb=RMB
        return
    end
 
    -- listen
    if G.listen_key ~= nil then
        local it = G.items[G.listen_key]
 
        if not G.listen_armed then
            -- wait for idle
            if key_idle then G.listen_armed = true end
        else
            if lmb_new then
                it.key       = "LMB"
                G.listen_key = nil
                G.listen_armed = false
                if it.cb then it.cb(it.key) end
            elseif rmb_new then
                it.key       = "RMB"
                G.listen_key = nil
                G.listen_armed = false
                if it.cb then it.cb(it.key) end
            elseif not key_idle and KEY ~= "[Unknown]" then
                -- strip brackets
                local k = KEY:match("%[(.+)%]") or KEY
                local newkey = (k == "BACK") and "NONE" or k
                it.key         = newkey
                G.listen_key   = nil
                G.listen_armed = false
                if it.cb then it.cb(newkey) end
            end
        end
 
        G.prev_key=KEY; G.prev_lmb=LMB; G.prev_rmb=RMB
        return
    end
 
    if not G.visible then
        G.prev_key=KEY; G.prev_lmb=LMB; G.prev_rmb=RMB
        return
    end
 
    clamp_sel(flat)
 
    if key_new then
        if     KEY == "[UP]"     then nav(flat, -1)
        elseif KEY == "[DOWN]"   then nav(flat,  1)
        elseif KEY == "[RETURN]" then
            local e = flat[G.sel+1]
            if e then
                if e.kind == "page" then
                    e.pd.open = not e.pd.open
                elseif e.kind == "item" then
                    local it = e.it
                    if it.type == "toggle" then
                        it.val = not it.val
                        if it.cb then it.cb(it.val) end
                    elseif it.type == "keybind" then
                        -- wait for release
                        G.listen_pending = e.key
                        G.listen_armed   = false
                    elseif it.type == "button" then
                        if it.cb then it.cb() end
                    end
                end
            end
        end
    end
 
    -- slider hold
    local e = flat[G.sel+1]
    if e and e.kind=="item" and e.it.type=="slider" then
        local it  = e.it
        local dir = 0
        if KEY=="[LEFT]" then dir=-1 elseif KEY=="[RIGHT]" then dir=1 end
        if dir ~= 0 then
            if G.hold.key ~= KEY then
                G.hold = {key=KEY, t=0, ticks=0}
                it.val = math.max(it.min, math.min(it.max, it.val+dir))
                if it.cb then it.cb(it.val) end
            else
                G.hold.t = G.hold.t + dt
                if G.hold.t > 0.35 then
                    local tks = math.floor((G.hold.t-0.35)/0.07)
                    if tks > G.hold.ticks then
                        it.val = math.max(it.min, math.min(it.max,
                            it.val + dir*(tks-G.hold.ticks)))
                        G.hold.ticks = tks
                        if it.cb then it.cb(it.val) end
                    end
                end
            end
        else
            if G.hold.key=="[LEFT]" or G.hold.key=="[RIGHT]" then
                G.hold = {key="",t=0,ticks=0}
            end
        end
    else
        if G.hold.key ~= "" then G.hold={key="",t=0,ticks=0} end
    end
 
    G.prev_key=KEY; G.prev_lmb=LMB; G.prev_rmb=RMB
end
 
-- draw
 
local function draw_menu(flat)
    local x,y,w    = G.mx, G.my, G.mw
    local lh,px,ix = G.lh, G.px, G.ix
 
    clamp_sel(flat)
 
    local h = 2 + 5 + lh + 4 + (#flat * lh) + 6
    fill(x, y, x+w, y+h, col.bg)
    fill(x, y, x+w, y+2, col.accent)
 
    local title = G._win_name or "rcm"
    str(x+(w-dx9.CalcTextWidth(title))/2, y+6, col.white, title)
 
    local cy = y+2+5+lh+3
    for fi,e in ipairs(flat) do
        local sel = (fi-1 == G.sel)
        if e.kind == "page" then
            local sym = e.pd.open and "[-] " or "[+] "
            str(x+3, cy, sel and col.sel or col.white, sym..e.key)
        elseif e.kind == "section" then
            str(x+ix, cy, col.gray, e.sect._name)
        elseif e.kind == "item" then
            local it = e.it
            local listening = (G.listen_key == e.key) or (G.listen_pending == e.key)
            local fc = sel and col.sel or col.white
            if it.type == "toggle" then
                str(x+ix, cy, fc, it.label.." -> "..(it.val and "ON" or "OFF"))
            elseif it.type == "slider" then
                str(x+ix, cy, fc, it.label.." -> <"..it.val.."/"..it.max..">")
            elseif it.type == "keybind" then
                local kdisp = listening and "[...]" or "["..it.key.."]"
                str(x+ix, cy, listening and col.accent or fc, it.label.." -> "..kdisp)
            elseif it.type == "button" then
                str(x+ix, cy, fc, it.label.." "..it.comment)
            end
        end
        cy = cy + lh
    end
end
 
-- watermark
 
local function draw_wm()
    G.fps.frames = G.fps.frames + 1
    G.fps.acc    = G.fps.acc + dt
    if G.fps.acc >= 0.2 then
        G.fps.val    = math.floor(G.fps.frames / G.fps.acc + 0.5)
        G.fps.frames = 0
        G.fps.acc    = 0
    end
 
    if not G.wm.visible then return end
 
    local label = (G._win_name or "rcm").." | "..G.fps.val.." fps"
    local wm_w  = dx9.CalcTextWidth(label) + G.px*2
    local wm_h  = 2 + G.lh + 2
    local sw,sh = dx9.size().width, dx9.size().height
    local wm    = G.wm
 
    if not wm.init then
        wm.x=sw/2-wm_w/2; wm.y=4
        wm.tx=wm.x; wm.ty=wm.y; wm.init=true
    end
 
    local snaps = {
        {x=sw/2-wm_w/2, y=4},
        {x=sw-wm_w-8,   y=4},
        {x=8,            y=4},
    }
    local mx2,my2 = dx9.GetMouse().x, dx9.GetMouse().y
 
    if LMB_HELD then
        if (mx2>=wm.x and mx2<=wm.x+wm_w and my2>=wm.y and my2<=wm.y+wm_h) or wm.drag then
            if not wm.drag then
                wm.drag=true; wm.snap=false
                wm.ox=mx2-wm.x; wm.oy=my2-wm.y
            end
            wm.x = math.max(0, math.min(sw-wm_w, mx2-wm.ox))
            wm.y = math.max(0, math.min(sh-wm_h, my2-wm.oy))
        end
    else
        if wm.drag then
            wm.drag = false
            local bd,bp = 80,nil
            for _,sp in ipairs(snaps) do
                local d = math.sqrt(((wm.x+wm_w/2)-(sp.x+wm_w/2))^2+(wm.y-sp.y)^2)
                if d<bd then bd=d; bp=sp end
            end
            if bp then wm.tx=bp.x; wm.ty=bp.y; wm.snap=true end
        end
    end
 
    if wm.snap then
        wm.x = wm.x+(wm.tx-wm.x)*math.min(1,12*dt)
        wm.y = wm.y+(wm.ty-wm.y)*math.min(1,12*dt)
        if math.abs(wm.tx-wm.x)<0.3 and math.abs(wm.ty-wm.y)<0.3 then
            wm.x=wm.tx; wm.y=wm.ty; wm.snap=false
        end
    end
 
    local wx,wy = math.floor(wm.x), math.floor(wm.y)
    fill(wx, wy, wx+wm_w, wy+wm_h, col.bg)
    fill(wx, wy, wx+wm_w, wy+2,    col.accent)
    str(wx+G.px, wy+4, col.white, label)
end
 
-- notifs
 
local function draw_notifs()
    local sw  = dx9.size().width
    local sh  = dx9.size().height
    local nw  = 210
    local nph = 5
    local nh  = 2 + G.lh + nph * 2
 
    for i=#G.notifs,1,-1 do
        G.notifs[i].prog = G.notifs[i].prog - dt/3.0
        if G.notifs[i].prog <= 0 then table.remove(G.notifs, i) end
    end
 
    for i=1,#G.notifs do
        G.notifs[i].ty = sh-10 - (#G.notifs-i)*(nh+4)
    end
 
    for _,n in ipairs(G.notifs) do
        n.y = n.y + (n.ty-n.y)*math.min(1,10*dt)
        local nx = sw-nw-10
        local ny = math.floor(n.y)
        fill(nx, ny-nh, nx+nw, ny, col.bg)
        local bw = math.floor(nw*math.max(0,n.prog))
        if bw>0 then fill(nx, ny-nh, nx+bw, ny-nh+2, col.accent) end
        str(nx+G.px+2, ny-nh+nph+2, col.white, n.txt)
    end
end
 
-- render
 
function library:Render(w)
    G._win_name = w._name
    local flat = flat_list(w)
    process_input(flat, w)
    flat = flat_list(w)
    if G.visible then draw_menu(flat) end
    draw_wm()
    draw_notifs()
end
