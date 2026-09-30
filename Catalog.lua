-- LocalCatalog v11. Client-only. Personalized browsing, makeup, bundles, body parts and resizable UI.
-- RightControl toggles the window. No place remotes or purchases: bundles and bodies are applied locally.
if not game:IsLoaded() then game.Loaded:Wait() end
local env=getgenv and getgenv() or _G
local carry,carryVisible
if env.LocalCatalog then
    local old=env.LocalCatalog
    if old.Gui then carryVisible=old.Gui.Panel.Visible or (old.Gui:FindFirstChild('TransformEditor') and old.Gui.TransformEditor.Visible) end
    if old.ExportOutfit then carry=old.ExportOutfit() else
        carry={AssetIds={},HideOriginal=false}
        for id in pairs(old.Items or {}) do table.insert(carry.AssetIds,id) end
    end
    old.Unload()
end
local Players=game:GetService('Players')
local AES=game:GetService('AvatarEditorService')
local MPS=game:GetService('MarketplaceService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
local LEGACY_SAVE='LocalCatalog-outfit.json'
local OUTFITS='LocalCatalog-outfits.json'
local FAVORITES='LocalCatalog-favorites.json'
local SETTINGS='LocalCatalog-settings.json'
local app={Alive=true,Items={},Desired={},Hidden={},Cache={},Connections={},Busy=false,
    Version=11,KeepOnRespawn=true,HideOriginal=false,Restoring=false,Revision=0,SearchBusy=false,
    Window={Width=1100,Height=736,Scale=1}}
env.LocalCatalog=app
-- Внешним модулям (портрет в MM2): образ или персонаж изменились — пора пересобрать картинку
local portraitSignal=Instance.new('BindableEvent')
app.PortraitChanged=portraitSignal.Event
-- These gates survive reloads so an old in-flight request cannot overlap a new instance.
env.LocalCatalogNetwork=env.LocalCatalogNetwork or {Search={Next=0},Avatar={Next=0},Metadata={}}
local network=env.LocalCatalogNetwork
network.Bundles=network.Bundles or {}
local function limited(err)
    local s=string.lower(tostring(err))
    return s:find('429',1,true) or s:find('too many requests',1,true) or s:find('rate limit',1,true)
end
local function apiCall(lane,fn,active,gap)
    local function waitUntil(deadline)
        while os.clock()<deadline do if not active() then error('Operation cancelled',0) end; task.wait(math.min(0.1,deadline-os.clock())) end
    end
    while lane.Busy do waitUntil(os.clock()+0.1) end
    assert(active(),'Operation cancelled'); lane.Busy=true
    local ok,result=pcall(function()
        for attempt=1,4 do
            waitUntil(lane.Next or 0)
            assert(active(),'Operation cancelled')
            app.ApiCalls=(app.ApiCalls or 0)+1
            local success,value=pcall(fn)
            lane.Next=os.clock()+(gap or 1.2)
            if success then return value end
            if not limited(value) or attempt==4 then error(value,0) end
            lane.Next=os.clock()+math.min(20,2^attempt)
            if app.Alive then app.NetworkWaiting=true end
        end
    end)
    lane.Busy=false; app.NetworkWaiting=false
    if not ok then error(result,0) end
    return result
end
local redraw,updateControls,status
local function safeText(value)
    -- Display standard Latin/Cyrillic text without decorative emoji or missing-glyph icons.
    local result={}
    local ok=pcall(function()
        for _,c in utf8.codes(tostring(value or '')) do
            if (c>=32 and c<=591) or (c>=1024 and c<=1327) or c==9733 or c==9734 then table.insert(result,utf8.char(c))
            elseif c==10 or c==9 then table.insert(result,' ') end
        end
    end)
    if not ok then return 'Item' end
    local s=table.concat(result):gsub('%s+',' '):match('^%s*(.-)%s*$')
    return s~='' and s or 'Untitled'
end
local function message(s,isError)
    app.LastMessage=safeText(s)
    if status then
        status.Text=app.LastMessage
        status.TextColor3=isError and Color3.fromRGB(255,156,157) or Color3.fromRGB(167,190,213)
    end
end
local function refresh()
    if not app.Alive then return end
    if redraw then redraw() end
    if updateControls then updateControls() end
    if app.RequestPreview then app.RequestPreview() end
    if app.QueuePortrait then app.QueuePortrait() end
    portraitSignal:Fire()
end
local function connect(signal,fn)
    local c=signal:Connect(fn); table.insert(app.Connections,c); return c
end
local function make(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent; return o
end
local function corner(o,r) make('UICorner',{CornerRadius=UDim.new(0,r or 9)},o) end
local function valid(rev,ch)
    return app.Alive and rev==app.Revision and ch==player.Character
end
local function current()
    assert(app.Alive,'Catalog is closed')
    local ch=player.Character
    assert(ch and ch.Parent and ch:FindFirstChildOfClass('Humanoid'),'Character is still loading')
    return ch
end
local clothing={[2]='ShirtGraphic',[11]='Shirt',[12]='Pants',[18]='Decal'}
local makeup={[88]='Face',[89]='Lip',[90]='Eye'}
local accessory={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,
    [64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
-- Части тела: тип ассета -> поле HumanoidDescription. Классическая и динамическая голова — один слот
local bodySlots={[17]='Head',[79]='Head',[27]='Torso',[28]='RightArm',[29]='LeftArm',[30]='LeftLeg',[31]='RightLeg'}
local slotParts={Head={'Head'},Torso={'UpperTorso','LowerTorso'},LeftArm={'LeftUpperArm','LeftLowerArm','LeftHand'},
    RightArm={'RightUpperArm','RightLowerArm','RightHand'},LeftLeg={'LeftUpperLeg','LeftLowerLeg','LeftFoot'},
    RightLeg={'RightUpperLeg','RightLowerLeg','RightFoot'}}
-- Анимации из паков и динамических голов; по каким слотам Animate раскладывать — решает сам ассет
local animationKinds={[48]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[78]=true}
local function supportedKind(kind)
    return accessory[kind] or clothing[kind] or makeup[kind] or bodySlots[kind] or animationKinds[kind]
end
local restoreBody,restoreAnimations
local function isCosmetic(o)
    return o:IsA('Accessory') or o:IsA('Shirt') or o:IsA('Pants') or o:IsA('ShirtGraphic')
end
-- ctx: app (свой персонаж) или контекст синхронизированного чужого игрока из app.Remote
local function hide(o,ctx)
    ctx=ctx or app
    if not ctx.Hidden[o] then ctx.Hidden[o]=o.Parent; o.Parent=nil end
end
local function restoreHidden(predicate,ctx)
    ctx=ctx or app
    local restore={}
    for o,parent in pairs(ctx.Hidden) do if predicate(o,parent) then table.insert(restore,{o,parent}) end end
    for _,v in ipairs(restore) do
        ctx.Hidden[v[1]]=nil
        local parent=v[2]
        if parent and parent.Parent then pcall(function() v[1].Parent=parent end) else v[1]:Destroy() end
    end
end
-- Части тела возвращает restoreBody, анимации — restoreAnimations; здесь только свои объекты
local function destroyItem(id,ctx)
    ctx=ctx or app
    local item=ctx.Items[id]
    if item then
        if item.Slot then
            if item.R6Mesh and item.Object and item.Object.Parent then item.Object:Destroy() end
        elseif not item.Animation and item.Object and item.Object.Parent then item.Object:Destroy() end
        ctx.Items[id]=nil
    end
end
local function clearVisuals()
    if app.CloseDialogs then app.CloseDialogs() end
    if app.EditingId and app.CloseTransform then app.CloseTransform(false,true) end
    local ids={}; for id in pairs(app.Items) do table.insert(ids,id) end
    for _,id in ipairs(ids) do destroyItem(id) end
    restoreBody(app)
    restoreAnimations(app)
    restoreHidden(function() return true end)
end
local function hideOriginal(ch,ctx)
    ctx=ctx or app
    local added={}; for _,it in pairs(ctx.Items) do if it.Object then added[it.Object]=true end end
    for _,o in ipairs(ch:GetChildren()) do if isCosmetic(o) and not added[o] then hide(o,ctx) end end
    local head=ch:FindFirstChild('Head')
    if head then for _,o in ipairs(head:GetChildren()) do
        if o:IsA('Decal') and o:FindFirstChildOfClass('WrapTextureTransfer') and not added[o] then hide(o,ctx) end
    end end
end
function app.SetHideOriginal(value)
    app.HideOriginal=value==true
    if app.HideOriginal then hideOriginal(current()) else
        restoreHidden(function(o)
            for _,it in pairs(app.Items) do
                if clothing[it.Kind] and o:IsA(clothing[it.Kind]) then return false end
            end
            return true
        end)
    end
    refresh()
end
function app.ExportOutfit()
    local ids={}; for id in pairs(app.Desired) do table.insert(ids,id) end; table.sort(ids)
    local transforms,items={},{}
    for _,id in ipairs(ids) do
        local it=app.Desired[id]
        table.insert(items,{Id=id,Name=it.Name,Kind=it.Kind,LayerOrder=it.LayerOrder})
        if it.Transform then
            local t=it.Transform
            transforms[string.format('%.0f',id)]={Position=table.clone(t.Position),Rotation=table.clone(t.Rotation),Scale=table.clone(t.Scale)}
        end
    end
    return {Version=4,AssetIds=ids,Items=items,HideOriginal=app.HideOriginal,Transforms=transforms}
end
function app.Reset()
    app.Revision+=1
    app.Desired={}; app.HideOriginal=false; app.Restoring=false; app.Busy=false
    clearVisuals(); refresh(); message('Original appearance restored')
end
local function attach(acc,ch,fit)
    local handle=acc:FindFirstChild('Handle')
    assert(handle and handle:IsA('BasePart'),'Accessory has no Handle')
    for _,w in ipairs(handle:QueryDescendants('JointInstance, WeldConstraint, RigidConstraint')) do
        if w.Name=='AccessoryWeld' or w.Name=='AccessoryRigidConstraint' then w:Destroy() end
    end
    for _,p in ipairs(acc:QueryDescendants('BasePart')) do
        p.Anchored=false; p.CanCollide=false; p.CanTouch=false; p.Massless=true
    end
    local own=handle:FindFirstChildOfClass('Attachment')
    local target
    if own then
        for _,part in ipairs(ch:GetChildren()) do
            if part:IsA('BasePart') then
                local a=part:FindFirstChild(own.Name)
                if a and a:IsA('Attachment') then target=a; break end
            end
        end
    end
    local part=fit and ch:FindFirstChild(fit.Part) or (target and target.Parent or ch:FindFirstChild('Head'))
    assert(part,'No matching character attachment')
    local c0=fit and fit.C0 or (own and target and own.CFrame or acc.AttachmentPoint)
    local c1=fit and fit.C1 or (target and target.CFrame or CFrame.new(0,0.5,0))
    handle.CFrame=part.CFrame*c1*c0:Inverse()
    if fit and fit.NativeConstraint and #acc:QueryDescendants('WrapLayer')>0 and own and target then
        own.CFrame=c0
        make('RigidConstraint',{Name='AccessoryRigidConstraint',Attachment0=own,Attachment1=target},handle)
        acc.Parent=ch
        return nil,nil
    end
    local weld=make('Weld',{Name='AccessoryWeld',Part0=handle,Part1=part,C0=c0,C1=c1},handle)
    acc.Parent=ch; return weld,c0
end
local function defaultTransform()
    return {Position={0,0,0},Rotation={0,0,0},Scale={1,1,1}}
end
local function normalizedTransform(data)
    local out=defaultTransform()
    for key,values in pairs(out) do
        local source=data and data[key]
        for axis=1,3 do
            local v=source and tonumber(source[axis]) or values[axis]
            assert(v and v==v and math.abs(v)<math.huge,'Enter a finite number')
            values[axis]=math.clamp(v,key=='Scale' and 0.05 or (key=='Rotation' and -360 or -10),key=='Scale' and 5 or (key=='Rotation' and 360 or 10))
        end
    end
    return out
end
local function transformItem(it,data)
    local t=normalizedTransform(data)
    local h=it.Object.Handle
    local s=Vector3.new(unpack(t.Scale))
    h.Size=it.BaseSize*s
    if it.Mesh then it.Mesh.Scale=it.BaseMeshScale*s; it.Mesh.Offset=it.BaseMeshOffset*s end
    for a,cf in pairs(it.BaseAttachments) do
        if a.Parent then a.CFrame=CFrame.new(cf.Position*s)*cf.Rotation end
    end
    it.Weld.C0=CFrame.new(it.Base.Position*s)*it.Base.Rotation
    it.Weld.C1=it.BaseC1*CFrame.new(unpack(t.Position))*CFrame.fromEulerAnglesXYZ(math.rad(t.Rotation[1]),math.rad(t.Rotation[2]),math.rad(t.Rotation[3]))
    h.CFrame=it.Weld.Part1.CFrame*it.Weld.C1*it.Weld.C0:Inverse()
    it.Transform=t
    return t
end
function app.SetTransform(id,data)
    local it=app.Items[id]
    assert(it and it.Weld,'Select an equipped accessory')
    assert(not it.Layered,'Transform Item is not available for layered clothing')
    local t=transformItem(it,data)
    if app.Desired[id] then app.Desired[id].Transform=t end
    if app.UpdateTransformFields then app.UpdateTransformFields(id) end
    if app.RequestPreview then app.RequestPreview() end
    return t
end
local assetTypesByName={}
for _,v in ipairs(Enum.AvatarAssetType:GetEnumItems()) do assetTypesByName[v.Name]=v.Value end

local function kindFromHint(hint)
    if type(hint)~='table' then return nil end
    local assetType=hint.AssetType or hint.Kind
    if typeof and typeof(assetType)=='EnumItem' then assetType=assetType.Name end
    if type(assetType)=='string' then return assetTypesByName[assetType] end
    if type(assetType)=='number' then return assetType end
end

local bodyProperties={'Head','Torso','LeftArm','RightArm','LeftLeg','RightLeg','HeightScale','WidthScale','DepthScale','HeadScale','BodyTypeScale','ProportionScale'}
local scaleValues={HeightScale='BodyHeightScale',WidthScale='BodyWidthScale',DepthScale='BodyDepthScale',HeadScale='HeadScale',BodyTypeScale='BodyTypeScale',ProportionScale='BodyProportionScale'}
local function bodyContext(ch,ctx)
    ctx=ctx or app
    local h=ch:FindFirstChildOfClass('Humanoid')
    local d=h:GetAppliedDescription()
    -- Примеренные части тела: под них садятся аксессуары и собирается следующая часть
    for _,it in pairs(ctx.Items) do if it.Slot then d[it.Slot]=it.Id end end
    for prop,name in pairs(scaleValues) do local v=h:FindFirstChild(name); if v then d[prop]=v.Value end end
    local key={h.RigType.Name}
    for _,prop in ipairs(bodyProperties) do table.insert(key,tostring(d[prop])) end
    d:SetAccessories({},true)
    for _,o in ipairs(d:QueryDescendants('MakeupDescription')) do o:Destroy() end
    d.Shirt=0; d.Pants=0; d.GraphicTShirt=0
    return d,table.concat(key,':'),h.RigType
end
local function itemMetadata(id,hint,active)
    local cached=network.Metadata[id]
    local hintedKind=kindFromHint(hint)
    if cached then return cached end
    if hintedKind then
        local info={Kind=hintedKind,Name=safeText(hint.Name or ('ID '..string.format('%.0f',id)))}
        network.Metadata[id]=info; return info
    end
    local info=apiCall(network.Avatar,function() return MPS:GetProductInfoAsync(id,Enum.InfoType.Asset) end,active,0.35)
    local result={Kind=info.AssetTypeId,Name=safeText(info.Name)}
    network.Metadata[id]=result; return result
end
local function loadFittedWearable(id,kind,description,rig,active)
    if makeup[kind] then
        make('MakeupDescription',{AssetId=id,MakeupType=Enum.MakeupType[makeup[kind]],Order=1},description)
        local model=apiCall(network.Avatar,function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description,rig)
        end,active,0.35)
        local chosen
        local head=model:FindFirstChild('Head')
        if head then for _,o in ipairs(head:GetChildren()) do
            if o:IsA('Decal') and o:FindFirstChildOfClass('WrapTextureTransfer') then chosen=o; break end
        end end
        if chosen then chosen.Parent=nil end
        model:Destroy()
        assert(chosen,'Roblox did not return a makeup texture')
        return chosen
    end
    if accessory[kind] then
        local assetType
        for name,value in pairs(assetTypesByName) do if value==kind then assetType=Enum.AvatarAssetType[name]; break end end
        assert(assetType,'Unknown accessory type')
        local record={AssetId=id,AccessoryType=AES:GetAccessoryType(assetType),IsLayered=(kind>=64 and kind<=72) or kind==76 or kind==77}
        -- Order on a rigid accessory makes SetAccessories silently discard the record.
        if record.IsLayered then record.Order=1 end
        description:SetAccessories({record},true)
        local model=apiCall(network.Avatar,function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description,rig)
        end,active,0.35)
        local chosen,fit
        local ok,err=pcall(function()
            -- AvatarJointUpgrade and layered fitting finish only after entering the world.
            -- Assemble locally, off-screen, without collisions or executable scripts.
            for _,scriptObject in ipairs(model:QueryDescendants('LuaSourceContainer')) do scriptObject:Destroy() end
            for _,part in ipairs(model:QueryDescendants('BasePart')) do part.CanCollide=false; part.CanTouch=false; part.CanQuery=false end
            local root=model:FindFirstChild('HumanoidRootPart')
            if root then root.Anchored=true end
            model.Name='_LocalCatalogFitting'; model:PivotTo(CFrame.new(0,10000,0)); model.Parent=workspace
            local advanced=#model:QueryDescendants('AnimationConstraint')>0
            local deadline=os.clock()+1.5
            repeat
                assert(active(),'Operation cancelled')
                task.wait(0.05)
            until not advanced or #model:QueryDescendants('RigidConstraint')>0 or os.clock()>=deadline
            task.wait(0.1)
            for _,o in ipairs(model:GetChildren()) do
                if o:IsA('Accessory') then chosen=o; break end
            end
            assert(chosen,'Avatar assembly did not return an accessory')
            local h=chosen:FindFirstChild('Handle')
            local w=h and h:FindFirstChild('AccessoryWeld')
            if w and w:IsA('JointInstance') and w.Part1 then fit={Part=w.Part1.Name,C0=w.C0,C1=w.C1} end
            local constraint=h and h:FindFirstChildOfClass('RigidConstraint')
            if constraint and constraint.Attachment0 and constraint.Attachment1 then
                fit={Part=constraint.Attachment1.Parent.Name,C0=constraint.Attachment0.CFrame,C1=constraint.Attachment1.CFrame,NativeConstraint=true}
            end
            chosen.Parent=nil
        end)
        model:Destroy()
        if not ok then if chosen then chosen:Destroy() end; error(err,0) end
        return chosen,fit
    end
    local objects=game:GetObjects('rbxassetid://'..string.format('%.0f',id))
    local chosen
    for _,root in ipairs(objects) do
        if root:IsA(clothing[kind]) then chosen=root; break end
        local candidates=root:QueryDescendants(clothing[kind])
        if candidates[1] then chosen=candidates[1]; chosen.Parent=nil; break end
    end
    for _,root in ipairs(objects) do if root~=chosen then root:Destroy() end end
    assert(chosen,'Roblox did not return clothing for this ID')
    return chosen
end

-- Посадка зависит от тела: шаблоны аксессуаров и макияжа кэшируем по телу,
-- чтобы свой персонаж и синхронизированные чужие не вытесняли шаблоны друг друга
local function cacheKey(id,bodyKey)
    local info=network.Metadata[id]
    if info and (accessory[info.Kind] or makeup[info.Kind]) then return string.format('%.0f',id)..'|'..bodyKey end
    return id
end
-- Общая примерка для любого персонажа: ctx — app или контекст чужого игрока,
-- active() — жив ли ещё запрос. Возвращает надетый предмет и шаблон из кэша
local function wearOn(ctx,ch,id,hint,active)
    local description,bodyKey,rig=bodyContext(ch,ctx)
    local cached=app.Cache[cacheKey(id,bodyKey)]
    if cached and (accessory[cached.Kind] or makeup[cached.Kind]) and cached.BodyKey~=bodyKey then
        cached=nil
    end
    if not cached then
        local chosen,fit,info
        local ok,err=pcall(function()
            info=itemMetadata(id,hint,active)
            assert(accessory[info.Kind] or clothing[info.Kind] or makeup[info.Kind],'Unsupported item type')
            chosen,fit=loadFittedWearable(id,info.Kind,description,rig,active)
            for _,scriptObject in ipairs(chosen:QueryDescendants('LuaSourceContainer')) do scriptObject:Destroy() end
            assert(active(),'Operation cancelled')
        end)
        description:Destroy()
        if not ok then if chosen then chosen:Destroy() end; error(err,0) end
        chosen.Archivable=true
        cached={Template=chosen,Kind=info.Kind,Name=info.Name,Layered=#chosen:QueryDescendants('WrapLayer')>0,BodyKey=bodyKey,Fit=fit}
        local key=cacheKey(id,bodyKey)
        if app.Cache[key] then app.Cache[key].Template:Destroy() end
        app.Cache[key]=cached
    else description:Destroy() end

    local kind=cached.Kind
    local humanoid=ch:FindFirstChildOfClass('Humanoid')
    if cached.Layered then
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,'Layered clothing requires R15')
    end

    -- У своего персонажа выбор хранится в Desired, у чужого — только надетое
    local owned=ctx.Desired or ctx.Items
    local chosen=cached.Template:Clone()
    local weld,base
    local ok,err=pcall(function()
        if makeup[kind] then
            local head=ch:FindFirstChild('Head')
            assert(head and head:IsA('MeshPart') and head:FindFirstChildOfClass('WrapTarget'),'Makeup requires a compatible MeshPart head with WrapTarget')
            chosen:SetAttribute('LocalCatalogMakeup',true)
            chosen.Parent=head
        elseif accessory[kind] then
            weld,base=attach(chosen,ch,cached.Fit)
        else
            local parent=kind==18 and ch:FindFirstChild('Head') or ch
            assert(parent,'Head is still loading')
            local remove={}
            for key,item in pairs(owned) do if item.Kind==kind then table.insert(remove,key) end end
            for _,key in ipairs(remove) do destroyItem(key,ctx); owned[key]=nil end
            for _,o in ipairs(parent:GetChildren()) do if o:IsA(clothing[kind]) then hide(o,ctx) end end
            chosen.Parent=parent
        end
    end)
    if not ok then chosen:Destroy(); error(err) end

    local it={Id=id,Name=cached.Name,Kind=kind,Object=chosen,Weld=weld,Base=base,Layered=cached.Layered}
    ctx.Items[id]=it
    local order=hint and hint.LayerOrder
    if cached.Layered or makeup[kind] then
        if not order then
            order=1
            for _,v in pairs(owned) do order=math.max(order,(v.LayerOrder or 0)+1) end
            if makeup[kind] then for _,o in ipairs(ch.Head:GetChildren()) do
                if o:IsA('Decal') and o~=chosen then order=math.max(order,o.ZIndex+1) end
            end end
        end
        for _,wrap in ipairs(chosen:QueryDescendants('WrapLayer')) do wrap.Order=order end
        if makeup[kind] then chosen.ZIndex=order end
    end
    it.LayerOrder=order
    if weld and not cached.Layered then
        local h=chosen.Handle
        it.BaseSize=h.Size; it.BaseC1=weld.C1; it.BaseAttachments={}
        for _,a in ipairs(h:QueryDescendants('Attachment')) do it.BaseAttachments[a]=a.CFrame end
        it.Mesh=h:FindFirstChildOfClass('SpecialMesh')
        if it.Mesh then it.BaseMeshScale=it.Mesh.Scale; it.BaseMeshOffset=it.Mesh.Offset end
    end
    return it,cached
end

-- Системы тела, анимаций и бандлов живут в одном блоке: у главного чанка лимит в 200 локалей
local wearBody,bundleDetails
do
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Части тела
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Реальные части персонажа никогда не меняют Parent. Хват тула (RightGrip) создаёт
    -- Humanoid владельца и реплицирует на сервер, но после локального Parent=nil и возврата
    -- клиент перестаёт реплицировать новое внутри части: сервер не видит хвата, ручка падает
    -- в пустоту и тул сгорает на FallenPartsDestroyHeight (проверено в MM2 вторым аккаунтом).
    -- Поэтому новое тело надеваем прямо на исходные части: меш и текстура — MeshPart:ApplyMesh,
    -- размер, прозрачность и аттачменты — с модели Roblox, клетка, лицо и SurfaceAppearance —
    -- копиями. Суставы, хват оружия, дисплеи скинов и аксессуары остаются на своих частях
    -- и садятся уже по новой форме
    local function near(a,b)
        if typeof(a)=='CFrame' then
            return (a.Position-b.Position).Magnitude<1e-3 and a.LookVector:Dot(b.LookVector)>0.9999 and a.UpVector:Dot(b.UpVector)>0.9999
        elseif typeof(a)=='Vector3' then return (a-b).Magnitude<1e-3 end
        return math.abs(a-b)<1e-3
    end
    -- Внешний вид части; макияж (свой и серверный) остаётся на голове
    local appearanceClasses={'DataModelMesh','SurfaceAppearance','WrapTarget','Decal','FaceControls','Bone'}
    local function isAppearance(o)
        if o:GetAttribute('LocalCatalogMakeup') or o:FindFirstChildOfClass('WrapTextureTransfer') then return false end
        for _,class in ipairs(appearanceClasses) do if o:IsA(class) then return true end end
        return false
    end
    local function isRigPoint(o) return o:IsA('Attachment') and not o:IsA('Bone') end
    -- Motor6D берут смещения из риг-аттачментов, аксессуары — из одноимённого аттачмента части.
    -- Свои примерки пересчитываем с их трансформацией
    local function fixRig(ctx,ch,touched)
        for _,m in ipairs(ch:QueryDescendants('Motor6D')) do
            if touched[m.Part0] or touched[m.Part1] then
                local a0=m.Part0 and m.Part0:FindFirstChild(m.Name..'RigAttachment')
                local a1=m.Part1 and m.Part1:FindFirstChild(m.Name..'RigAttachment')
                if a0 and a1 and a0:IsA('Attachment') and a1:IsA('Attachment') then m.C0=a0.CFrame; m.C1=a1.CFrame end
            end
        end
        local own={}
        for _,it in pairs(ctx.Items) do
            if it.Weld and it.BaseC1 and it.Object and it.Object.Parent and touched[it.Weld.Part1] then
                own[it.Object]=true
                local handle=it.Object:FindFirstChild('Handle')
                local a=handle and handle:FindFirstChildOfClass('Attachment')
                local target=a and it.Weld.Part1:FindFirstChild(a.Name)
                if target and target:IsA('Attachment') then
                    it.BaseC1=target.CFrame
                    pcall(transformItem,it,it.Transform)
                end
            end
        end
        for _,acc in ipairs(ch:GetChildren()) do
            local handle=acc:IsA('Accessory') and not own[acc] and acc:FindFirstChild('Handle')
            local weld=handle and handle:FindFirstChild('AccessoryWeld')
            local a=handle and handle:FindFirstChildOfClass('Attachment')
            if weld and weld:IsA('Weld') and a and touched[weld.Part1] then
                local target=weld.Part1:FindFirstChild(a.Name)
                if target and target:IsA('Attachment') then weld.C1=target.CFrame end
            end
        end
    end
    local function bodyState(ctx,ch)
        local body=ctx.Body
        if body and body.Character~=ch then restoreBody(ctx); body=nil end
        if not body then
            local h=ch:FindFirstChildOfClass('Humanoid')
            local root=ch:FindFirstChild('HumanoidRootPart')
            local ra=root and root:FindFirstChild('RootRigAttachment')
            body={Character=ch,Parts={},Meshes={},Connections={},Humanoid=h,RootAttachment=ra,
                HipHeight=h and h.HipHeight,RootCF=ra and ra:IsA('Attachment') and ra.CFrame or nil}
            ctx.Body=body
        end
        return body
    end
    -- Сервер пересобрал тело (ApplyDescription, смена масштаба): примерка устарела,
    -- владелец контекста одевает персонажа заново
    local function invalidateBody(ctx,body)
        if body.Invalid or ctx.Body~=body then return end
        body.Invalid=true
        task.delay(0.3,function()
            if ctx.Body==body and ctx.OnBodyInvalid then ctx.OnBodyInvalid(body.Character) end
        end)
    end
    local function watchBody(ctx,ch,body)
        if body.Watching then return end
        body.Watching=true
        local function track(signal,fn) table.insert(body.Connections,signal:Connect(fn)) end
        track(ch.ChildAdded,function(o)
            local entry=o:IsA('BasePart') and body.Parts[o.Name]
            if entry and o~=entry.Part then invalidateBody(ctx,body) end
        end)
        if body.Humanoid then
            for _,v in ipairs(body.Humanoid:GetChildren()) do
                if v:IsA('NumberValue') then track(v.Changed,function() invalidateBody(ctx,body) end) end
            end
        end
    end
    -- Откат одной части. Что успел поменять сервер, не трогаем — его значение новее нашего
    local function revertPart(entry)
        local p=entry.Part
        for _,c in ipairs(entry.Connections) do c:Disconnect() end
        entry.Connections={}
        for _,o in ipairs(entry.Added) do if o.Parent then o:Destroy() end end
        local alive=p.Parent~=nil
        for o,parent in pairs(entry.Hidden) do
            if alive then pcall(function() o.Parent=parent end) else o:Destroy() end
        end
        if entry.Backup then
            if alive and entry.MeshId and p.MeshId==entry.MeshId then
                pcall(function() p:ApplyMesh(entry.Backup); p.TextureID=entry.TextureID end)
            end
            entry.Backup:Destroy()
        end
        if not alive then return end
        if entry.AppliedSize and near(p.Size,entry.AppliedSize) then p.Size=entry.Size end
        if entry.AppliedTransparency and near(p.Transparency,entry.AppliedTransparency) then p.Transparency=entry.Transparency end
        for a,rec in pairs(entry.Attachments) do
            if a.Parent==p and near(a.CFrame,rec.Applied) then a.CFrame=rec.Original end
        end
    end
    -- Одна часть: запись заводим до изменений, чтобы откатить и недоделанную
    local function applyPart(body,real,new)
        local entry={Part=real,Size=real.Size,Transparency=real.Transparency,Attachments={},Hidden={},Added={},Connections={}}
        body.Parts[real.Name]=entry
        if new:IsA('MeshPart') and real:IsA('MeshPart') then
            entry.Backup=Instance.new('MeshPart')
            entry.Backup:ApplyMesh(real)
            entry.TextureID=real.TextureID
            real:ApplyMesh(new)
            real.TextureID=new.TextureID
            entry.MeshId=real.MeshId; entry.AppliedTexture=real.TextureID
        end
        -- Классическая голова донора несёт лицо из описания — оставляем своё; динамическая
        -- и headless лица не имеют — прячем
        entry.KeepFace=real.Name=='Head' and new:FindFirstChildWhichIsA('Decal')~=nil
        for _,o in ipairs(real:GetChildren()) do
            if isAppearance(o) and not (entry.KeepFace and o:IsA('Decal')) then entry.Hidden[o]=real; o.Parent=nil end
        end
        if new:IsA('MeshPart') and not real:IsA('MeshPart') and new.MeshSize.Magnitude>0 then
            -- Часть без MeshPart (голова R6, старые риги): меш донора через FileMesh
            table.insert(entry.Added,make('SpecialMesh',{MeshType=Enum.MeshType.FileMesh,MeshId=new.MeshId,
                TextureId=new.TextureID,Scale=new.Size/new.MeshSize},real))
        end
        for _,o in ipairs(new:GetChildren()) do
            if isAppearance(o) and not (entry.KeepFace and o:IsA('Decal')) then
                local c=o:Clone(); c.Parent=real; table.insert(entry.Added,c)
            end
        end
        -- Риг и аксессуары — по аттачментам донора; аттачменты игры (пояс, ножны дисплеев)
        -- растягиваем вместе с частью
        local ratio=new.Size/real.Size
        for _,a in ipairs(real:GetChildren()) do
            if isRigPoint(a) then
                local src=new:FindFirstChild(a.Name)
                local cf=(src and isRigPoint(src)) and src.CFrame or CFrame.new(a.CFrame.Position*ratio)*a.CFrame.Rotation
                entry.Attachments[a]={Original=a.CFrame,Applied=cf}
                a.CFrame=cf
            end
        end
        for _,src in ipairs(new:GetChildren()) do
            if isRigPoint(src) and not real:FindFirstChild(src.Name) then
                local c=src:Clone(); c:ClearAllChildren(); c.Parent=real; table.insert(entry.Added,c)
            end
        end
        -- Прозрачность только повышаем: часть, спрятанную другой функцией (Headless/Korblox
        -- MainScript, невидимость игры), не показываем; прозрачные куски донора (голень Korblox) держим
        real.Size=new.Size; entry.AppliedSize=real.Size
        entry.MinTransparency=new.Transparency
        real.Transparency=math.max(real.Transparency,new.Transparency); entry.AppliedTransparency=real.Transparency
        return entry
    end
    local function watchPart(ctx,body,entry)
        local p=entry.Part
        local function track(signal,fn) table.insert(entry.Connections,signal:Connect(fn)) end
        -- Сервер сменил меш на месте или убрал часть — одеваем заново;
        -- чей-то локальный скрипт сбросил только текстуру — возвращаем свою
        track(p.AncestryChanged,function() if not p.Parent then invalidateBody(ctx,body) end end)
        if entry.MeshId then
            track(p:GetPropertyChangedSignal('MeshId'),function()
                if ctx.Body==body and p.MeshId~=entry.MeshId then invalidateBody(ctx,body) end
            end)
            track(p:GetPropertyChangedSignal('TextureID'),function()
                if ctx.Body==body and p.MeshId==entry.MeshId and p.TextureID~=entry.AppliedTexture then p.TextureID=entry.AppliedTexture end
            end)
        end
        track(p:GetPropertyChangedSignal('Transparency'),function()
            if ctx.Body==body and p.Transparency<entry.MinTransparency-1e-3 then p.Transparency=entry.MinTransparency end
        end)
        -- Новое в части: внешний вид с сервера прячем под примеркой, аттачменты игры растягиваем
        track(p.ChildAdded,function(o)
            task.defer(function()
                if ctx.Body~=body or o.Parent~=p or table.find(entry.Added,o) or entry.Attachments[o] then return end
                if isAppearance(o) and not (entry.KeepFace and o:IsA('Decal')) then
                    entry.Hidden[o]=p; o.Parent=nil
                elseif isRigPoint(o) then
                    local cf=CFrame.new(o.CFrame.Position*entry.AppliedSize/entry.Size)*o.CFrame.Rotation
                    entry.Attachments[o]={Original=o.CFrame,Applied=cf}; o.CFrame=cf
                end
            end)
        end)
    end
    local function applyParts(ctx,ch,parts,hipHeight,rootCF)
        -- Несовместимую сборку отвергаем до изменений: половина тела хуже отказа
        for name,new in pairs(parts) do
            local real=ch:FindFirstChild(name)
            if real and real:IsA('MeshPart') and not new:IsA('MeshPart') then error('Roblox returned an incompatible '..name,0) end
        end
        local body=bodyState(ctx,ch)
        local touched={}
        for name,new in pairs(parts) do
            local real=ch:FindFirstChild(name)
            if real and real:IsA('BasePart') then
                if body.Parts[name] then revertPart(body.Parts[name]) end
                local ok,result=pcall(applyPart,body,real,new)
                touched[real]=true
                if not ok then new:Destroy(); fixRig(ctx,ch,touched); error(result,0) end
                watchPart(ctx,body,result)
            end
            new:Destroy()
        end
        fixRig(ctx,ch,touched)
        if hipHeight and body.Humanoid then body.Humanoid.HipHeight=hipHeight; body.AppliedHip=body.Humanoid.HipHeight end
        if rootCF and body.RootAttachment then body.RootAttachment.CFrame=rootCF; body.AppliedRoot=rootCF end
        watchBody(ctx,ch,body)
    end
    restoreBody=function(ctx)
        local body=ctx.Body
        if not body then return end
        ctx.Body=nil
        for _,c in ipairs(body.Connections) do c:Disconnect() end
        for _,m in ipairs(body.Meshes) do if m.Parent then m:Destroy() end end
        restoreHidden(function(o) return o:IsA('CharacterMesh') end,ctx)
        local touched={}
        for _,entry in pairs(body.Parts) do revertPart(entry); touched[entry.Part]=true end
        local ch=body.Character
        if ch and ch.Parent then
            fixRig(ctx,ch,touched)
            -- Высоту бёдер и корень, выставленные сервером после примерки, не трогаем
            local h,ra=body.Humanoid,body.RootAttachment
            if h and body.AppliedHip and near(h.HipHeight,body.AppliedHip) then h.HipHeight=body.HipHeight end
            if ra and body.AppliedRoot and near(ra.CFrame,body.AppliedRoot) then ra.CFrame=body.RootCF end
        end
    end
    -- Надеть части тела пачкой: одна модель Roblox на все слоты, как у ApplyDescription.
    -- entries = {{Id,Kind,Name}}; на R6 руки/ноги/торс — это CharacterMesh, голова — часть
    wearBody=function(ctx,ch,entries,active)
        local humanoid=ch:FindFirstChildOfClass('Humanoid')
        assert(humanoid,'Character is still loading')
        local description,_,rig=bodyContext(ch,ctx)
        local r6=rig==Enum.HumanoidRigType.R6
        local slots={}
        for _,e in ipairs(entries) do
            local slot=bodySlots[e.Kind]
            assert(slot,'Not a body part')
            slots[slot]=e; description[slot]=e.Id
        end
        local keyParts={'body',rig.Name}
        for _,prop in ipairs(bodyProperties) do table.insert(keyParts,tostring(description[prop])) end
        local names={}; for slot in pairs(slots) do table.insert(names,slot) end; table.sort(names)
        table.insert(keyParts,table.concat(names,','))
        local key=table.concat(keyParts,':')
        local cached=app.Cache[key]
        if not cached then
            local model,template
            local ok,err=pcall(function()
                model=apiCall(network.Avatar,function() return Players:CreateHumanoidModelFromDescriptionAsync(description,rig) end,active,0.35)
                template=Instance.new('Model')
                for slot in pairs(slots) do
                    if r6 and slot~='Head' then
                        for _,m in ipairs(model:GetChildren()) do
                            if m:IsA('CharacterMesh') and m.BodyPart==Enum.BodyPart[slot] then m.Parent=template end
                        end
                    else
                        for _,name in ipairs(slotParts[slot]) do
                            local part=model:FindFirstChild(name)
                            assert(part and part:IsA('BasePart'),'Roblox did not return '..name)
                            part.Parent=template
                        end
                    end
                end
                for _,o in ipairs(template:QueryDescendants('JointInstance, Constraint, WeldConstraint, LuaSourceContainer')) do o:Destroy() end
                local root=model:FindFirstChild('HumanoidRootPart')
                local ra=root and root:FindFirstChild('RootRigAttachment')
                local h=model:FindFirstChildOfClass('Humanoid')
                template.Archivable=true
                cached={Template=template,Kind='Body',BodyKey=key,HipHeight=h and h.HipHeight,RootCF=ra and ra:IsA('Attachment') and ra.CFrame or nil}
            end)
            if model then model:Destroy() end
            if not ok then if template then template:Destroy() end; description:Destroy(); error(err,0) end
            app.Cache[key]=cached
        end
        description:Destroy()
        assert(active(),'Operation cancelled')

        -- Прежние части в тех же слотах заменяются новыми
        for id,item in pairs(ctx.Items) do
            if item.Slot and slots[item.Slot] and slots[item.Slot].Id~=id then
                destroyItem(id,ctx)
                if ctx.Desired then ctx.Desired[id]=nil end
            end
        end
        local clone=cached.Template:Clone()
        local parts,meshes={},{}
        for _,o in ipairs(clone:GetChildren()) do
            if o:IsA('BasePart') then parts[o.Name]=o; o.Parent=nil
            elseif o:IsA('CharacterMesh') then meshes[o.BodyPart.Name]=o end
        end
        local body=bodyState(ctx,ch)
        if r6 then for slot in pairs(slots) do if slot~='Head' then
            for _,o in ipairs(ch:GetChildren()) do
                if o:IsA('CharacterMesh') and o.BodyPart==Enum.BodyPart[slot] and not table.find(body.Meshes,o) then hide(o,ctx) end
            end
            local mesh=meshes[slot]
            if mesh then mesh.Parent=ch; table.insert(body.Meshes,mesh) end
        end end end
        if next(parts) then applyParts(ctx,ch,parts,not r6 and cached.HipHeight or nil,not r6 and cached.RootCF or nil) end
        watchBody(ctx,ch,body)
        clone:Destroy()
        local items={}
        for slot,e in pairs(slots) do
            local limbMesh=r6 and slot~='Head'
            local it={Id=e.Id,Name=e.Name,Kind=e.Kind,Slot=slot,R6Mesh=limbMesh or nil,
                Object=limbMesh and meshes[slot] or ch:FindFirstChild(slotParts[slot][1])}
            ctx.Items[e.Id]=it; table.insert(items,it)
        end
        return items
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- Анимации (паки, настроение динамической головы)
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Скрипт Animate персонажа слушает свои StringValue: меняем их содержимое, и он сам
    -- перезагружает набор. Анимации своего персонажа реплицирует Animator — их видят все,
    -- поэтому чужим персонажам паки не применяем
    local function animationTemplate(id,info)
        local cached=app.Cache[id]
        if cached then return cached end
        local objects=game:GetObjects('rbxassetid://'..string.format('%.0f',id))
        local chosen
        for _,root in ipairs(objects) do
            if not chosen and #root:QueryDescendants('Animation')>0 then chosen=root else root:Destroy() end
        end
        assert(chosen,'Roblox did not return animations for this ID')
        for _,s in ipairs(chosen:QueryDescendants('LuaSourceContainer')) do s:Destroy() end
        chosen.Archivable=true
        cached={Template=chosen,Kind=info.Kind,Name=info.Name}
        app.Cache[id]=cached
        return cached
    end
    local function applyAnimationSets(ch,it,template)
        local animate=ch:FindFirstChild('Animate')
        assert(animate,'Character has no Animate script')
        app.AnimOriginals=app.AnimOriginals or {}
        local sets=template:IsA('StringValue') and {template} or template:GetChildren()
        local applied=0
        for _,value in ipairs(sets) do
            local slot=value:IsA('StringValue') and animate:FindFirstChild(value.Name)
            if slot and slot:IsA('StringValue') then
                local saved=app.AnimOriginals[value.Name]
                if not saved or saved.Slot~=slot then
                    saved={Slot=slot,Children=slot:GetChildren()}
                    app.AnimOriginals[value.Name]=saved
                    for _,c in ipairs(saved.Children) do c.Parent=nil end
                else
                    slot:ClearAllChildren()
                end
                for _,c in ipairs(value:GetChildren()) do c:Clone().Parent=slot end
                applied+=1
            end
        end
        assert(applied>0,'This animation does not fit the character')
    end
    restoreAnimations=function(ctx)
        if ctx~=app or not app.AnimOriginals then return end
        for _,saved in pairs(app.AnimOriginals) do
            if saved.Slot.Parent then
                saved.Slot:ClearAllChildren()
                for _,c in ipairs(saved.Children) do c.Parent=saved.Slot end
            else
                for _,c in ipairs(saved.Children) do c:Destroy() end
            end
        end
        app.AnimOriginals=nil
    end
    -- Все надетые анимации заново поверх исходного Animate: снятие одной не ломает остальные
    local function reapplyAnimations(ch)
        restoreAnimations(app)
        local ids={}
        for id,it in pairs(app.Items) do if it.Animation then table.insert(ids,id) end end
        table.sort(ids)
        for _,id in ipairs(ids) do
            local cached=app.Cache[id]
            if cached then pcall(applyAnimationSets,ch,app.Items[id],cached.Template) end
        end
    end
    local function wearAnimation(ch,id,info)
        local cached=animationTemplate(id,info)
        for key,item in pairs(app.Items) do
            if item.Animation and item.Kind==info.Kind and key~=id then app.Items[key]=nil; app.Desired[key]=nil end
        end
        app.Items[id]=nil
        reapplyAnimations(ch)
        local it={Id=id,Name=cached.Name,Kind=info.Kind,Animation=true}
        applyAnimationSets(ch,it,cached.Template)
        app.Items[id]=it
        return it
    end

    -- Примерка любого поддерживаемого ассета: части тела, анимации, аксессуары, одежда, макияж
    local function wearAny(ctx,ch,id,hint,active)
        local info=itemMetadata(id,hint,active)
        assert(supportedKind(info.Kind),'Unsupported item type')
        if bodySlots[info.Kind] then
            return wearBody(ctx,ch,{{Id=id,Kind=info.Kind,Name=info.Name}},active)[1],{Name=info.Name}
        end
        if animationKinds[info.Kind] then
            assert(ctx==app,'Animations are applied only to your character')
            return wearAnimation(ch,id,info),{Name=info.Name}
        end
        return wearOn(ctx,ch,id,hint,active)
    end

    function app.WearAsync(rawId,expectedRevision,hint)
        local id=type(rawId)=='number' and rawId or tonumber(tostring(rawId):match('^%s*(%d+)%s*$') or tostring(rawId):match('/catalog/(%d+)'))
        assert(id and id>0 and id%1==0,'Enter an asset ID or a catalog link')
        local ch=current(); local rev=expectedRevision or app.Revision
        assert(valid(rev,ch),'Operation cancelled')
        local existing=app.Items[id]
        if existing and (not existing.Object or existing.Object.Parent) then return 'Item is already equipped' end

        local it,cached=wearAny(app,ch,id,hint,function() return valid(rev,ch) end)
        local previous=app.Desired[id] and app.Desired[id].Transform
        app.Desired[id]={Id=id,Name=cached.Name,Kind=it.Kind,LayerOrder=it.LayerOrder}
        if it.Weld and not cached.Layered then app.SetTransform(id,previous or defaultTransform()) end
        refresh(); return 'Equipped: '..cached.Name
    end
    -- Несколько частей тела одной сборкой (бандлы, сохранённые образы)
    function app.WearBodyAsync(entries,expectedRevision)
        local ch=current(); local rev=expectedRevision or app.Revision
        assert(valid(rev,ch),'Operation cancelled')
        local items=wearBody(app,ch,entries,function() return valid(rev,ch) end)
        for _,it in ipairs(items) do app.Desired[it.Id]={Id=it.Id,Name=it.Name,Kind=it.Kind} end
        refresh()
        return items
    end
    -- Снять один предмет или список. Часть тела снимается откатом тела и повторной сборкой
    -- оставшихся частей, поэтому вызов может ждать сеть — зовём из run()
    function app.Remove(target,expectedRevision)
        local ids=type(target)=='table' and target or {target}
        local names,bodyChanged,animationChanged={},false,false
        for _,id in ipairs(ids) do
            if app.EditingId==id and app.CloseTransform then app.CloseTransform(false) end
            local item=app.Items[id] or app.Desired[id]
            if item then
                local live=app.Items[id]
                if live and live.Slot then bodyChanged=true elseif live and live.Animation then animationChanged=true end
                destroyItem(id); app.Desired[id]=nil
                if clothing[item.Kind] and not (app.HideOriginal and item.Kind~=18) then
                    restoreHidden(function(o) return o:IsA(clothing[item.Kind]) end)
                end
                table.insert(names,item.Name)
            end
        end
        local ch=player.Character
        if animationChanged and ch then reapplyAnimations(ch) end
        if bodyChanged then
            local remaining={}
            for id,it in pairs(app.Items) do if it.Slot then table.insert(remaining,{Id=id,Kind=it.Kind,Name=it.Name}) end end
            for _,e in ipairs(remaining) do app.Items[e.Id]=nil end
            restoreBody(app)
            if #remaining>0 and ch then
                local rev=expectedRevision or app.Revision
                local ok,err=pcall(wearBody,app,ch,remaining,function() return valid(rev,ch) end)
                if not ok then refresh(); error(err,0) end
            end
        end
        refresh()
        if #names>0 then message('Removed: '..table.concat(names,', ')) end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- Бандлы
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Как TryBundle оригинального каталога: надеваются ассеты из BundledItems (части тела,
    -- голова, аксессуары, обувь, анимации); UserOutfit и неподдерживаемое пропускаем
    bundleDetails=function(id,hint,active)
        local cached=network.Bundles[id]
        if cached then return cached end
        local details=(type(hint)=='table' and type(hint.BundledItems)=='table') and hint
            or apiCall(network.Avatar,function() return AES:GetItemDetails(id,Enum.AvatarItemType.Bundle) end,active,0.35)
        local assets={}
        for _,entry in ipairs(details.BundledItems or {}) do
            local assetId=tonumber(entry.Id)
            local kind=entry.Type=='Asset' and kindFromHint({AssetType=entry.AssetType})
            if assetId and kind and supportedKind(kind) then
                local name=safeText(entry.Name or ('ID '..string.format('%.0f',assetId)))
                table.insert(assets,{Id=assetId,Kind=kind,Name=name,AssetType=entry.AssetType})
                network.Metadata[assetId]=network.Metadata[assetId] or {Kind=kind,Name=name}
            end
        end
        local result={Id=id,Name=safeText(details.Name or ('Bundle '..string.format('%.0f',id))),Assets=assets}
        network.Bundles[id]=result
        return result
    end
    function app.BundleWorn(id)
        local bundle=network.Bundles[id]
        if not bundle or #bundle.Assets==0 then return false end
        for _,a in ipairs(bundle.Assets) do if not app.Items[a.Id] then return false end end
        return true
    end
    function app.WearBundleAsync(rawId,expectedRevision,hint)
        local id=type(rawId)=='number' and rawId or tonumber(tostring(rawId):match('^%s*(%d+)%s*$') or tostring(rawId):match('bundles?/(%d+)'))
        assert(id and id>0 and id%1==0,'Enter a bundle ID or a bundle link')
        local ch=current(); local rev=expectedRevision or app.Revision
        local function active() return valid(rev,ch) end
        assert(active(),'Operation cancelled')
        local bundle=bundleDetails(id,hint,active)
        assert(#bundle.Assets>0,'This bundle has no items that can be worn')
        local body,rest,failed={},{},{}
        for _,a in ipairs(bundle.Assets) do
            if bodySlots[a.Kind] then table.insert(body,{Id=a.Id,Kind=a.Kind,Name=a.Name}) else table.insert(rest,a) end
        end
        -- Сначала тело: аксессуары бандла садятся уже на его части
        if #body>0 then
            local ok,err=pcall(app.WearBodyAsync,body,rev)
            if not ok then
                if not active() then error(err,0) end
                for _,a in ipairs(body) do table.insert(failed,a.Name) end
            end
        end
        for _,a in ipairs(rest) do
            assert(active(),'Operation cancelled')
            local ok=pcall(app.WearAsync,a.Id,rev,{Name=a.Name,AssetType=a.AssetType})
            if not ok then
                if not active() then error('Operation cancelled',0) end
                table.insert(failed,a.Name)
            end
        end
        refresh()
        if #failed>0 then return 'Equipped '..bundle.Name..'. Not loaded: '..table.concat(failed,', ') end
        return 'Equipped: '..bundle.Name
    end
    function app.RemoveBundle(id,expectedRevision)
        local bundle=network.Bundles[id]
        if not bundle then return end
        local ids={}
        for _,a in ipairs(bundle.Assets) do if app.Items[a.Id] or app.Desired[a.Id] then table.insert(ids,a.Id) end end
        app.Remove(ids,expectedRevision)
    end
end
function app.MoveMakeupLayer(id,direction)
    local ordered={}
    for _,it in pairs(app.Items) do if makeup[it.Kind] then table.insert(ordered,it) end end
    table.sort(ordered,function(a,b)
        if (a.LayerOrder or 0)==(b.LayerOrder or 0) then return a.Id<b.Id end
        return (a.LayerOrder or 0)<(b.LayerOrder or 0)
    end)
    for index,it in ipairs(ordered) do if it.Id==id then
        local other=ordered[index+(direction>0 and 1 or -1)]
        if not other then return end
        local first,second=it.LayerOrder or index,other.LayerOrder or index+1
        if first==second then second=first+1 end
        it.LayerOrder=second; other.LayerOrder=first
        it.Object.ZIndex=second; other.Object.ZIndex=first
        app.Desired[it.Id].LayerOrder=second; app.Desired[other.Id].LayerOrder=first
        refresh(); return
    end end
end
local storageProblems={}
local function readDocument(path)
    if type(readfile)~='function' then return nil,false end
    local exists=type(isfile)=='function' and isfile(path)
    local ok,raw=pcall(readfile,path)
    if not ok and not exists then return nil,false end
    local parsed,data=false,nil
    if ok then parsed,data=pcall(Http.JSONDecode,Http,raw) end
    if parsed and type(data)=='table' then return data,true end
    local backupOk,backup=pcall(function() return Http:JSONDecode(readfile(path..'.bak')) end)
    if backupOk and type(backup)=='table' then return backup,true end
    storageProblems[path]=true
    return nil,true
end
local function writeDocument(path,data)
    assert(type(writefile)=='function','Your executor does not support saving files')
    assert(not storageProblems[path],'File '..path..' is corrupted and has not been overwritten')
    local encoded=Http:JSONEncode(data)
    local previous
    if type(readfile)=='function' then
        local ok,raw=pcall(readfile,path)
        if ok then
            local validJson=pcall(Http.JSONDecode,Http,raw)
            if validJson then previous=raw; writefile(path..'.bak',raw) end
        end
    end
    local ok,err=pcall(function()
        writefile(path,encoded)
        if type(readfile)=='function' then assert(readfile(path)==encoded,'Could not verify the saved file') end
    end)
    if not ok then if previous then pcall(writefile,path,previous) end; error(err,0) end
end
local function saveSettings()
    if type(writefile)=='function' then
        local ok=pcall(writeDocument,SETTINGS,{KeepOnRespawn=app.KeepOnRespawn,Window=app.Window})
        return ok
    end
    return false
end
if type(readfile)=='function' then
    pcall(function()
        local s=readDocument(SETTINGS)
        if s and type(s.KeepOnRespawn)=='boolean' then app.KeepOnRespawn=s.KeepOnRespawn end
        if s and type(s.Window)=='table' then
            for field,bounds in pairs({Width={1000,1900},Height={680,1100},Scale={0.6,1.6}}) do
                local n=tonumber(s.Window[field])
                if n and n==n then app.Window[field]=math.clamp(n,bounds[1],bounds[2]) end
            end
        end
    end)
end
local SavedOutfits={}
local SavedItems={}
local function saveOutfitLibrary()
    assert(type(writefile)=='function','Your executor does not support saving files')
    writeDocument(OUTFITS,{Version=1,Outfits=SavedOutfits})
end
local function saveFavoriteLibrary()
    assert(type(writefile)=='function','Your executor does not support saving files')
    local items={}
    for _,entry in pairs(SavedItems) do table.insert(items,entry) end
    table.sort(items,function(a,b) return (a.Name or '')<(b.Name or '') end)
    writeDocument(FAVORITES,{Version=1,Items=items})
end
local function normalizeFavorite(entry)
    if type(entry)~='table' then return nil end
    local id=tonumber(entry.Id)
    if not id or id<=0 or id%1~=0 then return nil end
    local assetType=entry.AssetType
    if typeof and typeof(assetType)=='EnumItem' then assetType=assetType.Name end
    if type(assetType)~='string' or assetType=='' then assetType=nil end
    -- Translate legacy storage keys without renaming user outfits or asset titles.
    local legacyGroups={['Аксессуары']='Accessories',['Волосы']='Hair',['Одежда']='Clothing'}
    local group=legacyGroups[entry.Group] or safeText(entry.Group or '')
    if group=='' or group=='Untitled' then return nil end
    local subName=entry.Sub and safeText(entry.Sub) or nil
    if subName=='Untitled' then subName=nil end
    return {Id=id,Name=safeText(entry.Name or ('ID '..string.format('%.0f',id))),AssetType=assetType,Group=group,Sub=subName}
end
local function loadFavoriteLibrary()
    if type(readfile)~='function' then return end
    pcall(function()
        local root=readDocument(FAVORITES)
        local source=type(root)=='table' and (root.Items or root) or {}
        for _,entry in ipairs(source) do
            local normalized=normalizeFavorite(entry)
            if normalized then SavedItems[normalized.Id]=normalized end
        end
    end)
end
local function isFavorite(id) return SavedItems[tonumber(id)]~=nil end
local function normalizeSavedOutfit(entry,index)
    if type(entry)~='table' or type(entry.Data)~='table' then return nil end
    local data=entry.Data
    if type(data.AssetIds)~='table' then return nil end
    for _,id in ipairs(data.AssetIds) do
        if type(id)~='number' or id<=0 or id%1~=0 or id>9007199254740991 then return nil end
    end
    if data.Items~=nil and type(data.Items)~='table' then return nil end
    if data.Transforms~=nil and type(data.Transforms)~='table' then return nil end
    for _,transform in pairs(data.Transforms or {}) do
        if type(transform)~='table' or not pcall(normalizedTransform,transform) then return nil end
    end
    return {
        Id=tostring(entry.Id or ('outfit-'..tostring(index))),
        Name=safeText(entry.Name or ('Outfit '..tostring(index))),
        Data=data
    }
end
local function loadOutfitLibrary()
    if type(readfile)~='function' then return end
    local existed=false
    pcall(function()
        local root; root,existed=readDocument(OUTFITS)
        local source=type(root)=='table' and (root.Outfits or root) or {}
        for i,entry in ipairs(source) do
            local normalized=normalizeSavedOutfit(entry,i)
            if normalized then table.insert(SavedOutfits,normalized) end
        end
    end)
    -- One-time compatibility with the old single-save file.
    if not existed then
        pcall(function()
            local data=Http:JSONDecode(readfile(LEGACY_SAVE))
            if type(data)=='table' and type(data.AssetIds)=='table' then
                table.insert(SavedOutfits,{Id=Http:GenerateGUID(false),Name='Imported outfit',Data=data})
                if type(writefile)=='function' then pcall(saveOutfitLibrary) end
            end
        end)
    end
end
loadOutfitLibrary()
loadFavoriteLibrary()
app.SavedItems=SavedItems
app.SavedOutfits=SavedOutfits
local function outfitName(name)
    local value=safeText(name)
    assert(value~='Untitled','Enter an outfit name')
    local stop=utf8.offset(value,49)
    return stop and value:sub(1,stop-1) or value
end
function app.SaveOutfit(name,data)
    local entry={Id=Http:GenerateGUID(false),Name=outfitName(name),Data=data or app.ExportOutfit()}
    assert(normalizeSavedOutfit(entry,1),'Invalid outfit')
    entry.Data=Http:JSONDecode(Http:JSONEncode(entry.Data))
    table.insert(SavedOutfits,entry)
    local ok,err=pcall(saveOutfitLibrary)
    if not ok then table.remove(SavedOutfits,#SavedOutfits); error(err,0) end
    return entry
end
function app.RenameOutfit(id,name)
    for _,entry in ipairs(SavedOutfits) do if entry.Id==id then
        local old=entry.Name; entry.Name=outfitName(name)
        local ok,err=pcall(saveOutfitLibrary)
        if not ok then entry.Name=old; error(err,0) end
        return entry
    end end
    error('Outfit not found')
end
function app.OverwriteOutfit(id,data)
    for _,entry in ipairs(SavedOutfits) do if entry.Id==id then
        local replacement=Http:JSONDecode(Http:JSONEncode(data or app.ExportOutfit()))
        assert(normalizeSavedOutfit({Id=entry.Id,Name=entry.Name,Data=replacement},1),'Invalid outfit')
        local previous=entry.Data; entry.Data=replacement
        local ok,err=pcall(saveOutfitLibrary)
        if not ok then entry.Data=previous; error(err,0) end
        return entry
    end end
    error('Outfit not found')
end
function app.DeleteOutfit(id)
    for index,entry in ipairs(SavedOutfits) do if entry.Id==id then
        table.remove(SavedOutfits,index)
        local ok,err=pcall(saveOutfitLibrary)
        if not ok then table.insert(SavedOutfits,index,entry); error(err,0) end
        return
    end end
end
function app.SetKeepOnRespawn(value)
    app.KeepOnRespawn=value==true
    -- Disabling during restoration cancels pending work and leaves the original character.
    if not app.KeepOnRespawn and app.Restoring then app.Reset() end
    local persisted=saveSettings()
    refresh()
    message((app.KeepOnRespawn and 'Your outfit will be restored after respawn' or 'Respawn will use the original appearance')..
        (persisted and '' or ' (this session only)'))
end
local function applyOutfit(data,rev)
    local failed,hints={},{}
    for _,item in ipairs(data.Items or {}) do if item.Id then hints[item.Id]=item end end
    if data.HideOriginal then app.SetHideOriginal(true) end
    local function active() return app.Alive and app.Revision==rev end
    for _,id in ipairs(data.AssetIds) do
        if not app.Desired[id] then
            local hint=hints[id] or {}
            app.Desired[id]={Id=id,Name=hint.Name or ('ID '..string.format('%.0f',id)),Kind=kindFromHint(hint),LayerOrder=hint.LayerOrder,
                Transform=data.Transforms and data.Transforms[string.format('%.0f',id)]}
        end
    end
    -- Части тела — одной сборкой и до аксессуаров, чтобы те сели уже на новое тело
    local body,rest={},{}
    for _,id in ipairs(data.AssetIds) do
        if not active() then return nil end
        local ok,info=pcall(itemMetadata,id,hints[id],active)
        if ok and bodySlots[info.Kind] then table.insert(body,{Id=id,Kind=info.Kind,Name=info.Name}) else table.insert(rest,id) end
    end
    if #body>0 then
        local ok=pcall(app.WearBodyAsync,body,rev)
        if not active() then return nil end
        if not ok then for _,e in ipairs(body) do table.insert(failed,string.format('%.0f',e.Id)) end end
    end
    for _,id in ipairs(rest) do
        if not active() then return nil end
        local ok=pcall(function()
            app.WearAsync(id,rev,hints[id])
            local transform=data.Transforms and data.Transforms[string.format('%.0f',id)]
            local equipped=app.Items[id]
            if transform and equipped and equipped.Weld and not equipped.Layered then app.SetTransform(id,transform) end
        end)
        if not ok then table.insert(failed,string.format('%.0f',id)) end
    end
    refresh()
    return failed
end
-- One generation per spawn: old downloads and delayed callbacks cannot dress a new character.
-- keep=true — тот же персонаж пересобран сервером: образ надеваем заново независимо от настройки
function app.HandleCharacterAdded(ch,keep)
    if not app.Alive then return end
    app.Revision+=1
    local rev=app.Revision
    clearVisuals(); app.Busy=false
    if not app.KeepOnRespawn and not keep then
        app.Desired={}; app.HideOriginal=false; app.Restoring=false
        refresh(); message('Respawn: original appearance kept'); return
    end
    local outfit=app.ExportOutfit()
    if #outfit.AssetIds==0 and not outfit.HideOriginal then app.Restoring=false; refresh(); return end
    app.Restoring=true; refresh(); message(keep and 'Body changed by the game: re-applying outfit...' or 'Respawn: waiting for appearance...')
    task.spawn(function()
        local started=os.clock()
        while valid(rev,ch) and (not ch.Parent or not ch:FindFirstChildOfClass('Humanoid') or not ch:FindFirstChild('Head')) do
            if os.clock()-started>15 then
                app.Restoring=false; refresh(); message('Character did not load. Click Retry',true); return
            end
            task.wait(0.1)
        end
        if not valid(rev,ch) then return end
        while valid(rev,ch) and not player:HasAppearanceLoaded() and os.clock()-started<10 do task.wait(0.15) end
        -- Give server clothing/attachments time to settle, also for custom character loaders.
        task.wait(0.65)
        if not valid(rev,ch) then return end
        local ok,failed=pcall(applyOutfit,outfit,rev)
        if not valid(rev,ch) then return end
        app.Restoring=false; refresh()
        if not ok then message('Could not restore outfit. Click Retry',true)
        elseif failed and #failed>0 then message('Could not equip: '..table.concat(failed,', ')..'. Click Retry',true)
        else message(keep and 'Outfit re-applied' or 'Outfit restored after respawn') end
    end)
end
app.OnBodyInvalid=function(ch)
    if app.Alive and ch==player.Character then app.HandleCharacterAdded(ch,true) end
end
local C={Bg=Color3.fromRGB(28,29,32),Surface=Color3.fromRGB(36,38,41),Card=Color3.fromRGB(47,49,53),
    Muted=Color3.fromRGB(170,174,182),Text=Color3.fromRGB(245,246,248),Accent=Color3.fromRGB(65,111,85),
    Green=Color3.fromRGB(58,111,82),Border=Color3.fromRGB(67,70,76)}
local gui=make('ScreenGui',{Name='LocalCatalog',ResetOnSpawn=false,DisplayOrder=1000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild('PlayerGui'))
app.Gui=gui
local panel=make('Frame',{Name='Panel',Size=UDim2.fromOffset(1100,736),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=C.Bg,BorderSizePixel=0},gui)
panel.Visible=carryVisible~=false
corner(panel,14)
make('UIStroke',{Color=C.Border,Thickness=1},panel)
local scale=make('UIScale',{Scale=1},panel)
local function fit()
    local cam=workspace.CurrentCamera
    if cam then
        scale.Scale=math.max(0.2,math.min(app.Window.Scale,(cam.ViewportSize.X-32)/app.Window.Width,(cam.ViewportSize.Y-80)/app.Window.Height))
        local half=Vector2.new(app.Window.Width,app.Window.Height)*scale.Scale/2
        local p=panel.Position
        panel.Position=UDim2.fromOffset(
            math.clamp(p.X.Scale*cam.ViewportSize.X+p.X.Offset,half.X+16,math.max(half.X+16,cam.ViewportSize.X-half.X-16)),
            math.clamp(p.Y.Scale*cam.ViewportSize.Y+p.Y.Offset,half.Y+20,math.max(half.Y+20,cam.ViewportSize.Y-half.Y-60)))
        if app.ModalGui then for _,s in ipairs(app.ModalGui:QueryDescendants('UIScale')) do s.Scale=scale.Scale end end
    end
end
fit()
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then cameraConnection=connect(workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'),fit) end
    fit()
end
bindCamera(); connect(workspace:GetPropertyChangedSignal('CurrentCamera'),bindCamera)
local function label(text,x,y,w,h,parent,size)
    return make('TextLabel',{Text=text=='' and '' or safeText(text),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,TextColor3=C.Text,Font=Enum.Font.SourceSans,TextSize=size or 18,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent or panel)
end
local function button(text,x,y,w,h,fn,parent,accent)
    local b=make('TextButton',{Text=text=='' and '' or safeText(text),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=accent and C.Accent or C.Card,TextColor3=C.Text,Font=Enum.Font.SourceSansSemibold,
        TextSize=18,BorderSizePixel=0,AutoButtonColor=true},parent or panel)
    corner(b); if fn then b.Activated:Connect(fn) end; return b
end
local function input(placeholder,x,y,w,h)
    local b=make('TextBox',{Text='',PlaceholderText=placeholder,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.Surface,TextColor3=C.Text,PlaceholderColor3=C.Muted,Font=Enum.Font.SourceSans,TextSize=18,
        ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},panel)
    corner(b); make('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,10)},b); return b
end
local function run(fn)
    if app.Busy or app.Restoring then message('Please wait while items are equipped...'); return end
    app.Busy=true; local rev=app.Revision; if updateControls then updateControls() end; message('Loading item...')
    task.spawn(function()
        local ok,result=pcall(fn,rev)
        if not app.Alive or rev~=app.Revision then return end
        app.Busy=false; refresh()
        message(ok and (result or 'Done') or ('Failed: '..tostring(result)),not ok)
    end)
end
local title=label('Catalog',22,10,140,36,nil,28)
title.Font=Enum.Font.SourceSansBold; title.Active=true
label('Local avatar editor',170,15,220,26,nil,16).TextColor3=C.Muted
button('Minimize',890,14,102,34,function() if app.CloseDialogs then app.CloseDialogs() end; panel.Visible=false end)
button('Close',1000,14,78,34,function() app.Unload() end)
local toggle=button('Catalog',14,130,116,40,function() if app.ToggleWindow then app.ToggleWindow() else panel.Visible=not panel.Visible end end,gui,true)
local dragStart,dragPosition,dragTouch
local dragHeader=make('Frame',{Name='DragHeader',Size=UDim2.new(1,0,0,54),BackgroundTransparency=1,Active=true,ZIndex=3},panel)
connect(dragHeader.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragStart=i.Position; dragPosition=panel.Position; dragTouch=i.UserInputType==Enum.UserInputType.Touch and i or nil
    end
end)
connect(UIS.InputChanged,function(i)
    if dragStart and ((dragTouch and i==dragTouch) or (not dragTouch and i.UserInputType==Enum.UserInputType.MouseMovement)) then
        local d=i.Position-dragStart
        local viewport=workspace.CurrentCamera.ViewportSize
        local x=math.clamp(dragPosition.X.Scale*viewport.X+dragPosition.X.Offset+d.X,100,viewport.X-100)
        local y=math.clamp(dragPosition.Y.Scale*viewport.Y+dragPosition.Y.Offset+d.Y,20+app.Window.Height*scale.Scale/2,viewport.Y-40)
        panel.Position=UDim2.fromOffset(x,y)
    end
end)
connect(UIS.InputEnded,function(i)
    if i==dragTouch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragStart=nil; dragTouch=nil end
end)
local query=input('Search catalog',20,106,452,40)
query.Name='SearchInput'
local searchButton=button('Search',480,106,90,40,nil,nil,true)
searchButton.Name='SearchButton'
local optionsButton=button('Search Options',578,106,198,40,nil)
optionsButton.Name='SearchOptions'
local rigid={'Hat','FaceAccessory','NeckAccessory','ShoulderAccessory','FrontAccessory','BackAccessory','WaistAccessory'}
local layered={'TShirtAccessory','ShirtAccessory','PantsAccessory','JacketAccessory','SweaterAccessory','ShortsAccessory','LeftShoeAccessory','RightShoeAccessory','DressSkirtAccessory'}
local classic={'TShirt','Shirt','Pants'}
local allClothes=table.clone(layered); for _,v in ipairs(classic) do table.insert(allClothes,v) end
local makeupTypes={'EyeMakeup','LipMakeup','FaceMakeup','EyelashAccessory','EyebrowAccessory'}
local collectibleAccessories=table.clone(rigid)
for _,v in ipairs({'HairAccessory','EyebrowAccessory','EyelashAccessory'}) do table.insert(collectibleAccessories,v) end
local wearableTypes=table.clone(collectibleAccessories)
for _,v in ipairs(allClothes) do table.insert(wearableTypes,v) end
for _,v in ipairs({'EyeMakeup','LipMakeup','FaceMakeup','Face'}) do table.insert(wearableTypes,v) end
local handheld=table.clone(layered); table.insert(handheld,'ShoulderAccessory')
-- Поиск бандлов: AssetTypes пустой, BundleTypes задан — как в оригинальном каталоге.
-- Sort — сортировка оригинала по умолчанию (части тела — по избранному)
local function sub(name,types,keyword,free,bundleTypes,sort)
    return {Name=name,Types=types or {},Keyword=keyword,Free=free,BundleTypes=bundleTypes,Sort=sort}
end
-- Catalog Avatar Creator's wearable hierarchy; Body merges its Characters, Body and Anim Packs sections.
local categories={
    {Name='Accessories',Sub={
        sub('All',rigid),sub('Free',rigid,nil,true),sub('Hats',{'Hat'}),sub('Face',{'FaceAccessory'}),
        sub('Neck',{'NeckAccessory'}),sub('Shoulders',{'ShoulderAccessory'}),sub('Front',{'FrontAccessory'}),
        sub('Back',{'BackAccessory'}),sub('Waist',{'WaistAccessory'}),sub('Handheld',handheld,',Handheld,Holdable'),
        sub('Effects',rigid,',Filter,Aura,Confetti,Sparkles')}},
    {Name='Hair',Sub={sub('All hair',{'HairAccessory'}),sub('Free',{'HairAccessory'},nil,true),
        sub('Bangs',{'FaceAccessory'},'Hair Bangs'),sub('Extensions',rigid,',Extensions')}},
    {Name='Clothing',Sub={
        sub('Classic T-shirts',{'TShirt'}),sub('Classic shirts',{'Shirt'}),sub('Classic pants',{'Pants'}),sub('Classic',classic),
        sub('All clothing',allClothes),sub('Free',allClothes,nil,true),sub('Layered',layered),
        sub('T-shirts',{'TShirtAccessory'}),sub('Pants',{'PantsAccessory'}),sub('Jackets',{'JacketAccessory'}),
        sub('Shirts',{'ShirtAccessory'}),sub('Sweaters',{'SweaterAccessory'}),sub('Shorts',{'ShortsAccessory'}),
        sub('Dresses / skirts',{'DressSkirtAccessory'}),sub('Shoes',{'LeftShoeAccessory','RightShoeAccessory'})}},
    {Name='Body',Sub={
        sub('Characters',nil,nil,false,{'BodyParts'}),sub('Free',nil,nil,true,{'BodyParts'}),sub('Faces',nil,nil,false,{'DynamicHead'}),
        sub('Heads',{'Head','DynamicHead'},nil,false,nil,'MostFavorited'),sub('Torso',{'Torso'},nil,false,nil,'MostFavorited'),
        sub('Arms',{'LeftArm','RightArm'},nil,false,nil,'MostFavorited'),sub('Legs',{'LeftLeg','RightLeg'},nil,false,nil,'MostFavorited'),
        sub('Anim Packs',nil,nil,false,{'Animations'})}},
    {Name='Makeup',Sub={sub('All',makeupTypes),sub('Eyes',{'EyeMakeup'}),sub('Lips',{'LipMakeup'}),
        sub('Face',{'FaceMakeup'}),sub('Eyelashes',{'EyelashAccessory'}),sub('Eyebrows',{'EyebrowAccessory'})}},
    {Name='Collectibles',Sub={sub('All',wearableTypes),sub('Accessories',collectibleAccessories)}},
    {Name='Saved',SavedRoot=true},
}
for _,cat in ipairs(categories) do
    if cat.Name=='Collectibles' then for _,entry in ipairs(cat.Sub) do entry.SalesTypeFilter='Collectibles' end end
end
app.Categories=categories
local category,subcategory=1,1
local savedSection='Outfits'
local savedGroup='All'
local function avatarTypeName(value)
    if typeof and typeof(value)=='EnumItem' then return value.Name end
    if type(value)=='string' then return value end
    return nil
end
local accessoryFavoriteSub={Hat='Hats',FaceAccessory='Face',NeckAccessory='Neck',ShoulderAccessory='Shoulders',FrontAccessory='Front',BackAccessory='Back',WaistAccessory='Waist'}
local clothingFavoriteSub={TShirt='Classic T-shirts',Shirt='Classic shirts',Pants='Classic pants',TShirtAccessory='T-shirts',PantsAccessory='Pants',JacketAccessory='Jackets',ShirtAccessory='Shirts',SweaterAccessory='Sweaters',ShortsAccessory='Shorts',DressSkirtAccessory='Dresses / skirts',LeftShoeAccessory='Shoes',RightShoeAccessory='Shoes'}
local function favoritePlacement(item)
    local cat=categories[category]
    local selected=cat and cat.Sub and cat.Sub[subcategory]
    local group=cat and cat.Name or 'Accessories'
    local subName=selected and selected.Name or nil
    local assetName=avatarTypeName(item.AssetType)
    if table.find(makeupTypes,assetName) then return 'Makeup',assetName end
    local bodyFavoriteSub={Head='Heads',DynamicHead='Heads',Torso='Torso',LeftArm='Arms',RightArm='Arms',LeftLeg='Legs',RightLeg='Legs'}
    if bodyFavoriteSub[assetName] then return 'Body',bodyFavoriteSub[assetName] end
    if group=='Collectibles' then
        if table.find(allClothes,assetName) then return 'Clothing',clothingFavoriteSub[assetName] end
        if assetName=='HairAccessory' then return 'Hair',nil end
        return 'Accessories',accessoryFavoriteSub[assetName] or 'Faces'
    end
    if group=='Accessories' and (subName=='All' or subName=='Free') then subName=accessoryFavoriteSub[assetName]
    elseif group=='Hair' and (subName=='All hair' or subName=='Free') then subName=nil
    elseif group=='Clothing' and (subName=='All clothing' or subName=='Free' or subName=='Layered' or subName=='Classic') then subName=clothingFavoriteSub[assetName]
    end
    return group,subName
end
local categoryPanel=make('Frame',{Name='Categories',Position=UDim2.fromOffset(20,57),Size=UDim2.fromOffset(756,38),BackgroundTransparency=1},panel)
make('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},categoryPanel)
local subPanel=make('ScrollingFrame',{Name='Subcategories',Position=UDim2.fromOffset(52,154),Size=UDim2.fromOffset(688,40),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=3},panel)
make('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},subPanel)
do
    local left=button('<',20,154,26,32,function() subPanel.CanvasPosition=Vector2.new(math.max(0,subPanel.CanvasPosition.X-280*scale.Scale),0) end)
    local right=button('>',748,154,28,32,function()
        local maximum=math.max(0,subPanel.AbsoluteCanvasSize.X-subPanel.AbsoluteSize.X)
        subPanel.CanvasPosition=Vector2.new(math.min(maximum,subPanel.CanvasPosition.X+280*scale.Scale),0)
    end)
    left.Name='PreviousSubcategories'; right.Name='NextSubcategories'
    local function update()
        local maximum=math.max(0,subPanel.AbsoluteCanvasSize.X-subPanel.AbsoluteSize.X)
        left.Visible=maximum>1; right.Visible=maximum>1
        left.TextColor3=subPanel.CanvasPosition.X>1 and C.Text or C.Muted
        right.TextColor3=subPanel.CanvasPosition.X<maximum-1 and C.Text or C.Muted
    end
    connect(subPanel:GetPropertyChangedSignal('AbsoluteCanvasSize'),update)
    connect(subPanel:GetPropertyChangedSignal('CanvasPosition'),update)
    update()
end
local results=make('ScrollingFrame',{Name='Results',Position=UDim2.fromOffset(20,204),Size=UDim2.fromOffset(756,384),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},panel)
corner(results)
make('UIGridLayout',{CellSize=UDim2.fromOffset(180,211),CellPadding=UDim2.fromOffset(8,10),FillDirectionMaxCells=8,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},results)
make('UIPadding',{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingBottom=UDim.new(0,8)},results)
local empty=label('Loading catalog...',120,320,556,90,nil,22)
empty.Name='EmptyResults'; empty.TextXAlignment=Enum.TextXAlignment.Center; empty.TextColor3=C.Muted
local moreButton=button('Load more',20,598,756,36)
moreButton.Name='MoreButton'
local pages,resultCount,searchSerial=nil,0,0
local cardButtons={}
local favoriteButtons={}
local function clearResults()
    for _,o in ipairs(results:GetChildren()) do if o:IsA('Frame') then o:Destroy() end end
    resultCount=0; cardButtons={}; favoriteButtons={}; results.CanvasPosition=Vector2.zero
end
local renderSavedOutfits,renderSavedItems,renderCategories,filterMatch,search
local modalGui=make('ScreenGui',{Name='LocalCatalogModal',ResetOnSpawn=false,DisplayOrder=2000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild('PlayerGui'))
app.ModalGui=modalGui
local modalShade=make('TextButton',{Name='Shade',Text='',AutoButtonColor=false,Active=true,Visible=false,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0},modalGui)
local function clearModal()
    for _,o in ipairs(modalShade:GetChildren()) do o:Destroy() end
    modalShade.Visible=false
end
app.CloseDialogs=clearModal
local function modalLabel(parent,text,x,y,w,h,size) return label(text,x,y,w,h,parent,size) end
local function modalButton(parent,text,x,y,w,h,fn,accent)
    return button(text,x,y,w,h,fn,parent,accent)
end
local function openNameDialog(titleText,initialText,onDone)
    clearModal(); modalShade.Visible=true
    local boxFrame=make('Frame',{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(470,210),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},boxFrame)
    corner(boxFrame,14); make('UIStroke',{Color=C.Border,Thickness=1},boxFrame)
    local t=modalLabel(boxFrame,titleText,20,16,430,32,24); t.Font=Enum.Font.SourceSansBold
    local nameBox=make('TextBox',{Text=initialText or '',PlaceholderText='Outfit name',Position=UDim2.fromOffset(20,67),Size=UDim2.fromOffset(430,42),BackgroundColor3=C.Surface,TextColor3=C.Text,PlaceholderColor3=C.Muted,Font=Enum.Font.SourceSans,TextSize=19,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},boxFrame)
    corner(nameBox); make('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,10)},nameBox)
    local notice=modalLabel(boxFrame,'',20,112,430,25,15); notice.TextColor3=Color3.fromRGB(255,156,157)
    modalButton(boxFrame,'Cancel',20,151,205,40,clearModal,false)
    local submitted=false
    local function submit()
        if submitted then return end
        local name=safeText(nameBox.Text)
        local stop=utf8.offset(name,49); if stop then name=name:sub(1,stop-1) end
        if name=='' or name=='Untitled' then notice.Text='Enter an outfit name'; return end
        submitted=true; clearModal(); onDone(name)
    end
    modalButton(boxFrame,'Save',245,151,205,40,submit,true)
    nameBox.FocusLost:Connect(function(enter) if enter then submit() end end)
    task.defer(function() pcall(function() nameBox:CaptureFocus() end) end)
end
local function openConfirmDialog(titleText,bodyText,confirmText,onConfirm)
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(470,220),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f)
    corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    local t=modalLabel(f,titleText,20,16,430,32,24); t.Font=Enum.Font.SourceSansBold
    modalLabel(f,bodyText,20,62,430,72,17).TextColor3=C.Muted
    f.Name='Confirmation'
    modalButton(f,'Cancel',20,161,205,40,clearModal,false).Name='Cancel'
    modalButton(f,confirmText,245,161,205,40,function() clearModal(); onConfirm() end,true).Name='Confirm'
end
local defaultSearchOptions={SortType='Relevance',SortAggregation='AllTime',CreatorType='All',CreatorName='',IncludeOffSale=true,PersonalizedResults=true}
app.SearchOptions=table.clone(defaultSearchOptions)
function app.NormalizeSearchOptions(value)
    local result=table.clone(defaultSearchOptions)
    for _,field in ipairs({'SortType','SortAggregation','CreatorType'}) do
        local enum=Enum[field=='SortType' and 'CatalogSortType' or (field=='SortAggregation' and 'CatalogSortAggregation' or 'CreatorTypeFilter')]
        local candidate=value[field] or result[field]
        local ok,item=pcall(function() return enum[candidate] end)
        assert(ok and item,'Unknown value: '..field)
        result[field]=candidate
    end
    result.CreatorName=tostring(value.CreatorName or ''):match('^%s*(.-)%s*$')
    result.IncludeOffSale=value.IncludeOffSale~=false
    result.PersonalizedResults=value.PersonalizedResults~=false
    for _,field in ipairs({'MinPrice','MaxPrice'}) do
        local raw=value[field]
        if raw~=nil and tostring(raw):match('%S') then
            local n=tonumber(raw)
            assert(n and n==n and n>=0 and n<=2147483647 and n%1==0,'Price must be a whole number from 0 to 2147483647')
            result[field]=n
        end
    end
    assert(not result.MinPrice or not result.MaxPrice or result.MinPrice<=result.MaxPrice,'Minimum price exceeds maximum price')
    return result
end
function app.SetSearchOptions(value)
    app.SearchOptions=app.NormalizeSearchOptions(value)
    local count=0
    for k,v in pairs(app.SearchOptions) do if defaultSearchOptions[k]~=v then count+=1 end end
    optionsButton.Text='Search Options'..(count>0 and (' ('..count..')') or '')
end
do
    local sortChoices={{'Relevance','Relevance'},{'Bestselling','Bestselling'},{'MostFavorited','Most Favorited'},
        {'RecentlyCreated','Recently Published'},{'PriceLowToHigh','Price: Low to High'},{'PriceHighToLow','Price: High to Low'}}
    local periods={{'AllTime','All time'},{'Past12Hours','Past 12 hours'},{'PastDay','Past day'},{'Past3Days','Past 3 days'},{'PastWeek','Past week'},{'PastMonth','Past month'}}
    local creatorTypes={{'All','All creators'},{'User','User'},{'Group','Group'}}
    local function openSearchOptions()
        clearModal(); modalShade.Visible=true
        local draft=table.clone(app.SearchOptions)
        local f=make('Frame',{Name='SearchOptionsDialog',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(610,554),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
        make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
        modalLabel(f,'Search Options',24,16,430,36,26).Font=Enum.Font.SourceSansBold
        modalButton(f,'X',548,18,38,34,clearModal)
        modalLabel(f,'Choose your filters, then click Apply.',24,57,560,24,17).TextColor3=C.Muted
        local dropdown
        local function closeDropdown() if dropdown then dropdown:Destroy(); dropdown=nil end end
        local function selectField(field,choices,x,y,w,changed)
            local b=modalButton(f,'',x,y,w,38,nil)
            b.Name=field
            local function update()
                for _,choice in ipairs(choices) do if choice[1]==draft[field] then b.Text=choice[2]..'  v' end end
            end
            b.Activated:Connect(function()
                local wasOpen=dropdown and dropdown.Name==field..'Choices'
                closeDropdown(); if wasOpen then return end
                dropdown=make('Frame',{Name=field..'Choices',Position=UDim2.fromOffset(x,y+42),Size=UDim2.fromOffset(w,#choices*34+8),BackgroundColor3=C.Surface,BorderSizePixel=0,ZIndex=20},f)
                corner(dropdown); make('UIStroke',{Color=C.Border,Thickness=1},dropdown)
                for i,choice in ipairs(choices) do
                    local option=modalButton(dropdown,choice[2],4,4+(i-1)*34,w-8,32,function()
                        draft[field]=choice[1]; closeDropdown(); update(); if changed then changed() end
                    end,draft[field]==choice[1])
                    option.Name=choice[1]; option.TextSize=17
                end
            end)
            update(); return b,update
        end
        local function field(name,placeholder,x,y,w,text)
            local b=make('TextBox',{Name=name,Text=text or '',PlaceholderText=placeholder,PlaceholderColor3=C.Muted,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,38),BackgroundColor3=C.Surface,TextColor3=C.Text,Font=Enum.Font.SourceSans,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,BorderSizePixel=0},f)
            corner(b); make('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},b)
            b.Focused:Connect(closeDropdown); return b
        end
        modalLabel(f,'Sort type',24,91,270,24,17).TextColor3=C.Muted
        local periodLabel=modalLabel(f,'Time period',312,91,270,24,17)
        local period,updatePeriod
        local function updatePeriodState()
            local active=draft.SortType=='Bestselling' or draft.SortType=='MostFavorited'
            period.Visible=active; periodLabel.Visible=active
        end
        local _,updateSort=selectField('SortType',sortChoices,24,119,270,updatePeriodState)
        period,updatePeriod=selectField('SortAggregation',periods,312,119,274)
        updatePeriodState()
        modalLabel(f,'Price in Robux',24,171,562,24,17).TextColor3=C.Muted
        local min=field('MinPrice','Min',24,199,270,draft.MinPrice and tostring(draft.MinPrice))
        local max=field('MaxPrice','Max',312,199,274,draft.MaxPrice and tostring(draft.MaxPrice))
        modalLabel(f,'Creator',24,251,562,24,17).TextColor3=C.Muted
        local creator=field('CreatorName','Username or group name',24,279,348,draft.CreatorName)
        local _,updateCreator=selectField('CreatorType',creatorTypes,384,279,202)
        local offSale=modalButton(f,'',24,337,562,38,function() end)
        offSale.Name='IncludeOffSale'
        local function updateOffSale()
            offSale.Text=(draft.IncludeOffSale and 'ON' or 'OFF')..'  ·  Include off-sale items'
            offSale.BackgroundColor3=draft.IncludeOffSale and C.Green or C.Card
        end
        offSale.Activated:Connect(function() closeDropdown(); draft.IncludeOffSale=not draft.IncludeOffSale; updateOffSale() end)
        updateOffSale()
        local personalized=modalButton(f,'',24,384,562,38,nil)
        personalized.Name='PersonalizedResults'
        local function updatePersonalized()
            personalized.Text=(draft.PersonalizedResults and 'ON' or 'OFF')..'  ·  Personalized Results'
            personalized.BackgroundColor3=draft.PersonalizedResults and C.Green or C.Card
        end
        personalized.Activated:Connect(function() closeDropdown(); draft.PersonalizedResults=not draft.PersonalizedResults; updatePersonalized() end)
        updatePersonalized()
        modalLabel(f,'Recommendations use an empty query, Relevance and on-sale items.',24,425,562,30,15).TextColor3=C.Muted
        local notice=modalLabel(f,'',24,458,562,26,16); notice.TextColor3=Color3.fromRGB(255,160,150)
        modalButton(f,'Reset',24,493,156,40,function()
            closeDropdown(); draft=table.clone(defaultSearchOptions)
            min.Text=''; max.Text=''; creator.Text=''; notice.Text=''
            updateSort(); updatePeriod(); updateCreator(); updatePeriodState(); updateOffSale(); updatePersonalized()
        end).Name='ResetOptions'
        modalButton(f,'Cancel',292,493,136,40,clearModal).Name='CancelOptions'
        modalButton(f,'Apply',440,493,146,40,function()
            closeDropdown(); draft.MinPrice=min.Text; draft.MaxPrice=max.Text; draft.CreatorName=creator.Text
            local ok,err=pcall(app.SetSearchOptions,draft)
            if not ok then notice.Text=tostring(err):gsub('^.-:%d+: ',''); return end
            clearModal(); search()
        end,true).Name='ApplyOptions'
    end
    optionsButton.Activated:Connect(openSearchOptions)
end
local function outfitItems(data)
    local byId={}
    for _,item in ipairs(data.Items or {}) do if item.Id then byId[item.Id]=item end end
    local out={}
    for _,id in ipairs(data.AssetIds or {}) do
        local item=byId[id] or {}
        table.insert(out,{Id=id,Name=safeText(item.Name or ('ID '..string.format('%.0f',id))),Kind=item.Kind})
    end
    return out
end
local function equipSavedOutfit(entry)
    run(function(rev)
        clearVisuals(); app.Desired={}; app.HideOriginal=false
        local failed=applyOutfit(entry.Data,rev)
        return failed and #failed==0 and ('Outfit equipped: '..entry.Name) or ('Some outfit items could not load: '..table.concat(failed or {},', '))
    end)
end
local function openOutfitPreview(entry)
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(620,590),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f)
    corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    local t=modalLabel(f,entry.Name,22,14,500,34,26); t.Font=Enum.Font.SourceSansBold
    modalButton(f,'X',558,14,40,34,clearModal,false)
    modalLabel(f,'Equip this saved outfit?',22,53,560,28,18).TextColor3=C.Muted
    local list=make('ScrollingFrame',{Position=UDim2.fromOffset(22,92),Size=UDim2.fromOffset(576,404),BackgroundColor3=C.Surface,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4},f)
    corner(list); make('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},list); make('UIPadding',{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)},list)
    local items=outfitItems(entry.Data)
    if #items==0 then
        local none=modalLabel(list,'This outfit contains no added items.',8,8,530,52,18); none.Size=UDim2.new(1,-16,0,52); none.TextColor3=C.Muted
    else
        for i,item in ipairs(items) do
            local row=make('Frame',{Size=UDim2.new(1,-8,0,66),LayoutOrder=i,BackgroundColor3=C.Card,BorderSizePixel=0},list); corner(row)
            make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',item.Id)..'&w=150&h=150',Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(52,52),BackgroundTransparency=1},row)
            local n=modalLabel(row,item.Name,70,8,460,28,17); n.TextTruncate=Enum.TextTruncate.AtEnd
            local idLabel=modalLabel(row,'ID: '..string.format('%.0f',item.Id),70,35,460,22,15); idLabel.TextColor3=C.Muted
        end
    end
    local originalText=entry.Data.HideOriginal and 'Original items will be hidden.' or 'Original items will remain visible.'
    modalLabel(f,originalText,22,503,360,24,15).TextColor3=C.Muted
    modalButton(f,'Cancel',391,510,95,48,clearModal,false)
    modalButton(f,'Equip',497,510,101,48,function() clearModal(); equipSavedOutfit(entry) end,true)
end
local function confirmOverwrite(entry,data)
    if app.Busy or app.Restoring then message('Please wait for the current item to finish loading'); return end
    local snapshot=data or app.ExportOutfit()
    openConfirmDialog('Overwrite outfit?',
        ''..entry.Name..' will be replaced with your current outfit ('..#snapshot.AssetIds..' items). Its name will stay the same.',
        'Overwrite',function()
            local ok,err=pcall(app.OverwriteOutfit,entry.Id,snapshot)
            if ok then message('Outfit updated: '..entry.Name) else message(err,true) end
            if categories[category].SavedRoot and savedSection=='Outfits' then renderSavedOutfits() end
        end)
end
local function openOutfitActions(entry)
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{Name='OutfitActions',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(470,288),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    modalLabel(f,entry.Name,20,16,368,36,24).TextTruncate=Enum.TextTruncate.AtEnd
    modalButton(f,'X',410,18,38,32,clearModal)
    modalButton(f,'Overwrite with current outfit',20,76,430,48,function() confirmOverwrite(entry) end,true).Name='OverwriteOutfit'
    modalButton(f,'Rename',20,138,430,48,function()
        openNameDialog('Rename outfit',entry.Name,function(name)
            local ok,err=pcall(app.RenameOutfit,entry.Id,name)
            if not ok then message(err,true) end
            renderSavedOutfits()
        end)
    end).Name='RenameOutfit'
    modalButton(f,'Delete outfit',20,212,430,44,function()
        openConfirmDialog('Delete outfit?',''..entry.Name..' will be removed from your saved outfits.','Delete',function()
            local ok,err=pcall(app.DeleteOutfit,entry.Id)
            if not ok then message(err,true) end
            renderSavedOutfits()
        end)
    end).Name='DeleteOutfit'
end
renderSavedOutfits=function()
    clearResults(); pages=nil; app.SearchBusy=false
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Search saved items...'; searchButton.Text='Search'
    empty.Visible=#SavedOutfits==0
    empty.Text='No saved outfits yet.\nCreate a look and click Save.'
    for index,entry in ipairs(SavedOutfits) do
        if filterMatch(entry.Name) then
        local card=make('Frame',{Name='SavedOutfit',LayoutOrder=index,BackgroundColor3=C.Card,BorderSizePixel=0},results); corner(card); resultCount+=1
        local items=outfitItems(entry.Data)
        for j=1,math.min(3,#items) do
            make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',items[j].Id)..'&w=150&h=150',Size=UDim2.fromOffset(48,48),Position=UDim2.fromOffset(9+(j-1)*53,10),BackgroundTransparency=1},card)
        end
        if #items==0 then modalLabel(card,'Empty outfit',12,18,156,34,16).TextColor3=C.Muted end
        local n=label(entry.Name,10,66,160,39,card,17); n.TextTruncate=Enum.TextTruncate.AtEnd; n.Font=Enum.Font.SourceSansSemibold
        local count=label('Items: '..#items,10,107,160,22,card,15); count.TextColor3=C.Muted
        card:SetAttribute('OutfitId',entry.Id)
        button('Open',10,136,160,30,function() openOutfitPreview(entry) end,card,true).Name='PreviewOutfit'
        button('Manage',10,173,160,28,function() openOutfitActions(entry) end,card).Name='ManageOutfit'
    end
        end
    empty.Visible=resultCount==0
    moreButton.Text='Saved outfits: '..resultCount; moreButton.Active=false; moreButton.AutoButtonColor=false
end
local function openSaveDialog(data)
    local function createNew()
        openNameDialog('Save outfit','Outfit '..tostring(#SavedOutfits+1),function(name)
            local ok,err=pcall(app.SaveOutfit,name,data)
            if not ok then message(err,true); return end
            message('Saved: '..name)
            if categories[category].SavedRoot and savedSection=='Outfits' then renderSavedOutfits() end
        end)
    end
    if #SavedOutfits==0 then createNew(); return end
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{Name='SaveOutfitDialog',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(510,440),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    modalLabel(f,'Save current outfit',20,16,420,36,24)
    modalButton(f,'X',452,18,38,32,clearModal)
    modalButton(f,'Create a new outfit',20,72,470,44,createNew,true).Name='CreateNew'
    modalLabel(f,'Or choose an outfit to overwrite:',20,133,470,28,18).TextColor3=C.Muted
    local list=make('ScrollingFrame',{Name='Outfits',Position=UDim2.fromOffset(20,172),Size=UDim2.fromOffset(470,246),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0},f)
    make('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},list)
    for i,entry in ipairs(SavedOutfits) do
        local b=modalButton(list,entry.Name,0,0,458,46,function() confirmOverwrite(entry,data) end)
        b.Name='Overwrite_'..i; b.LayoutOrder=i; b.TextTruncate=Enum.TextTruncate.AtEnd
    end
end
local function removeFavorite(id)
    id=tonumber(id)
    if not id or not SavedItems[id] then return true end
    local old=SavedItems[id]
    SavedItems[id]=nil
    local ok,err=pcall(saveFavoriteLibrary)
    if not ok then SavedItems[id]=old; message(err,true); return false end
    return true
end
local function addFavorite(item,group,subName)
    local id=tonumber(item.Id)
    assert(id and id>0,'Item has no valid ID')
    local old=SavedItems[id]
    SavedItems[id]={Id=id,Name=safeText(item.Name or ('ID '..string.format('%.0f',id))),AssetType=avatarTypeName(item.AssetType),Group=group,Sub=subName}
    local ok,err=pcall(saveFavoriteLibrary)
    if not ok then SavedItems[id]=old; error(err) end
end
local function toggleFavorite(item,group,subName)
    local id=tonumber(item.Id)
    if isFavorite(id) then
        if not removeFavorite(id) then return end
        message('Removed from favorites: '..safeText(item.Name))
    else
        local ok,err=pcall(addFavorite,item,group,subName)
        if not ok then message(err,true); return end
        message('Saved: '..safeText(item.Name))
    end
    if renderCategories then renderCategories() end
    local cat=categories[category]
    if cat and cat.SavedRoot and savedSection~='Outfits' and renderSavedItems then renderSavedItems(savedGroup)
    else refresh() end
end
app.SetFavorite=function(item,group,subName,value)
    if value then return addFavorite(item,group,subName) end
    return removeFavorite(item.Id)
end
filterMatch=function(name,id)
    local function fold(value)
        local parts={}
        for _,c in utf8.codes(string.lower(tostring(value))) do
            if c>=1040 and c<=1071 then c+=32 elseif c==1025 then c=1105 end
            table.insert(parts,utf8.char(c))
        end
        return table.concat(parts)
    end
    local term=fold(query.Text):match('^%s*(.-)%s*$')
    return term=='' or fold(name):find(term,1,true)~=nil or tostring(id or ''):find(term,1,true)~=nil
end
-- Ключ карточки: число — ассет, 'b'..id — бандл (id ассетов и бандлов пересекаются)
local function renderItemCard(item,group,subName)
    local id=tonumber(item.Id)
    local isBundle=item.ItemType=='Bundle'
    local key=isBundle and 'b'..string.format('%.0f',id) or id
    if cardButtons[key] then return end
    -- Состав бандла приходит в выдаче поиска: запоминаем его без запроса, чтобы знать, надет ли он
    if isBundle and type(item.BundledItems)=='table' then pcall(bundleDetails,id,item,function() return app.Alive end) end
    local card=make('Frame',{Name=(isBundle and 'Bundle_' or 'Item_')..string.format('%.0f',id),LayoutOrder=resultCount,BackgroundColor3=C.Card,BorderSizePixel=0},results)
    corner(card); resultCount+=1
    make('ImageLabel',{Image='rbxthumb://type='..(isBundle and 'BundleThumbnail' or 'Asset')..'&id='..string.format('%.0f',id)..'&w=150&h=150',Size=UDim2.fromOffset(126,120),Position=UDim2.fromOffset(27,3),BackgroundTransparency=1},card)
    if not isBundle then
        local fav=button('',138,7,34,34,function() toggleFavorite(item,group,subName) end,card)
        fav.Name='Favorite'; favoriteButtons[id]=fav
        make('ImageLabel',{Name='Star',Image='rbxassetid://7537715511',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(23,23),BackgroundTransparency=1,ImageColor3=C.Muted,ScaleType=Enum.ScaleType.Fit},fav)
    end
    local name=label(item.Name,10,125,160,41,card,17); name.TextTruncate=Enum.TextTruncate.AtEnd
    local b=button('Try on',10,171,160,32,function()
        run(function(rev)
            if isBundle then
                if app.BundleWorn(id) then app.RemoveBundle(id,rev); return 'Bundle removed' end
                return app.WearBundleAsync(id,rev,item)
            end
            if app.Items[id] then app.Remove(id,rev); return 'Item removed' end
            return app.WearAsync(id,rev,{Name=item.Name,AssetType=item.AssetType})
        end)
    end,card,true)
    b.Name='Wear'; cardButtons[key]=b
end
renderSavedItems=function(group)
    clearResults(); pages=nil; app.SearchBusy=false
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Search saved items...'; searchButton.Text='Search'
    local items={}
    for _,entry in pairs(SavedItems) do
        if group=='All' or entry.Group==group then table.insert(items,entry) end
    end
    table.sort(items,function(a,b) return (a.Name or '')<(b.Name or '') end)
    empty.Visible=#items==0
    empty.Text='No favorite items yet.\nClick a star on a catalog item.'
    for _,item in ipairs(items) do
        if filterMatch(item.Name,item.Id) then renderItemCard(item,item.Group,item.Sub) end
    end
    empty.Visible=resultCount==0
    moreButton.Text='Favorite items: '..resultCount; moreButton.Active=false; moreButton.AutoButtonColor=false
    refresh()
end
local function refreshCards()
    for id,b in pairs(cardButtons) do
        local worn
        if type(id)=='string' then worn=app.BundleWorn(tonumber(id:sub(2))) else worn=app.Items[id]~=nil end
        b.Text=worn and 'Remove' or 'Try on'
        b.BackgroundColor3=worn and C.Green or C.Accent
        b.Active=not app.Busy and not app.Restoring
        b.AutoButtonColor=b.Active
    end
    for id,b in pairs(favoriteButtons) do
        local saved=isFavorite(id)
        b.Text=''
        b.Star.ImageColor3=saved and Color3.fromRGB(255,210,97) or C.Text
        b.BackgroundColor3=saved and Color3.fromRGB(77,65,38) or C.Surface
        b:SetAttribute('IsFavorite',saved)
        b.Active=not app.Busy and not app.Restoring
        b.AutoButtonColor=b.Active
    end
end
local function renderPage()
    for _,item in ipairs(pages:GetCurrentPage()) do
        if item.ItemType=='Bundle' then
            renderItemCard(item)
        elseif item.ItemType=='Asset' and not cardButtons[item.Id] then
            local group,subName=favoritePlacement(item)
            renderItemCard(item,group,subName)
        end
    end
    empty.Visible=resultCount==0
    empty.Text='No results.\nTry a different keyword or category.'
    moreButton.Text=pages.IsFinished and ('Total results: '..resultCount) or ('Load more  |  Shown: '..resultCount)
    moreButton.Active=not pages.IsFinished; moreButton.AutoButtonColor=not pages.IsFinished
    refreshCards()
end
local searchCache={}
function app.BuildCatalogParams(selected,keyword,options)
    options=app.NormalizeSearchOptions(options or app.SearchOptions)
    if selected.Free then options.MinPrice=0; options.MaxPrice=0 end
    local p=CatalogSearchParams.new()
    p.SearchKeyword=((selected.Keyword and selected.Keyword..' ' or '')..(keyword or '')):gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
    p.IncludeOffSale=options.IncludeOffSale
    -- Matches the original catalog's personalized browse mode. Roblox handles ranking.
    if options.PersonalizedResults and p.SearchKeyword=='' and options.CreatorName=='' and options.SortType=='Relevance' then
        p.IncludeOffSale=false
    end
    -- Части тела оригинал по умолчанию сортирует по избранному
    p.SortType=Enum.CatalogSortType[(selected.Sort and options.SortType=='Relevance') and selected.Sort or options.SortType]
    p.SortAggregation=Enum.CatalogSortAggregation[options.SortAggregation]
    p.CreatorType=Enum.CreatorTypeFilter[options.CreatorType]
    p.CreatorName=options.CreatorName
    if options.MinPrice then p.MinPrice=options.MinPrice end
    if options.MaxPrice then p.MaxPrice=options.MaxPrice end
    p.SalesTypeFilter=Enum.SalesTypeFilter[selected.SalesTypeFilter or 'All']
    local types={}; for _,name in ipairs(selected.Types) do table.insert(types,Enum.AvatarAssetType[name]) end
    p.AssetTypes=types
    local bundles={}; for _,name in ipairs(selected.BundleTypes or {}) do table.insert(bundles,Enum.BundleType[name]) end
    p.BundleTypes=bundles
    return p
end
local function catalogPages(selected,keyword,active,options)
    local p=app.BuildCatalogParams(selected,keyword,options)
    local key=Http:JSONEncode({selected.Types,selected.BundleTypes or {},p.SearchKeyword,p.SortType.Name,p.SortAggregation.Name,
        p.CreatorType.Name,p.CreatorName,p.IncludeOffSale,p.MinPrice,p.MaxPrice,p.SalesTypeFilter.Name})
    local entry=searchCache[key]
    if not entry or os.clock()-entry.Time>120 then
        local engine=apiCall(network.Search,function() return AES:SearchCatalogAsync(p) end,active,1.2)
        entry={Engine=engine,Pages={engine:GetCurrentPage()},Finished=engine.IsFinished,Time=os.clock()}
        searchCache[key]=entry
        local count=0; for _ in pairs(searchCache) do count+=1 end
        if count>12 then
            local oldest,oldTime
            for k,v in pairs(searchCache) do if k~=key and (not oldTime or v.Time<oldTime) then oldest=k; oldTime=v.Time end end
            if oldest then searchCache[oldest]=nil end
        end
    end
    local wrapper={Index=1,IsFinished=entry.Finished and #entry.Pages==1}
    function wrapper:GetCurrentPage() return entry.Pages[self.Index] end
    function wrapper:AdvanceToNextPageAsync()
        if not entry.Pages[self.Index+1] and not entry.Finished then
            apiCall(network.Search,function()
                entry.Engine:AdvanceToNextPageAsync()
                table.insert(entry.Pages,entry.Engine:GetCurrentPage())
                entry.Finished=entry.Engine.IsFinished
                return true
            end,active,1.2)
        end
        if entry.Pages[self.Index+1] then self.Index+=1 end
        self.IsFinished=entry.Finished and self.Index==#entry.Pages
    end
    return wrapper
end
app.QueryCatalog=function(types,keyword,options)
    return catalogPages({Types=types},keyword or '',function() return app.Alive end,options)
end
app.QueryCategory=function(index,subIndex,keyword,options)
    return catalogPages(categories[index].Sub[subIndex or 1],keyword or '',function() return app.Alive end,options)
end
search=function()
    searchSerial+=1; local token=searchSerial
    local cat=categories[category]
    if cat and cat.SavedRoot then
        if savedSection=='Outfits' then renderSavedOutfits() else renderSavedItems(savedGroup) end
        return
    end
    local selected=cat.Sub[subcategory]; local keyword=query.Text; local options=table.clone(app.SearchOptions)
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Search catalog'
    app.SearchBusy=true; searchButton.Text='Searching...'; pages=nil
    clearResults(); empty.Visible=true; empty.Text='Searching for items...'
    moreButton.Active=false; moreButton.Text='Please wait...'
    task.spawn(function()
        task.wait(0.35)
        local function active() return app.Alive and token==searchSerial end
        if not active() then return end
        local ok,result=pcall(catalogPages,selected,keyword,active,options)
        if not app.Alive or token~=searchSerial then return end
        app.SearchBusy=false; searchButton.Text='Search'
        if ok then pages=result; renderPage()
        else empty.Text='Catalog did not respond.\nClick Search to try again.'; moreButton.Text='No results'; message(result,true) end
    end)
end
app.Search=search
renderCategories=function()
    for _,parent in ipairs({categoryPanel,subPanel}) do
        for _,o in ipairs(parent:GetChildren()) do if o:IsA('GuiButton') then o:Destroy() end end
    end
    local isSaved=categories[category].SavedRoot
    optionsButton.Visible=not isSaved
    local dw=app.Window.Width-1100
    query.Size=UDim2.fromOffset((isSaved and 658 or 452)+dw,40)
    searchButton.Position=UDim2.fromOffset((isSaved and 686 or 480)+dw,106)
    for i,cat in ipairs(categories) do
        local b=button(cat.Name,0,0,118,38,function()
            if category==i then return end
            category=i; subcategory=1; query.Text=''; subPanel.CanvasPosition=Vector2.zero
            renderCategories(); search()
        end,categoryPanel)
        b.Name='Category_'..i; b.LayoutOrder=i; b.TextSize=18
        b.Size=UDim2.new(1/#categories,-8*(#categories-1)/#categories,0,38)
        b.BackgroundTransparency=i==category and 0 or 1
        b.BackgroundColor3=C.Card; b.TextColor3=i==category and C.Text or C.Muted
        if i==category then make('Frame',{Name='Selection',AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,1),Size=UDim2.new(1,-24,0,2),BackgroundColor3=C.Text,BorderSizePixel=0},b) end
    end
    local function chip(name,text,width,selected,fn,order)
        local b=button(text,0,0,width,32,fn,subPanel)
        b.Name=name; b.LayoutOrder=order; b.TextSize=17
        b.BackgroundColor3=selected and C.Card or C.Bg
        b.TextColor3=selected and C.Text or C.Muted
        return b
    end
    if isSaved then
        chip('Outfits','Outfits',104,savedSection=='Outfits',function()
            savedSection='Outfits'; query.Text=''; renderCategories(); search()
        end,1)
        chip('Favorites','Favorites',122,savedSection=='Favorites',function()
            savedSection='Favorites'; query.Text=''; renderCategories(); search()
        end,2)
        if savedSection=='Favorites' then
            for i,group in ipairs({'All','Accessories','Hair','Clothing','Body','Makeup'}) do
                chip('FavoritesGroup_'..i,group,math.clamp(utf8.len(group)*8+24,70,124),savedGroup==group,function()
                    savedGroup=group; renderCategories(); search()
                end,i+2)
            end
        end
    else
        for j,entry in ipairs(categories[category].Sub) do
            chip('Subcategory_'..j,entry.Name,math.clamp(utf8.len(entry.Name)*9+24,70,198),j==subcategory,function()
                subcategory=j; renderCategories(); search()
            end,j)
        end
    end
end
renderCategories()
searchButton.Activated:Connect(search)
query.FocusLost:Connect(function(enter) if enter then search() end end)
moreButton.Activated:Connect(function()
    if app.SearchBusy or not pages or pages.IsFinished then return end
    app.SearchBusy=true; moreButton.Text='Loading...'
    local token=searchSerial; local currentPages=pages
    task.spawn(function()
        local ok,err=pcall(function() currentPages:AdvanceToNextPageAsync() end)
        if not app.Alive or token~=searchSerial then return end
        app.SearchBusy=false
        if ok then renderPage() else moreButton.Text='Retry loading'; message(err,true) end
    end)
end)
local wornTitle=label('Your avatar',794,106,170,36,nil,23)
local retry=button('Retry',978,111,100,30,function()
    if not app.Busy and not app.Restoring then run(function(rev)
        local failed=applyOutfit(app.ExportOutfit(),rev)
        return failed and #failed==0 and 'All items equipped' or 'Some items are unavailable'
    end) end
end)
retry.TextSize=16
app.WornHeading=label('Wearing',794,354,284,24,nil,18)
local worn=make('ScrollingFrame',{Name='Worn',Position=UDim2.fromOffset(792,384),Size=UDim2.fromOffset(288,110),BackgroundColor3=C.Surface,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4},panel)
corner(worn)
make('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},worn)
make('UIPadding',{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingBottom=UDim.new(0,8)},worn)
local wornEmpty=label('No added items.\nClick Try on to get started.',814,399,245,74,nil,17)
wornEmpty.TextColor3=C.Muted; wornEmpty.TextXAlignment=Enum.TextXAlignment.Center
redraw=function()
    for _,o in ipairs(worn:GetChildren()) do if o:IsA('Frame') then o:Destroy() end end
    local items={}; for _,it in pairs(app.Desired) do table.insert(items,it) end
    table.sort(items,function(a,b) return a.Name<b.Name end)
    app.WornHeading.Text='Wearing ('..#items..')'; wornEmpty.Visible=#items==0
    for i,it in ipairs(items) do
        local row=make('Frame',{Size=UDim2.fromOffset(267,92),LayoutOrder=i,BackgroundColor3=C.Card,BorderSizePixel=0},worn)
        corner(row)
        make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',it.Id)..'&w=150&h=150',
            Position=UDim2.fromOffset(3,5),Size=UDim2.fromOffset(50,50),BackgroundTransparency=1},row)
        local n=label(it.Name,60,5,201,41,row,16); n.TextTruncate=Enum.TextTruncate.AtEnd
        if not app.Items[it.Id] then n.TextColor3=C.Muted end
        -- Снятие части тела пересобирает тело и ждёт сеть — через run
        button('Remove',186,53,74,30,function()
            run(function(rev) app.Remove(it.Id,rev); return 'Removed: '..it.Name end)
        end,row).TextSize=16
        local equipped=app.Items[it.Id]
        if equipped and equipped.Weld and not equipped.Layered then
            button('Transform Item',60,53,118,30,function() app.OpenTransform(it.Id) end,row).TextSize=16
        elseif equipped and makeup[equipped.Kind] then
            button('Layer -',60,53,56,30,function() app.MoveMakeupLayer(it.Id,-1) end,row).TextSize=15
            button('Layer +',121,53,56,30,function() app.MoveMakeupLayer(it.Id,1) end,row).TextSize=15
        end
    end
    refreshCards()
end
local hideButton=button('Hide originals',792,546,140,32,function()
    if app.Busy or app.Restoring then return end
    local ok,err=pcall(app.SetHideOriginal,not app.HideOriginal)
    if ok then message(app.HideOriginal and 'Original items hidden' or 'Original items visible') else message(err,true) end
end)
hideButton.Name='HideOriginal'
button('Reset outfit',940,546,140,32,function() app.Reset() end).Name='ResetOutfit'
local saveButton=button('Save outfit',792,504,288,34,function()
    if app.Busy or app.Restoring then message('Please wait for the current item to finish loading'); return end
    if type(writefile)~='function' then message('Your executor does not support saving files',true); return end
    local data=app.ExportOutfit()
    if #data.AssetIds==0 and not data.HideOriginal then message('Add an item first',true); return end
    openSaveDialog(data)
end,nil,true)
saveButton.Name='SaveOutfit'
local setting=make('Frame',{Name='RespawnSetting',Position=UDim2.fromOffset(792,588),Size=UDim2.fromOffset(288,88),BackgroundColor3=C.Surface,BorderSizePixel=0},panel)
corner(setting)
label('Keep outfit on respawn',12,8,257,24,setting,18).Font=Enum.Font.SourceSansSemibold
local keepButton=button('ON',12,42,64,30,function() app.SetKeepOnRespawn(not app.KeepOnRespawn) end,setting)
keepButton.Name='KeepOnRespawn'
local keepLabel=label('Keep',86,42,60,30,setting,17)
local keepHelp=label('Restore your selected items automatically.',154,35,123,46,setting,14)
keepHelp.TextColor3=C.Muted
updateControls=function()
    keepButton.Text=app.KeepOnRespawn and 'ON' or 'OFF'
    keepButton.BackgroundColor3=app.KeepOnRespawn and C.Green or C.Card
    keepLabel.Text=app.KeepOnRespawn and 'Keep' or 'Reset'
    keepHelp.Text=app.KeepOnRespawn and 'Restore items and hidden originals.' or 'Use the appearance supplied by the game.'
    hideButton.Text=app.HideOriginal and 'Show originals' or 'Hide originals'
    hideButton.BackgroundColor3=app.HideOriginal and C.Green or C.Card
    refreshCards()
end
local assetId=input('Asset ID, catalog or bundle link',20,650,596,38)
assetId.Name='AssetIdInput'
-- Ссылка вида roblox.com/bundles/<id> — бандл, всё остальное — ассет
function app.WearFromInput(text,rev)
    local bundleId=tostring(text):lower():match('bundles?/(%d+)')
    if bundleId then return app.WearBundleAsync(tonumber(bundleId),rev) end
    return app.WearAsync(text,rev)
end
local wearId=button('Try ID',626,650,150,38,function() run(function(rev) return app.WearFromInput(assetId.Text,rev) end) end,nil,true)
wearId.Name='WearId'
assetId.FocusLost:Connect(function(enter)
    if enter then run(function(rev) return app.WearFromInput(assetId.Text,rev) end) end
end)
label('Right Ctrl',720,15,150,26,nil,16).TextColor3=C.Muted
status=label('Choose a category or search for an item.',22,696,1056,26,nil,17)
status.Name='Status'; status.TextTruncate=Enum.TextTruncate.AtEnd
do
    local frame=make('Frame',{Name='AvatarPreview',Position=UDim2.fromOffset(792,154),Size=UDim2.fromOffset(288,190),BackgroundColor3=C.Surface,BorderSizePixel=0,ClipsDescendants=true},panel)
    corner(frame)
    local viewport=make('ViewportFrame',{Name='Viewport',Size=UDim2.new(1,0,1,-30),BackgroundTransparency=1,Active=true,
        Ambient=Color3.fromRGB(185,185,195),LightColor=Color3.fromRGB(255,247,235),LightDirection=Vector3.new(-1,-1,-2)},frame)
    local world=make('WorldModel',{Name='AvatarWorld'},viewport)
    local camera=make('Camera',{Name='PreviewCamera',FieldOfView=35},viewport)
    viewport.CurrentCamera=camera
    local sky=game:GetService('Lighting'):FindFirstChildOfClass('Sky')
    if sky then sky:Clone().Parent=viewport end
    local notice=label('Loading avatar...',12,44,264,62,frame,17)
    notice.Name='PreviewNotice'; notice.TextXAlignment=Enum.TextXAlignment.Center
    local state={Frame=frame,Viewport=viewport,World=world,Camera=camera,Yaw=0,Pitch=0,Zoom=1,Dirty=true,Builds=0}
    app.Preview=state
    local function updateCamera()
        if not state.Center then return end
        local aspect=math.max(.1,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
        local tangent=math.tan(math.rad(camera.FieldOfView/2))
        local direction=Vector3.new(math.sin(state.Yaw)*math.cos(state.Pitch),math.sin(state.Pitch),-math.cos(state.Yaw)*math.cos(state.Pitch))
        local basis=CFrame.lookAt(Vector3.zero,-direction)
        local distance=0
        for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
            local p=state.Size*Vector3.new(x,y,z)/2
            distance=math.max(distance,p:Dot(direction)+math.max(math.abs(p:Dot(basis.RightVector))/(tangent*aspect),math.abs(p:Dot(basis.UpVector))/tangent))
        end end end
        distance=math.max(.5,distance)*1.05*state.Zoom
        camera.CFrame=CFrame.lookAt(state.Center+direction*distance,state.Center)
    end
    state.UpdateCamera=updateCamera
    local function rebuild()
        if not app.Alive or not panel.Visible or app.Busy or app.Restoring then return end
        local character=player.Character
        if not character or not character:FindFirstChild('HumanoidRootPart') then notice.Visible=true; notice.Text='Waiting for avatar...'; return end
        local archivable=character.Archivable
        character.Archivable=true
        local ok,clone=pcall(function() return character:Clone() end)
        character.Archivable=archivable
        if not ok or not clone then notice.Visible=true; notice.Text='Avatar preview unavailable'; return end
        local success,err=pcall(function()
            clone.Name='PreviewAvatar'
            for _,o in ipairs(clone:QueryDescendants('LuaSourceContainer,Sound,Tool,ForceField')) do o:Destroy() end
            for _,part in ipairs(clone:QueryDescendants('BasePart')) do
                part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
            end
            local h=clone:FindFirstChildOfClass('Humanoid')
            if h then h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None; h.BreakJointsOnDeath=false end
            clone:PivotTo(CFrame.new())
            local box,size=clone:GetBoundingBox()
            state.Center=box.Position; state.Size=size
            clone.Parent=world
            if state.Model then state.Model:Destroy() end
            state.Model=clone; state.Dirty=false; state.Builds+=1
            state.LastError=nil; notice.Visible=false; updateCamera()
        end)
        if not success then clone:Destroy(); state.LastError=tostring(err); notice.Visible=true; notice.Text='Avatar preview unavailable' end
    end
    local scheduled=false
    function app.RequestPreview()
        state.Dirty=true
        if scheduled or not panel.Visible then return end
        scheduled=true
        task.delay(.15,function()
            scheduled=false
            if app.Alive and state.Dirty then rebuild() end
        end)
    end
    connect(panel:GetPropertyChangedSignal('Visible'),function() if panel.Visible and state.Dirty then app.RequestPreview() end end)
    connect(viewport:GetPropertyChangedSignal('AbsoluteSize'),updateCamera)
    local characterConnections={}
    local function bindCharacter(ch)
        for _,c in ipairs(characterConnections) do c:Disconnect() end
        characterConnections={}
        if ch then
            local function changed(o)
                if o:IsA('BasePart') or o:IsA('Accessory') or o:IsA('Decal') or o:IsA('SurfaceAppearance') or o:IsA('Clothing') or o:IsA('ShirtGraphic') then app.RequestPreview() end
            end
            table.insert(characterConnections,connect(ch.DescendantAdded,changed))
            table.insert(characterConnections,connect(ch.DescendantRemoving,changed))
        end
        app.RequestPreview()
    end
    connect(player.CharacterAdded,bindCharacter); bindCharacter(player.Character)
    local dragging
    connect(viewport.InputBegan,function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging={Input=i,Start=i.Position,Yaw=state.Yaw,Pitch=state.Pitch}
        end
    end)
    connect(UIS.InputChanged,function(i)
        if dragging and (i==dragging.Input or i.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=(i.Position-dragging.Start)/scale.Scale
            state.Yaw=dragging.Yaw-d.X*.012; state.Pitch=math.clamp(dragging.Pitch+d.Y*.008,-.6,.6); updateCamera()
        end
    end)
    connect(UIS.InputEnded,function(i)
        if dragging and (i==dragging.Input or i.UserInputType==Enum.UserInputType.MouseButton1) then dragging=nil end
    end)
    connect(viewport.InputChanged,function(i)
        if i.UserInputType==Enum.UserInputType.MouseWheel then state.Zoom=math.clamp(state.Zoom-i.Position.Z*.1,.55,1.8); updateCamera() end
    end)
    local hint=label('Drag to rotate',10,0,124,24,frame,14)
    hint.Position=UDim2.new(0,10,1,-27); hint.TextColor3=C.Muted
    for i,definition in ipairs({{'-','ZoomOut',.1},{'+','ZoomIn',-.1},{'Reset view','ResetView',0}}) do
        local b=button(definition[1],134+(i-1)*30,0,i==3 and 84 or 26,24,function()
            if definition[3]==0 then state.Zoom=1; state.Yaw=0; state.Pitch=0
            else state.Zoom=math.clamp(state.Zoom+definition[3],.55,1.8) end
            updateCamera()
        end,frame)
        b.Name=definition[2]; b.Position=UDim2.new(0,134+(i-1)*30,1,-27); b.TextSize=14
    end
end
do
    local sizeLabel=label('100%',433,15,62,26,nil,16)
    sizeLabel.TextXAlignment=Enum.TextXAlignment.Center
    local minus=button('-',396,14,32,32,function() app.SetInterfaceScale(app.Window.Scale-0.1) end)
    local plus=button('+',500,14,32,32,function() app.SetInterfaceScale(app.Window.Scale+0.1) end)
    minus.Name='ScaleDown'; plus.Name='ScaleUp'
    local reset=button('Reset UI',544,14,112,32,function()
        app.Window={Width=1100,Height=736,Scale=1}; app.LayoutWindow(); fit(); saveSettings()
    end)
    reset.Name='ResetWindow'
    local layouts={}
    for _,o in ipairs(panel:GetChildren()) do if o:IsA('GuiObject') and o~=dragHeader then
        layouts[o]={X=o.Position.X.Offset,Y=o.Position.Y.Offset,W=o.Size.X.Offset,H=o.Size.Y.Offset}
        if o:IsA('GuiButton') and o.Position.Y.Offset<54 then o.ZIndex=4 end
    end end
    local grip=button('',0,0,26,26,nil)
    grip.Name='ResizeGrip'; grip.Text=''; grip.AnchorPoint=Vector2.new(1,1); grip.Position=UDim2.new(1,-5,1,-5); grip.ZIndex=5
    grip.BackgroundTransparency=1; grip.AutoButtonColor=false
    for i=1,3 do make('Frame',{Name='GripLine',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(24-i*3,24-i*3),Size=UDim2.fromOffset(5*i,2),Rotation=-45,BackgroundColor3=C.Muted,BorderSizePixel=0},grip) end
    function app.LayoutWindow()
        local dw,dh=app.Window.Width-1100,app.Window.Height-736
        panel.Size=UDim2.fromOffset(app.Window.Width,app.Window.Height)
        for o,b in pairs(layouts) do
            local x,y,w,h=b.X,b.Y,b.W,b.H
            -- Place search controls from current content width, never from captured positions.
            if o==query then w=(categories[category].SavedRoot and 658 or 452)+dw
            elseif o==searchButton then x=(categories[category].SavedRoot and 686 or 480)+dw
            elseif o==optionsButton then x=578+dw
            elseif o==app.Preview.Frame then x=792+dw; h=190+dh*.45
            elseif o==app.WornHeading then x=794+dw; y=354+dh*.45
            elseif o==worn then x=792+dw; y=384+dh*.45; h=110+dh*.55
            elseif o==wornEmpty then x=814+dw; y=399+dh*.45
            elseif b.X>=792 then
                x+=dw
                if b.Y>=504 then y+=dh end
            elseif o==categoryPanel or o==subPanel then w+=dw
            elseif o==results then w+=dw; h+=dh
            elseif o.Name=='NextSubcategories' then x+=dw
            elseif o==empty then x+=dw/2; y+=dh/2
            elseif o==moreButton or o==assetId or o==status then w+=dw; y+=dh
            elseif o==wearId then x+=dw; y+=dh
            elseif b.Y<54 and b.X>=700 then x+=dw end
            o.Position=UDim2.fromOffset(x,y); o.Size=UDim2.fromOffset(w,h)
        end
        sizeLabel.Text=math.floor(app.Window.Scale*100+0.5)..'%'
    end
    function app.SetWindowSize(w,h,persist)
        assert(type(w)=='number' and type(h)=='number' and w==w and h==h,'Invalid window size')
        app.Window.Width=math.clamp(w,1000,1900); app.Window.Height=math.clamp(h,680,1100)
        app.LayoutWindow(); fit(); if persist~=false then saveSettings() end
    end
    function app.SetInterfaceScale(value,persist)
        assert(type(value)=='number' and value==value,'Invalid interface scale')
        app.Window.Scale=math.clamp(value,0.6,1.6)
        app.LayoutWindow(); fit(); if persist~=false then saveSettings() end
    end
    local sizing
    connect(grip.InputBegan,function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            sizing={Input=i,Start=i.Position,W=app.Window.Width,H=app.Window.Height,Scale=scale.Scale,Position=panel.Position}
        end
    end)
    connect(UIS.InputChanged,function(i)
        if sizing and (i==sizing.Input or i.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=(i.Position-sizing.Start)/sizing.Scale
            local oldW,oldH=app.Window.Width,app.Window.Height
            local viewport=workspace.CurrentCamera.ViewportSize
            app.SetWindowSize(math.min(sizing.W+d.X,(viewport.X-32)/sizing.Scale),math.min(sizing.H+d.Y,(viewport.Y-80)/sizing.Scale),false)
            panel.Position+=UDim2.fromOffset((app.Window.Width-oldW)*scale.Scale/2,(app.Window.Height-oldH)*scale.Scale/2)
            fit()
        end
    end)
    connect(UIS.InputEnded,function(i)
        if sizing and (i==sizing.Input or i.UserInputType==Enum.UserInputType.MouseButton1) then sizing=nil; saveSettings() end
    end)
    app.LayoutWindow(); fit()
end
-- Live transform editor. Handles affect only the selected client-owned accessory.
local editor=make('Frame',{Name='TransformEditor',Visible=false,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-24,0.5,0),Size=UDim2.fromOffset(344,584),BackgroundColor3=C.Bg,BorderSizePixel=0},gui)
corner(editor,14); make('UIStroke',{Color=C.Border,Thickness=1},editor)
local editorScale=make('UIScale',{Scale=scale.Scale},editor)
connect(scale:GetPropertyChangedSignal('Scale'),function() editorScale.Scale=scale.Scale end)
label('Transform Item',18,12,310,32,editor,25).Font=Enum.Font.SourceSansBold
local editName=label('',18,49,308,44,editor,18)
local mode='Position'
local modeNames={Position='Position',Rotation='Rotation',Scale='Scale'}
local stepValues={Position=0.05,Rotation=5,Scale=0.05}
local uniform=true
local initialTransform,dragTransform,dragFrame,dragTarget,highlight
local modeButtons,fields={},{}
local moveHandles=make('Handles',{Name='LocalCatalogMoveScale',Visible=false,Color3=Color3.fromRGB(105,184,255),Style=Enum.HandlesStyle.Movement},gui)
local rotateHandles=make('ArcHandles',{Name='LocalCatalogRotate',Visible=false,Color3=Color3.fromRGB(255,194,102)},gui)
local function editInput(text,x,y,w,h)
    local box=make('TextBox',{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=C.Surface,TextColor3=C.Text,Font=Enum.Font.SourceSans,TextSize=19,ClearTextOnFocus=false,BorderSizePixel=0},editor)
    corner(box); return box
end
local modeHelp=label('',18,143,308,38,editor,17)
local uniformButton=button('Uniform scale: ON',18,321,308,34,function()
    uniform=not uniform
    if app.UpdateTransformFields then app.UpdateTransformFields(app.EditingId) end
end,editor)
label('Step',18,369,60,32,editor,18)
local stepInput=editInput('0.05',91,367,100,34)
stepInput.Name='StepInput'
local editorNotice=label('Edit the values or drag the 3D handles.',18,410,308,53,editor,17)
editorNotice.TextColor3=C.Muted
local function updateGizmos()
    local it=app.EditingId and app.Items[app.EditingId]
    local h=it and it.Object:FindFirstChild('Handle')
    local shown=editor.Visible and h~=nil
    moveHandles.Adornee=h; rotateHandles.Adornee=h
    moveHandles.Visible=shown and mode~='Rotation'; rotateHandles.Visible=shown and mode=='Rotation'
    moveHandles.Style=mode=='Scale' and Enum.HandlesStyle.Resize or Enum.HandlesStyle.Movement
    if highlight then highlight.Enabled=shown end
end
function app.UpdateTransformFields(id)
    if not id or id~=app.EditingId then return end
    local it=app.Items[id]; if not it then return end
    for axis,b in ipairs(fields) do if not b:IsFocused() then b.Text=string.format('%.3f',it.Transform[mode][axis]) end end
    for key,b in pairs(modeButtons) do b.BackgroundColor3=key==mode and C.Accent or C.Card end
    uniformButton.Visible=mode=='Scale'
    uniformButton.Text=uniform and 'Uniform scale: ON' or 'Uniform scale: OFF'
    modeHelp.Text=mode=='Position' and 'X / Y / Z position in studs' or (mode=='Rotation' and 'X / Y / Z rotation in degrees' or 'X / Y / Z scale (1 = original)')
    updateGizmos()
end
local function step()
    local v=tonumber((stepInput.Text:gsub(',','.')))
    if not v or v~=v or v<=0 or v==math.huge then v=stepValues[mode] end
    v=math.clamp(v,0.001,mode=='Rotation' and 180 or 10)
    stepValues[mode]=v; return v
end
local function snap(v) local s=step(); return math.round(v/s)*s end
local function applyEdited(t)
    local ok,err=pcall(app.SetTransform,app.EditingId,t)
    if not ok then editorNotice.Text=safeText(err); editorNotice.TextColor3=Color3.fromRGB(255,156,157) end
end
local function changeAxis(axis,value)
    local it=app.EditingId and app.Items[app.EditingId]; if not it then return end
    local t=normalizedTransform(it.Transform)
    if mode=='Scale' and uniform then
        local ratio=math.max(0.05,value)/t.Scale[axis]
        for i=1,3 do t.Scale[i]*=ratio end
    else t[mode][axis]=value end
    applyEdited(t)
end
for index,key in ipairs({'Position','Rotation','Scale'}) do
    modeButtons[key]=button(modeNames[key],18+(index-1)*105,103,98,33,function()
        mode=key; dragTransform=nil; stepInput.Text=tostring(stepValues[mode]); app.UpdateTransformFields(app.EditingId)
    end,editor)
    modeButtons[key].Name='Mode_'..key
end
for axis,name in ipairs({'X','Y','Z'}) do
    local y=184+(axis-1)*44
    local l=label(name,20,y,30,35,editor,22)
    l.TextColor3=({Color3.fromRGB(255,137,137),Color3.fromRGB(137,226,171),Color3.fromRGB(137,183,255)})[axis]
    button('-',61,y,36,35,function()
        local it=app.Items[app.EditingId]; if it then changeAxis(axis,it.Transform[mode][axis]-step()) end
    end,editor).Name='Minus'..name
    local box=editInput('0',105,y,174,35); fields[axis]=box; box.Name='Value'..name
    button('+',287,y,36,35,function()
        local it=app.Items[app.EditingId]; if it then changeAxis(axis,it.Transform[mode][axis]+step()) end
    end,editor).Name='Plus'..name
    box.FocusLost:Connect(function()
        local v=tonumber((box.Text:gsub(',','.')))
        if v and v==v and math.abs(v)<math.huge then changeAxis(axis,v) end
        app.UpdateTransformFields(app.EditingId)
    end)
end
function app.CloseTransform(cancel,keepWindowState)
    local id=app.EditingId
    app.EditingId=nil; editor.Visible=false; dragTransform=nil
    if cancel and id and app.Items[id] and initialTransform then pcall(app.SetTransform,id,initialTransform) end
    if highlight then highlight:Destroy(); highlight=nil end
    updateGizmos(); if not keepWindowState then panel.Visible=true end
end
function app.OpenTransform(id)
    if app.Busy or app.Restoring then message('Please wait for the current item to finish loading'); return end
    local it=app.Items[id]
    if not it or not it.Weld or it.Layered then message('Transform Item is available for rigid accessories',true); return end
    if app.EditingId then app.CloseTransform(false) end
    app.EditingId=id; initialTransform=normalizedTransform(it.Transform)
    editName.Text=it.Name; panel.Visible=false; editor.Visible=true
    editorNotice.Text='Edit the values or drag the 3D handles.'; editorNotice.TextColor3=C.Muted
    highlight=make('Highlight',{Name='LocalCatalogSelection',Adornee=it.Object,FillTransparency=1,OutlineColor=Color3.fromRGB(105,184,255),DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},it.Object)
    app.UpdateTransformFields(id)
end
function app.ToggleWindow()
    clearModal()
    if app.EditingId then editor.Visible=not editor.Visible; updateGizmos() else panel.Visible=not panel.Visible end
end
button('Reset transform',18,473,308,34,function() applyEdited(defaultTransform()) end,editor)
button('Cancel',18,520,147,40,function() app.CloseTransform(true) end,editor)
button('Done',178,520,148,40,function() app.CloseTransform(false); message('Transform saved in the current outfit') end,editor,true)
local function beginDrag()
    local it=app.EditingId and app.Items[app.EditingId]; if not it then return end
    dragTransform=normalizedTransform(it.Transform)
    dragFrame=it.Object.Handle.CFrame
    dragTarget=it.Weld.Part1.CFrame*it.BaseC1
end
connect(moveHandles.MouseButton1Down,beginDrag)
connect(rotateHandles.MouseButton1Down,beginDrag)
connect(moveHandles.MouseDrag,function(face,distance)
    local it=app.EditingId and app.Items[app.EditingId]
    if not it or not dragTransform then return end
    local t=normalizedTransform(dragTransform)
    local direction=Vector3.FromNormalId(face)
    if mode=='Position' then
        local delta=dragTarget:VectorToObjectSpace(dragFrame:VectorToWorldSpace(direction))*snap(distance)
        t.Position[1]+=delta.X; t.Position[2]+=delta.Y; t.Position[3]+=delta.Z
    elseif mode=='Scale' then
        local axis=math.abs(direction.X)>0 and 1 or (math.abs(direction.Y)>0 and 2 or 3)
        local baseSize=({it.BaseSize.X,it.BaseSize.Y,it.BaseSize.Z})[axis]
        local value=math.max(0.05,t.Scale[axis]+snap(distance*2/math.max(0.001,baseSize)))
        if uniform then local ratio=value/t.Scale[axis]; for i=1,3 do t.Scale[i]*=ratio end else t.Scale[axis]=value end
    else return end
    applyEdited(t)
end)
connect(rotateHandles.MouseDrag,function(axis,angle)
    if not app.EditingId or not dragTransform or mode~='Rotation' then return end
    local index=axis==Enum.Axis.X and 1 or (axis==Enum.Axis.Y and 2 or 3)
    local t=normalizedTransform(dragTransform); t.Rotation[index]+=snap(math.deg(angle)); applyEdited(t)
end)
connect(UIS.InputEnded,function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragTransform=nil end
end)
connect(UIS.InputBegan,function(i,processed)
    if i.KeyCode==Enum.KeyCode.Escape and modalShade.Visible then clearModal(); return end
    if not processed and i.KeyCode==Enum.KeyCode.RightControl then app.ToggleWindow() end
end)
connect(player.CharacterAdded,app.HandleCharacterAdded)
-- If appearance arrives after the bounded wait, rebuild once from the completed server appearance.
connect(player.CharacterAppearanceLoaded,function(ch)
    if ch==player.Character and app.KeepOnRespawn and not app.Restoring and (next(app.Desired) or app.HideOriginal) then
        app.HandleCharacterAdded(ch)
    end
end)
-- ══════════════════════════════════════════════════════════════════════════════
-- Портрет: бюст в кадре rbxthumb AvatarBust, собранный локально
-- ══════════════════════════════════════════════════════════════════════════════
-- Сервер не знает о локальном образе, поэтому миниатюру повторяем во ViewportFrame.
-- Камера — CameraUtility.SetupCamera пакета Thumbnailing (RCC): экстенты головы и её аксессуаров,
-- подбородок как нижняя граница, нейтральная поза. Числа откалиброваны по настоящим AvatarBust
-- (Debuggers/portrait_lab.lua, IoU силуэта ~0.92); свет — лучшее приближение RCC в VPF.
-- Внутри do: главный чанк каталога близок к лимиту 200 локалей, наружу — только поля app
do
    local PORTRAIT={Fov=66,ExtentScale=1.9465,TargetDrop=0.359,CameraPitch=6.6,
        Ambient=Color3.fromRGB(212,212,212),LightColor=Color3.fromRGB(254,254,254),LightAzimuth=-60.5,LightElevation=49.3}
    function app.IsOutfitActive() return app.Alive and (next(app.Desired)~=nil or app.HideOriginal==true) end
    -- Суставы R15 бывают Motor6D и AnimationConstraint (апгрейд суставов аватара): {joint,part0,part1,c0,c1}
    local function portraitJoints(m)
        local list={}
        for _,j in ipairs(m:GetDescendants()) do
            if j:IsA('Motor6D') and j.Part0 and j.Part1 then table.insert(list,{j,j.Part0,j.Part1,j.C0,j.C1})
            elseif j:IsA('AnimationConstraint') and j.Attachment0 and j.Attachment1
                and j.Attachment0.Parent:IsA('BasePart') and j.Attachment1.Parent:IsA('BasePart') then
                table.insert(list,{j,j.Attachment0.Parent,j.Attachment1.Parent,j.Attachment0.CFrame,j.Attachment1.CFrame})
            end
        end
        return list
    end
    -- CharacterUtility.CalculateHeadExtents: голова + аксессуары на её точках крепления, низ не ниже подбородка
    local function portraitHeadExtents(m,target)
        local head=m.Head
        local inv=target:Inverse()
        local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
        local function add(part,clamp,yMin)
            local h=part.Size/2
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local c=part.CFrame*Vector3.new(x*h.X,y*h.Y,z*h.Z)
                if clamp then local t=clamp:PointToObjectSpace(c); c=clamp*Vector3.new(t.X,math.max(yMin,t.Y),t.Z) end
                c=inv*c; lo=lo:Min(c); hi=hi:Max(c)
            end end end
        end
        add(head)
        local points={}
        for _,a in ipairs(head:GetChildren()) do if a:IsA('Attachment') then points[a.Name]=true end end
        for _,acc in ipairs(m:GetChildren()) do
            local handle=acc:IsA('Accoutrement') and acc:FindFirstChild('Handle')
            if handle and handle:IsA('BasePart') then
                local a=handle:FindFirstChildWhichIsA('Attachment')
                if not a or points[a.Name] then add(handle,head.CFrame,-head.Size.Y/2) end
            end
        end
        return lo,hi
    end
    -- Живой R15-персонаж, с которого можно снять портрет (мёртвый разваливается на части)
    local function portraitSource()
        local ch=player.Character
        local hum=ch and ch:FindFirstChildOfClass('Humanoid')
        if hum and hum.Health>0 and hum.RigType==Enum.HumanoidRigType.R15 and ch:FindFirstChild('Head') and ch:FindFirstChild('HumanoidRootPart') then return ch end
    end
    -- ViewportFrame с бюстом персонажа как он выглядит сейчас (с локальным образом), или nil.
    -- WorldModel не шагает анимации, поэтому нейтральную позу собираем прямой кинематикой,
    -- а аксессуары возвращаем на снятые в клоне смещения от частей тела.
    local function buildPortrait()
        local ch=portraitSource()
        if not ch then return nil end
        local archivable=ch.Archivable
        ch.Archivable=true
        local ok,clone=pcall(function() return ch:Clone() end)
        ch.Archivable=archivable
        if not ok or not clone then return nil end
        local built,view=pcall(function()
            for _,o in ipairs(clone:QueryDescendants('LuaSourceContainer,Sound,Tool,ForceField,BillboardGui,Highlight')) do o:Destroy() end
            local joints=portraitJoints(clone)
            local placed={}
            for _,j in ipairs(joints) do placed[j[2]]=true; placed[j[3]]=true end
            local links={}
            for _,d in ipairs(clone:GetDescendants()) do
                local a,b
                if d:IsA('RigidConstraint') then a=d.Attachment0 and d.Attachment0.Parent; b=d.Attachment1 and d.Attachment1.Parent
                elseif d:IsA('WeldConstraint') or (d:IsA('JointInstance') and not d:IsA('Motor6D')) then a,b=d.Part0,d.Part1 end
                if a and b and a:IsA('BasePart') and b:IsA('BasePart') then table.insert(links,{a,b}) end
            end
            -- Цепочки креплений (хэндл → часть тела) в текущей позе клона: смещение сохраняется при смене позы
            local attached,progress={},true
            while progress do
                progress=false
                for _,l in ipairs(links) do
                    local a,b=l[1],l[2]
                    if placed[a] and not placed[b] then placed[b]=true; table.insert(attached,{b,a,a.CFrame:ToObjectSpace(b.CFrame)}); progress=true
                    elseif placed[b] and not placed[a] then placed[a]=true; table.insert(attached,{a,b,b.CFrame:ToObjectSpace(a.CFrame)}); progress=true end
                end
            end
            for _,p in ipairs(clone:QueryDescendants('BasePart')) do
                p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
            end
            clone:FindFirstChildOfClass('Humanoid').DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            local root=clone.HumanoidRootPart
            root.CFrame=CFrame.new()
            local solved={[root]=true}
            progress=true
            while progress do
                progress=false
                for _,j in ipairs(joints) do
                    if solved[j[2]] and not solved[j[3]] then
                        j[1].Transform=CFrame.new()
                        j[3].CFrame=j[2].CFrame*j[4]*j[5]:Inverse(); solved[j[3]]=true; progress=true
                    end
                end
            end
            for _,a in ipairs(attached) do a[1].CFrame=a[2].CFrame*a[3] end
            -- Цель — FaceFrontAttachment, взгляд спроецирован на горизонталь (CFrameUtility.CalculateTargetCFrame)
            local head=clone.Head
            local face=head:FindFirstChild('FaceFrontAttachment')
            local base=face and face.WorldCFrame or head.CFrame
            local look=math.abs(base.LookVector.Y)>0.9 and base.UpVector or base.LookVector
            local target=CFrame.lookAt(base.Position,base.Position+Vector3.new(look.X,0,look.Z).Unit)
            local lo,hi=portraitHeadExtents(clone,target)
            local distance=math.max(hi.X-lo.X,hi.Y-lo.Y)/2*PORTRAIT.ExtentScale/math.tan(math.rad(PORTRAIT.Fov)/2)
            local focus=target+target.Rotation*((lo+hi)/2)-Vector3.new(0,PORTRAIT.TargetDrop*(hi.Y-lo.Y),0)
            local camera=make('Camera',{Name='PortraitCamera',FieldOfView=PORTRAIT.Fov},nil)
            camera.CFrame=CFrame.lookAt(focus*(CFrame.fromEulerAnglesXYZ(math.rad(PORTRAIT.CameraPitch),0,0).LookVector*distance),focus.Position)
            local az,el=math.rad(PORTRAIT.LightAzimuth),math.rad(PORTRAIT.LightElevation)
            local v=make('ViewportFrame',{Name='CatalogPortrait',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
                Ambient=PORTRAIT.Ambient,LightColor=PORTRAIT.LightColor,
                LightDirection=-Vector3.new(math.cos(el)*math.sin(az),math.sin(el),math.cos(el)*math.cos(az))},nil)
            clone.Parent=make('WorldModel',{Name='PortraitWorld'},v)
            camera.Parent=v; v.CurrentCamera=camera
            return v
        end)
        if built then return view end
        clone:Destroy()
        return nil
    end
    -- Портрет готовится заранее, пока персонаж жив: к итогам раунда он может быть мёртв или ещё не заспавнен
    local portraitCache,portraitQueued
    local function updatePortrait()
        if not app.Alive then return end
        local view=buildPortrait()
        if view then
            if portraitCache then portraitCache:Destroy() end
            portraitCache=view; portraitSignal:Fire()
        end
    end
    local function queuePortrait()
        if portraitQueued then return end
        portraitQueued=true
        task.delay(0.5,function() portraitQueued=false; updatePortrait() end)
    end
    -- Копия готового портрета; с живого персонажа — свежая. nil — портрета нет (R6, не загрузился)
    function app.CreatePortrait()
        if not app.Alive then return nil end
        if portraitSource() then
            local view=buildPortrait()
            if view then
                if portraitCache then portraitCache:Destroy() end
                portraitCache=view
            end
        end
        if not portraitCache then return nil end
        -- Clone не переназначает CurrentCamera на камеру копии — иначе копия смотрит камерой кэша
        local copy=portraitCache:Clone()
        copy.CurrentCamera=copy:FindFirstChild('PortraitCamera')
        return copy
    end
    app.QueuePortrait=queuePortrait
    function app.DropPortrait() if portraitCache then portraitCache:Destroy(); portraitCache=nil end end
    if portraitSource() then queuePortrait() end
    connect(player.CharacterAdded,function(ch)
        -- После спавна внешность и образ каталога догружаются — снимаем, когда всё на месте
        task.delay(3,function() if ch==player.Character then queuePortrait() end end)
    end)
end
-- ══════════════════════════════════════════════════════════════════════════════
-- Синхронизация образа с пользователями скрипта
-- ══════════════════════════════════════════════════════════════════════════════
-- Транспорт — relay скинченджера: он берёт ExportSync у провайдера catalog в
-- getgenv().LookSync и приносит чужой образ в ApplyRemote. Формат {x=HideOriginal,
-- i={{id,layerOrder,transform9?}}}; тип предмета не передаётся — проверяем сами через
-- MarketplaceService, чтобы чужой пир не заставил грузить произвольный ассет.
-- Чужой персонаж одевается тем же wearOn, но в своём контексте (Items/Hidden/Head)
local SYNC_MAX_ITEMS=40
app.Remote={}
function app.ExportSync()
    local outfit=app.ExportOutfit()
    if #outfit.AssetIds==0 and not outfit.HideOriginal then return nil end
    local items={}
    for _,id in ipairs(outfit.AssetIds) do
        if #items>=SYNC_MAX_ITEMS then break end
        local d=app.Desired[id]
        -- Анимации своего персонажа и так видны всем через Animator
        if d and d.Kind and animationKinds[d.Kind] then continue end
        local entry={id,d and d.LayerOrder or 0}
        local t=d and d.Transform
        if t then
            local identity=true
            for axis=1,3 do
                if t.Position[axis]~=0 or t.Rotation[axis]~=0 or t.Scale[axis]~=1 then identity=false end
            end
            if not identity then
                entry[3]={t.Position[1],t.Position[2],t.Position[3],t.Rotation[1],t.Rotation[2],t.Rotation[3],t.Scale[1],t.Scale[2],t.Scale[3]}
            end
        end
        table.insert(items,entry)
    end
    return {x=outfit.HideOriginal==true,i=items}
end
local function remoteValid(ctx,rev,ch)
    return app.Alive and ctx.Alive and ctx.Revision==rev and ctx.Player.Character==ch and ch.Parent~=nil
end
local function clearRemoteVisuals(ctx)
    local ids={}; for id in pairs(ctx.Items) do table.insert(ids,id) end
    for _,id in ipairs(ids) do destroyItem(id,ctx) end
    restoreBody(ctx)
    restoreHidden(function() return true end,ctx)
end
-- Одно поколение на спавн и на версию образа: устаревшие загрузки не одевают новый персонаж
local function dressRemote(ctx)
    ctx.Revision+=1
    local rev,ch,data=ctx.Revision,ctx.Player.Character,ctx.Data
    clearRemoteVisuals(ctx)
    if not data or not ch then return end
    task.spawn(function()
        local started=os.clock()
        while remoteValid(ctx,rev,ch) and (not ch:FindFirstChildOfClass('Humanoid') or not ch:FindFirstChild('Head')) do
            if os.clock()-started>15 then return end
            task.wait(0.1)
        end
        while remoteValid(ctx,rev,ch) and not ctx.Player:HasAppearanceLoaded() and os.clock()-started<10 do task.wait(0.15) end
        task.wait(0.65)
        if not remoteValid(ctx,rev,ch) then return end
        if data.x then pcall(hideOriginal,ch,ctx) end
        local active=function() return remoteValid(ctx,rev,ch) end
        -- Тип проверяем сами (MarketplaceService), тело собираем одной моделью до аксессуаров
        local body,rest={},{}
        for _,entry in ipairs(data.i) do
            if not active() then return end
            local ok,info=pcall(itemMetadata,entry[1],nil,active)
            if ok and supportedKind(info.Kind) then
                if bodySlots[info.Kind] then table.insert(body,{Id=entry[1],Kind=info.Kind,Name=info.Name})
                elseif not animationKinds[info.Kind] then table.insert(rest,entry) end
            end
        end
        if #body>0 then pcall(wearBody,ctx,ch,body,active) end
        for _,entry in ipairs(rest) do
            if not active() then return end
            local id,order,tf=entry[1],entry[2],entry[3]
            local ok,it=pcall(wearOn,ctx,ch,id,{LayerOrder=order>0 and order or nil},active)
            if ok and it and it.Weld and not it.Layered and tf then
                pcall(transformItem,it,{Position={tf[1],tf[2],tf[3]},Rotation={tf[4],tf[5],tf[6]},Scale={tf[7],tf[8],tf[9]}})
            end
        end
    end)
end
local function forgetRemote(player)
    local ctx=app.Remote[player]
    if not ctx then return end
    app.Remote[player]=nil
    ctx.Alive=false; ctx.Revision+=1
    for _,c in ipairs(ctx.Connections) do c:Disconnect() end
    clearRemoteVisuals(ctx)
end
function app.ApplyRemote(target,data)
    if not app.Alive or typeof(target)~='Instance' or not target:IsA('Player') or target==player then return end
    local clean={x=type(data)=='table' and data.x==true,i={}}
    if type(data)=='table' and type(data.i)=='table' then
        for _,entry in ipairs(data.i) do
            if #clean.i>=SYNC_MAX_ITEMS then break end
            local id=type(entry)=='table' and tonumber(entry[1])
            if id and id>0 and id%1==0 and id<2^53 then
                local tf=entry[3]
                if type(tf)=='table' then
                    local numbers={}
                    for i=1,9 do local v=tonumber(tf[i]); if not v or v~=v or math.abs(v)==math.huge then numbers=nil; break end; numbers[i]=v end
                    tf=numbers
                else tf=nil end
                table.insert(clean.i,{id,math.max(0,math.floor(tonumber(entry[2]) or 0)),tf})
            end
        end
    end
    if #clean.i==0 and not clean.x then forgetRemote(target); return end
    local ctx=app.Remote[target]
    if not ctx then
        ctx={Player=target,Items={},Hidden={},Revision=0,Alive=true,Connections={}}
        ctx.OnBodyInvalid=function() if ctx.Alive then dressRemote(ctx) end end
        app.Remote[target]=ctx
        table.insert(ctx.Connections,connect(target.CharacterAdded,function() task.defer(dressRemote,ctx) end))
        -- Внешность с сервера догрузилась после нашей примерки — одеваем заново
        table.insert(ctx.Connections,connect(target.CharacterAppearanceLoaded,function(ch)
            if ch==target.Character and ctx.Alive then dressRemote(ctx) end
        end))
    end
    ctx.Data=clean
    dressRemote(ctx)
end
local lookProvider={Export=app.ExportSync,Apply=app.ApplyRemote}
pcall(function()
    env.LookSync=env.LookSync or {Providers={}}
    env.LookSync.Providers.catalog=lookProvider
end)
connect(Players.PlayerRemoving,forgetRemote)

function app.Unload()
    if not app.Alive then return end
    pcall(function()
        if env.LookSync and env.LookSync.Providers.catalog==lookProvider then env.LookSync.Providers.catalog=nil end
    end)
    local remote={}; for target in pairs(app.Remote) do table.insert(remote,target) end
    for _,target in ipairs(remote) do forgetRemote(target) end
    app.Reset(); app.Alive=false; searchSerial+=1
    for _,c in ipairs(app.Connections) do c:Disconnect() end
    for _,v in pairs(app.Cache) do v.Template:Destroy() end
    app.Cache={}; if modalGui then modalGui:Destroy() end; gui:Destroy()
    if env.LocalCatalog==app then env.LocalCatalog=nil end
    portraitSignal:Fire(); portraitSignal:Destroy()
    if app.DropPortrait then app.DropPortrait() end
end
refresh(); search()
if carry and (#carry.AssetIds>0 or carry.HideOriginal) then
    run(function(rev)
        local failed=applyOutfit(carry,rev)
        return failed and #failed==0 and 'Your outfit was carried into the updated catalog' or 'Some previous outfit items could not load'
    end)
end
