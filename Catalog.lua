-- LocalCatalog v8. Client-only. Personalized browsing, makeup and resizable UI.
-- RightShift toggles the window. No place remotes, purchases or bundles.
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
    Version=8,KeepOnRespawn=true,HideOriginal=false,Restoring=false,Revision=0,SearchBusy=false,HeadOriginal=nil,
    Window={Width=1100,Height=736,Scale=1}}
env.LocalCatalog=app
-- These gates survive reloads so an old in-flight request cannot overlap a new instance.
env.LocalCatalogNetwork=env.LocalCatalogNetwork or {Search={Next=0},Avatar={Next=0},Metadata={}}
local network=env.LocalCatalogNetwork
local function limited(err)
    local s=string.lower(tostring(err))
    return s:find('429',1,true) or s:find('too many requests',1,true) or s:find('rate limit',1,true)
end
local function apiCall(lane,fn,active,gap)
    local function waitUntil(deadline)
        while os.clock()<deadline do if not active() then error('Операция отменена',0) end; task.wait(math.min(0.1,deadline-os.clock())) end
    end
    while lane.Busy do waitUntil(os.clock()+0.1) end
    assert(active(),'Операция отменена'); lane.Busy=true
    local ok,result=pcall(function()
        for attempt=1,4 do
            waitUntil(lane.Next or 0)
            assert(active(),'Операция отменена')
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
    if not ok then return 'Предмет' end
    local s=table.concat(result):gsub('%s+',' '):match('^%s*(.-)%s*$')
    return s~='' and s or 'Без названия'
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
    assert(app.Alive,'Каталог закрыт')
    local ch=player.Character
    assert(ch and ch.Parent and ch:FindFirstChildOfClass('Humanoid'),'Персонаж ещё загружается')
    return ch
end
local clothing={[2]='ShirtGraphic',[11]='Shirt',[12]='Pants',[18]='Decal'}
local makeup={[88]='Face',[89]='Lip',[90]='Eye'}
local accessory={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,
    [64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local function isCosmetic(o)
    return o:IsA('Accessory') or o:IsA('Shirt') or o:IsA('Pants') or o:IsA('ShirtGraphic')
end
local function hide(o)
    if not app.Hidden[o] then app.Hidden[o]=o.Parent; o.Parent=nil end
end
local function restoreHidden(predicate)
    local restore={}
    for o,parent in pairs(app.Hidden) do if predicate(o,parent) then table.insert(restore,{o,parent}) end end
    for _,v in ipairs(restore) do
        app.Hidden[v[1]]=nil
        if v[2] and v[2].Parent then pcall(function() v[1].Parent=v[2] end) else v[1]:Destroy() end
    end
end
local function remapHeadReferences(ch,fromHead,toHead)
    if not ch or not fromHead or not toHead then return end
    for _,o in ipairs(fromHead:GetChildren()) do
        if o:GetAttribute('LocalCatalogMakeup') then o.Parent=toHead end
    end
    for _,o in ipairs(ch:QueryDescendants('JointInstance, WeldConstraint')) do
        if o:IsA('JointInstance') then
            if o.Part0==fromHead then o.Part0=toHead end
            if o.Part1==fromHead then o.Part1=toHead end
        elseif o:IsA('WeldConstraint') then
            if o.Part0==fromHead then o.Part0=toHead end
            if o.Part1==fromHead then o.Part1=toHead end
        end
    end
end
local function restoreHead()
    local original=app.HeadOriginal
    if not original then return end
    local ch=app.HeadCharacter
    if ch and ch.Parent then
        local currentHead=ch:FindFirstChild('Head')
        if currentHead and currentHead~=original then
            original.CFrame=currentHead.CFrame
            remapHeadReferences(ch,currentHead,original)
            original.Parent=ch
            currentHead:Destroy()
        elseif not original.Parent then
            original.Parent=ch
        end
    elseif not original.Parent then
        original:Destroy()
    end
    app.HeadOriginal=nil; app.HeadCharacter=nil
end
local function destroyItem(id)
    local item=app.Items[id]
    if item then
        if item.Kind==79 then restoreHead()
        elseif item.Object and item.Object.Parent then item.Object:Destroy() end
        app.Items[id]=nil
    end
end
local function clearVisuals()
    if app.CloseDialogs then app.CloseDialogs() end
    if app.EditingId and app.CloseTransform then app.CloseTransform(false,true) end
    local ids={}; for id in pairs(app.Items) do table.insert(ids,id) end
    -- Restore a custom head last so head-bound accessory welds can be remapped cleanly.
    table.sort(ids,function(a,b) return (app.Items[a] and app.Items[a].Kind==79) and false or (app.Items[b] and app.Items[b].Kind==79) end)
    for _,id in ipairs(ids) do destroyItem(id) end
    restoreHead()
    restoreHidden(function() return true end)
end
local function hideOriginal(ch)
    local added={}; for _,it in pairs(app.Items) do added[it.Object]=true end
    for _,o in ipairs(ch:GetChildren()) do if isCosmetic(o) and not added[o] then hide(o) end end
    local head=ch:FindFirstChild('Head')
    if head then for _,o in ipairs(head:GetChildren()) do
        if o:IsA('Decal') and o:FindFirstChildOfClass('WrapTextureTransfer') and not added[o] then hide(o) end
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
    clearVisuals(); refresh(); message('Исходная внешность восстановлена')
end
local function attach(acc,ch,fit)
    local handle=acc:FindFirstChild('Handle')
    assert(handle and handle:IsA('BasePart'),'У аксессуара нет Handle')
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
    assert(part,'Не найдено крепление на персонаже')
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
            assert(v and v==v and math.abs(v)<math.huge,'Введите конечное число')
            values[axis]=math.clamp(v,key=='Scale' and 0.05 or (key=='Rotation' and -360 or -10),key=='Scale' and 5 or (key=='Rotation' and 360 or 10))
        end
    end
    return out
end
function app.SetTransform(id,data)
    local it=app.Items[id]
    assert(it and it.Weld,'Выберите надетый аксессуар')
    assert(not it.Layered,'Многослойная одежда не поддерживает Transform Item')
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
    if app.Desired[id] then app.Desired[id].Transform=t end
    if app.UpdateTransformFields then app.UpdateTransformFields(id) end
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
local function bodyContext(ch)
    local h=ch:FindFirstChildOfClass('Humanoid')
    local d=h:GetAppliedDescription()
    for _,it in pairs(app.Items) do if it.Kind==79 then d.Head=it.Id; break end end
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
        assert(chosen,'Roblox не вернул текстуру Makeup')
        return chosen
    end
    if accessory[kind] then
        local assetType
        for name,value in pairs(assetTypesByName) do if value==kind then assetType=Enum.AvatarAssetType[name]; break end end
        assert(assetType,'Неизвестный тип аксессуара')
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
                assert(active(),'Операция отменена')
                task.wait(0.05)
            until not advanced or #model:QueryDescendants('RigidConstraint')>0 or os.clock()>=deadline
            task.wait(0.1)
            for _,o in ipairs(model:GetChildren()) do
                if o:IsA('Accessory') then chosen=o; break end
            end
            assert(chosen,'Сборка аватара не вернула аксессуар')
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
    if kind==79 then
        description.Head=id
        local model=apiCall(network.Avatar,function() return Players:CreateHumanoidModelFromDescriptionAsync(description,rig) end,active,0.35)
        local head=model:FindFirstChild('Head')
        if head then head.Parent=nil end; model:Destroy()
        assert(head and head:IsA('MeshPart'),'Roblox не вернул Dynamic Head')
        return head
    end
    local objects=game:GetObjects('rbxassetid://'..string.format('%.0f',id))
    local chosen
    for _,root in ipairs(objects) do
        if root:IsA(clothing[kind]) then chosen=root; break end
        local candidates=root:QueryDescendants(clothing[kind])
        if candidates[1] then chosen=candidates[1]; chosen.Parent=nil; break end
    end
    for _,root in ipairs(objects) do if root~=chosen then root:Destroy() end end
    assert(chosen,'Roblox не вернул одежду для этого ID')
    return chosen
end

local function attachDynamicHead(head,ch)
    assert(head and head:IsA('MeshPart'),'Некорректный Dynamic Head')
    local currentHead=ch:FindFirstChild('Head')
    assert(currentHead and currentHead:IsA('BasePart'),'У персонажа нет головы')
    if not app.HeadOriginal then
        app.HeadOriginal=currentHead
        app.HeadCharacter=ch
        currentHead.Parent=nil
    end
    local original=app.HeadOriginal
    head.Name='Head'
    head.CFrame=original.CFrame
    head.Anchored=false; head.CanCollide=false; head.CanTouch=false; head.Massless=true
    head.Parent=ch
    remapHeadReferences(ch,original,head)
    return head
end

function app.WearAsync(rawId,expectedRevision,hint)
    local id=type(rawId)=='number' and rawId or tonumber(tostring(rawId):match('^%s*(%d+)%s*$') or tostring(rawId):match('/catalog/(%d+)'))
    assert(id and id>0 and id%1==0,'Введите ID предмета или ссылку на каталог')
    local ch=current(); local rev=expectedRevision or app.Revision
    assert(valid(rev,ch),'Операция отменена')
    if app.Items[id] and app.Items[id].Object.Parent then return 'Предмет уже надет' end

    local description,bodyKey,rig=bodyContext(ch)
    local cached=app.Cache[id]
    if cached and (accessory[cached.Kind] or makeup[cached.Kind] or cached.Kind==79) and cached.BodyKey~=bodyKey then
        cached.Template:Destroy(); app.Cache[id]=nil; cached=nil
    end
    if not cached then
        local chosen,fit,info
        local ok,err=pcall(function()
            info=itemMetadata(id,hint,function() return valid(rev,ch) end)
            assert(info.Kind==79 or accessory[info.Kind] or clothing[info.Kind] or makeup[info.Kind],'Этот тип не поддерживается. Части тела и бандлы отключены')
            chosen,fit=loadFittedWearable(id,info.Kind,description,rig,function() return valid(rev,ch) end)
            for _,scriptObject in ipairs(chosen:QueryDescendants('LuaSourceContainer')) do scriptObject:Destroy() end
            assert(valid(rev,ch),'Операция отменена')
        end)
        description:Destroy()
        if not ok then if chosen then chosen:Destroy() end; error(err,0) end
        chosen.Archivable=true
        cached={Template=chosen,Kind=info.Kind,Name=info.Name,Layered=#chosen:QueryDescendants('WrapLayer')>0,BodyKey=bodyKey,Fit=fit}
        app.Cache[id]=cached
    else description:Destroy() end

    local kind=cached.Kind
    local humanoid=ch:FindFirstChildOfClass('Humanoid')
    if cached.Layered then
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,'Многослойная одежда требует R15')
    end

    local chosen=cached.Template:Clone()
    local weld,base
    local ok,err=pcall(function()
        if kind==79 then
            local remove={}
            for key,item in pairs(app.Desired) do if item.Kind==79 and key~=id then table.insert(remove,key) end end
            for _,key in ipairs(remove) do destroyItem(key); app.Desired[key]=nil end
            attachDynamicHead(chosen,ch)
        elseif makeup[kind] then
            local head=ch:FindFirstChild('Head')
            assert(head and head:IsA('MeshPart') and head:FindFirstChildOfClass('WrapTarget'),'Makeup требует совместимую MeshPart-голову с WrapTarget')
            chosen:SetAttribute('LocalCatalogMakeup',true)
            chosen.Parent=head
        elseif accessory[kind] then
            weld,base=attach(chosen,ch,cached.Fit)
        else
            local parent=kind==18 and ch:FindFirstChild('Head') or ch
            assert(parent,'Голова ещё не загружена')
            local remove={}
            for key,item in pairs(app.Desired) do if item.Kind==kind then table.insert(remove,key) end end
            for _,key in ipairs(remove) do destroyItem(key); app.Desired[key]=nil end
            for _,o in ipairs(parent:GetChildren()) do if o:IsA(clothing[kind]) then hide(o) end end
            chosen.Parent=parent
        end
    end)
    if not ok then chosen:Destroy(); error(err) end

    local previous=app.Desired[id] and app.Desired[id].Transform
    local it={Id=id,Name=cached.Name,Kind=kind,Object=chosen,Weld=weld,Base=base,Layered=cached.Layered}
    app.Items[id]=it
    local order=hint and hint.LayerOrder
    if cached.Layered or makeup[kind] then
        if not order then
            order=1
            for _,v in pairs(app.Desired) do order=math.max(order,(v.LayerOrder or 0)+1) end
            if makeup[kind] then for _,o in ipairs(ch.Head:GetChildren()) do
                if o:IsA('Decal') and o~=chosen then order=math.max(order,o.ZIndex+1) end
            end end
        end
        for _,wrap in ipairs(chosen:QueryDescendants('WrapLayer')) do wrap.Order=order end
        if makeup[kind] then chosen.ZIndex=order end
    end
    it.LayerOrder=order
    app.Desired[id]={Id=id,Name=cached.Name,Kind=kind,LayerOrder=order}
    if weld and not cached.Layered then
        local h=chosen.Handle
        it.BaseSize=h.Size; it.BaseC1=weld.C1; it.BaseAttachments={}
        for _,a in ipairs(h:QueryDescendants('Attachment')) do it.BaseAttachments[a]=a.CFrame end
        it.Mesh=h:FindFirstChildOfClass('SpecialMesh')
        if it.Mesh then it.BaseMeshScale=it.Mesh.Scale; it.BaseMeshOffset=it.Mesh.Offset end
        app.SetTransform(id,previous or defaultTransform())
    end
    refresh(); return 'Надето: '..cached.Name
end
function app.Remove(id)
    if app.EditingId==id and app.CloseTransform then app.CloseTransform(false) end
    local item=app.Items[id] or app.Desired[id]; if not item then return end
    destroyItem(id); app.Desired[id]=nil
    if clothing[item.Kind] and not (app.HideOriginal and item.Kind~=18) then
        restoreHidden(function(o) return o:IsA(clothing[item.Kind]) end)
    end
    refresh(); message('Снято: '..item.Name)
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
    assert(type(writefile)=='function','Executor не поддерживает сохранение файлов')
    assert(not storageProblems[path],'Файл '..path..' повреждён; он сохранён без перезаписи')
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
        if type(readfile)=='function' then assert(readfile(path)==encoded,'Не удалось проверить запись файла') end
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
            for field,bounds in pairs({Width={1000,1800},Height={680,1100},Scale={0.6,1.6}}) do
                local n=tonumber(s.Window[field])
                if n and n==n then app.Window[field]=math.clamp(n,bounds[1],bounds[2]) end
            end
        end
    end)
end
local SavedOutfits={}
local SavedItems={}
local function saveOutfitLibrary()
    assert(type(writefile)=='function','Executor не поддерживает сохранение файлов')
    writeDocument(OUTFITS,{Version=1,Outfits=SavedOutfits})
end
local function saveFavoriteLibrary()
    assert(type(writefile)=='function','Executor не поддерживает сохранение файлов')
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
    local group=safeText(entry.Group or '')
    if group=='' or group=='Без названия' then return nil end
    local subName=entry.Sub and safeText(entry.Sub) or nil
    if subName=='Без названия' then subName=nil end
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
        Name=safeText(entry.Name or ('Образ '..tostring(index))),
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
                table.insert(SavedOutfits,{Id=Http:GenerateGUID(false),Name='Старый сохранённый образ',Data=data})
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
    assert(value~='Без названия','Введите название образа')
    local stop=utf8.offset(value,49)
    return stop and value:sub(1,stop-1) or value
end
function app.SaveOutfit(name,data)
    local entry={Id=Http:GenerateGUID(false),Name=outfitName(name),Data=data or app.ExportOutfit()}
    assert(normalizeSavedOutfit(entry,1),'Некорректный образ')
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
    error('Образ не найден')
end
function app.OverwriteOutfit(id,data)
    for _,entry in ipairs(SavedOutfits) do if entry.Id==id then
        local replacement=Http:JSONDecode(Http:JSONEncode(data or app.ExportOutfit()))
        assert(normalizeSavedOutfit({Id=entry.Id,Name=entry.Name,Data=replacement},1),'Некорректный образ')
        local previous=entry.Data; entry.Data=replacement
        local ok,err=pcall(saveOutfitLibrary)
        if not ok then entry.Data=previous; error(err,0) end
        return entry
    end end
    error('Образ не найден')
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
    message((app.KeepOnRespawn and 'После респавна выбранный образ будет восстановлен' or 'После респавна останется исходная внешность')..
        (persisted and '' or ' (настройка действует в этой сессии)'))
end
local function applyOutfit(data,rev)
    local failed,hints={},{}
    for _,item in ipairs(data.Items or {}) do if item.Id then hints[item.Id]=item end end
    if data.HideOriginal then app.SetHideOriginal(true) end
    for _,id in ipairs(data.AssetIds) do
        if not app.Alive or app.Revision~=rev then return nil end
        if not app.Desired[id] then
            local hint=hints[id] or {}
            app.Desired[id]={Id=id,Name=hint.Name or ('ID '..string.format('%.0f',id)),Kind=kindFromHint(hint),LayerOrder=hint.LayerOrder,
                Transform=data.Transforms and data.Transforms[string.format('%.0f',id)]}
        end
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
function app.HandleCharacterAdded(ch)
    if not app.Alive then return end
    app.Revision+=1
    local rev=app.Revision
    clearVisuals(); app.Busy=false
    if not app.KeepOnRespawn then
        app.Desired={}; app.HideOriginal=false; app.Restoring=false
        refresh(); message('Респавн: оставлена исходная внешность'); return
    end
    local outfit=app.ExportOutfit()
    if #outfit.AssetIds==0 and not outfit.HideOriginal then app.Restoring=false; refresh(); return end
    app.Restoring=true; refresh(); message('Респавн: ждём загрузки внешности...')
    task.spawn(function()
        local started=os.clock()
        while valid(rev,ch) and (not ch.Parent or not ch:FindFirstChildOfClass('Humanoid') or not ch:FindFirstChild('Head')) do
            if os.clock()-started>15 then
                app.Restoring=false; refresh(); message('Персонаж не загрузился. Нажмите «Повторить»',true); return
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
        if not ok then message('Не удалось восстановить образ. Нажмите «Повторить»',true)
        elseif failed and #failed>0 then message('Не удалось надеть: '..table.concat(failed,', ')..'. Нажмите «Повторить»',true)
        else message('Образ восстановлен после респавна') end
    end)
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
    if app.Busy or app.Restoring then message('Подождите: примеряем вещи...'); return end
    app.Busy=true; local rev=app.Revision; if updateControls then updateControls() end; message('Загрузка предмета...')
    task.spawn(function()
        local ok,result=pcall(fn,rev)
        if not app.Alive or rev~=app.Revision then return end
        app.Busy=false; refresh()
        message(ok and (result or 'Готово') or ('Не удалось выполнить: '..tostring(result)),not ok)
    end)
end
local title=label('Каталог',22,10,140,36,nil,28)
title.Font=Enum.Font.SourceSansBold; title.Active=true
label('Локальная примерка',170,15,220,26,nil,16).TextColor3=C.Muted
button('Свернуть',890,14,102,34,function() if app.CloseDialogs then app.CloseDialogs() end; panel.Visible=false end)
button('Закрыть',1000,14,78,34,function() app.Unload() end)
local toggle=button('Каталог',14,130,116,40,function() if app.ToggleWindow then app.ToggleWindow() else panel.Visible=not panel.Visible end end,gui,true)
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
local query=input('Поиск по каталогу',20,106,452,40)
query.Name='SearchInput'
local searchButton=button('Найти',480,106,90,40,nil,nil,true)
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
local function sub(name,types,keyword,free) return {Name=name,Types=types,Keyword=keyword,Free=free} end
-- Catalog Avatar Creator's wearable hierarchy, with body/bundle categories excluded.
local categories={
    {Name='Аксессуары',Sub={
        sub('Все',rigid),sub('Бесплатные',rigid,nil,true),sub('Головные уборы',{'Hat'}),sub('На лицо',{'FaceAccessory'}),
        sub('На шею',{'NeckAccessory'}),sub('На плечи',{'ShoulderAccessory'}),sub('Спереди',{'FrontAccessory'}),
        sub('На спину',{'BackAccessory'}),sub('На пояс',{'WaistAccessory'}),sub('В руках',handheld,',Handheld,Holdable'),
        sub('Эффекты',rigid,',Filter,Aura,Confetti,Sparkles')}},
    {Name='Волосы',Sub={sub('Все волосы',{'HairAccessory'}),sub('Бесплатные',{'HairAccessory'},nil,true),
        sub('Чёлки',{'FaceAccessory'},'Hair Bangs'),sub('Пряди',rigid,',Extensions')}},
    {Name='Одежда',Sub={
        sub('Класс. футболки',{'TShirt'}),sub('Класс. рубашки',{'Shirt'}),sub('Класс. брюки',{'Pants'}),sub('Классическая',classic),
        sub('Вся одежда',allClothes),sub('Бесплатная',allClothes,nil,true),sub('Многослойная',layered),
        sub('Футболки',{'TShirtAccessory'}),sub('Брюки',{'PantsAccessory'}),sub('Куртки',{'JacketAccessory'}),
        sub('Рубашки',{'ShirtAccessory'}),sub('Свитеры',{'SweaterAccessory'}),sub('Шорты',{'ShortsAccessory'}),
        sub('Платья / юбки',{'DressSkirtAccessory'}),sub('Обувь',{'LeftShoeAccessory','RightShoeAccessory'})}},
    {Name='Makeup',Sub={sub('All',makeupTypes),sub('Eyes',{'EyeMakeup'}),sub('Lips',{'LipMakeup'}),
        sub('Face',{'FaceMakeup'}),sub('Eyelashes',{'EyelashAccessory'}),sub('Eyebrows',{'EyebrowAccessory'})}},
    {Name='Collectibles',Sub={sub('All',wearableTypes),sub('Accessories',collectibleAccessories),sub('Faces',{'Face'})}},
    {Name='Сохранённое',SavedRoot=true},
}
for _,entry in ipairs(categories[5].Sub) do entry.SalesTypeFilter='Collectibles' end
app.Categories=categories
local category,subcategory=1,1
local savedSection='Образы'
local savedGroup='Все'
local function avatarTypeName(value)
    if typeof and typeof(value)=='EnumItem' then return value.Name end
    if type(value)=='string' then return value end
    return nil
end
local accessoryFavoriteSub={Hat='Головные уборы',FaceAccessory='На лицо',NeckAccessory='На шею',ShoulderAccessory='На плечи',FrontAccessory='Спереди',BackAccessory='На спину',WaistAccessory='На пояс'}
local clothingFavoriteSub={TShirt='Класс. футболки',Shirt='Класс. рубашки',Pants='Класс. брюки',TShirtAccessory='Футболки',PantsAccessory='Брюки',JacketAccessory='Куртки',ShirtAccessory='Рубашки',SweaterAccessory='Свитеры',ShortsAccessory='Шорты',DressSkirtAccessory='Платья / юбки',LeftShoeAccessory='Обувь',RightShoeAccessory='Обувь'}
local function favoritePlacement(item)
    local cat=categories[category]
    local selected=cat and cat.Sub and cat.Sub[subcategory]
    local group=cat and cat.Name or 'Аксессуары'
    local subName=selected and selected.Name or nil
    local assetName=avatarTypeName(item.AssetType)
    if table.find(makeupTypes,assetName) then return 'Makeup',assetName end
    if group=='Collectibles' then
        if table.find(allClothes,assetName) then return 'Одежда',clothingFavoriteSub[assetName] end
        if assetName=='HairAccessory' then return 'Волосы',nil end
        return 'Аксессуары',accessoryFavoriteSub[assetName] or 'Лица'
    end
    if group=='Аксессуары' and (subName=='Все' or subName=='Бесплатные') then subName=accessoryFavoriteSub[assetName]
    elseif group=='Волосы' and (subName=='Все волосы' or subName=='Бесплатные') then subName=nil
    elseif group=='Одежда' and (subName=='Вся одежда' or subName=='Бесплатная' or subName=='Многослойная' or subName=='Классическая') then subName=clothingFavoriteSub[assetName]
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
make('UIGridLayout',{CellSize=UDim2.fromOffset(180,211),CellPadding=UDim2.fromOffset(8,10),SortOrder=Enum.SortOrder.LayoutOrder},results)
make('UIPadding',{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingBottom=UDim.new(0,8)},results)
local empty=label('Загрузка каталога...',120,320,556,90,nil,22)
empty.Name='EmptyResults'; empty.TextXAlignment=Enum.TextXAlignment.Center; empty.TextColor3=C.Muted
local moreButton=button('Загрузить ещё',20,598,756,36)
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
    local nameBox=make('TextBox',{Text=initialText or '',PlaceholderText='Название образа',Position=UDim2.fromOffset(20,67),Size=UDim2.fromOffset(430,42),BackgroundColor3=C.Surface,TextColor3=C.Text,PlaceholderColor3=C.Muted,Font=Enum.Font.SourceSans,TextSize=19,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},boxFrame)
    corner(nameBox); make('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,10)},nameBox)
    local notice=modalLabel(boxFrame,'',20,112,430,25,15); notice.TextColor3=Color3.fromRGB(255,156,157)
    modalButton(boxFrame,'Отмена',20,151,205,40,clearModal,false)
    local submitted=false
    local function submit()
        if submitted then return end
        local name=safeText(nameBox.Text)
        local stop=utf8.offset(name,49); if stop then name=name:sub(1,stop-1) end
        if name=='' or name=='Без названия' then notice.Text='Введите название образа'; return end
        submitted=true; clearModal(); onDone(name)
    end
    modalButton(boxFrame,'Сохранить',245,151,205,40,submit,true)
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
    modalButton(f,'Отмена',20,161,205,40,clearModal,false).Name='Cancel'
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
        assert(ok and item,'Неизвестное значение: '..field)
        result[field]=candidate
    end
    result.CreatorName=tostring(value.CreatorName or ''):match('^%s*(.-)%s*$')
    result.IncludeOffSale=value.IncludeOffSale~=false
    result.PersonalizedResults=value.PersonalizedResults~=false
    for _,field in ipairs({'MinPrice','MaxPrice'}) do
        local raw=value[field]
        if raw~=nil and tostring(raw):match('%S') then
            local n=tonumber(raw)
            assert(n and n==n and n>=0 and n<=2147483647 and n%1==0,'Цена должна быть целым числом от 0 до 2147483647')
            result[field]=n
        end
    end
    assert(not result.MinPrice or not result.MaxPrice or result.MinPrice<=result.MaxPrice,'Минимальная цена больше максимальной')
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
    local periods={{'AllTime','За всё время'},{'Past12Hours','За 12 часов'},{'PastDay','За сутки'},{'Past3Days','За 3 дня'},{'PastWeek','За неделю'},{'PastMonth','За месяц'}}
    local creatorTypes={{'All','Все авторы'},{'User','Пользователь'},{'Group','Группа'}}
    local function openSearchOptions()
        clearModal(); modalShade.Visible=true
        local draft=table.clone(app.SearchOptions)
        local f=make('Frame',{Name='SearchOptionsDialog',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(610,554),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
        make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
        modalLabel(f,'Search Options',24,16,430,36,26).Font=Enum.Font.SourceSansBold
        modalButton(f,'X',548,18,38,34,clearModal)
        modalLabel(f,'Настройте поиск, затем нажмите «Применить».',24,57,560,24,17).TextColor3=C.Muted
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
        modalLabel(f,'Сортировка',24,91,270,24,17).TextColor3=C.Muted
        local periodLabel=modalLabel(f,'Период',312,91,270,24,17)
        local period,updatePeriod
        local function updatePeriodState()
            local active=draft.SortType=='Bestselling' or draft.SortType=='MostFavorited'
            period.Visible=active; periodLabel.Visible=active
        end
        local _,updateSort=selectField('SortType',sortChoices,24,119,270,updatePeriodState)
        period,updatePeriod=selectField('SortAggregation',periods,312,119,274)
        updatePeriodState()
        modalLabel(f,'Цена в Robux',24,171,562,24,17).TextColor3=C.Muted
        local min=field('MinPrice','От',24,199,270,draft.MinPrice and tostring(draft.MinPrice))
        local max=field('MaxPrice','До',312,199,274,draft.MaxPrice and tostring(draft.MaxPrice))
        modalLabel(f,'Автор',24,251,562,24,17).TextColor3=C.Muted
        local creator=field('CreatorName','Имя пользователя или группы',24,279,348,draft.CreatorName)
        local _,updateCreator=selectField('CreatorType',creatorTypes,384,279,202)
        local offSale=modalButton(f,'',24,337,562,38,function() end)
        offSale.Name='IncludeOffSale'
        local function updateOffSale()
            offSale.Text=(draft.IncludeOffSale and 'ВКЛ' or 'ВЫКЛ')..'  ·  Показывать вещи не в продаже'
            offSale.BackgroundColor3=draft.IncludeOffSale and C.Green or C.Card
        end
        offSale.Activated:Connect(function() closeDropdown(); draft.IncludeOffSale=not draft.IncludeOffSale; updateOffSale() end)
        updateOffSale()
        local personalized=modalButton(f,'',24,384,562,38,nil)
        personalized.Name='PersonalizedResults'
        local function updatePersonalized()
            personalized.Text=(draft.PersonalizedResults and 'ВКЛ' or 'ВЫКЛ')..'  ·  Personalized Results'
            personalized.BackgroundColor3=draft.PersonalizedResults and C.Green or C.Card
        end
        personalized.Activated:Connect(function() closeDropdown(); draft.PersonalizedResults=not draft.PersonalizedResults; updatePersonalized() end)
        updatePersonalized()
        modalLabel(f,'Для рекомендаций: пустой запрос, Relevance и вещи в продаже.',24,425,562,30,15).TextColor3=C.Muted
        local notice=modalLabel(f,'',24,458,562,26,16); notice.TextColor3=Color3.fromRGB(255,160,150)
        modalButton(f,'Сбросить',24,493,156,40,function()
            closeDropdown(); draft=table.clone(defaultSearchOptions)
            min.Text=''; max.Text=''; creator.Text=''; notice.Text=''
            updateSort(); updatePeriod(); updateCreator(); updatePeriodState(); updateOffSale(); updatePersonalized()
        end).Name='ResetOptions'
        modalButton(f,'Отмена',292,493,136,40,clearModal).Name='CancelOptions'
        modalButton(f,'Применить',440,493,146,40,function()
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
        return failed and #failed==0 and ('Надет образ: '..entry.Name) or ('Образ загружен не полностью: '..table.concat(failed or {},', '))
    end)
end
local function openOutfitPreview(entry)
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(620,590),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f)
    corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    local t=modalLabel(f,entry.Name,22,14,500,34,26); t.Font=Enum.Font.SourceSansBold
    modalButton(f,'X',558,14,40,34,clearModal,false)
    modalLabel(f,'Вы хотите экипировать данный образ?',22,53,560,28,18).TextColor3=C.Muted
    local list=make('ScrollingFrame',{Position=UDim2.fromOffset(22,92),Size=UDim2.fromOffset(576,404),BackgroundColor3=C.Surface,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4},f)
    corner(list); make('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},list); make('UIPadding',{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)},list)
    local items=outfitItems(entry.Data)
    if #items==0 then
        local none=modalLabel(list,'В образе нет добавленных предметов.',8,8,530,52,18); none.Size=UDim2.new(1,-16,0,52); none.TextColor3=C.Muted
    else
        for i,item in ipairs(items) do
            local row=make('Frame',{Size=UDim2.new(1,-8,0,66),LayoutOrder=i,BackgroundColor3=C.Card,BorderSizePixel=0},list); corner(row)
            make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',item.Id)..'&w=150&h=150',Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(52,52),BackgroundTransparency=1},row)
            local n=modalLabel(row,item.Name,70,8,460,28,17); n.TextTruncate=Enum.TextTruncate.AtEnd
            local idLabel=modalLabel(row,'ID: '..string.format('%.0f',item.Id),70,35,460,22,15); idLabel.TextColor3=C.Muted
        end
    end
    local originalText=entry.Data.HideOriginal and 'Исходные вещи будут скрыты.' or 'Исходные вещи останутся видимыми.'
    modalLabel(f,originalText,22,503,360,24,15).TextColor3=C.Muted
    modalButton(f,'Отмена',391,510,95,48,clearModal,false)
    modalButton(f,'Экипировать',497,510,101,48,function() clearModal(); equipSavedOutfit(entry) end,true)
end
local function confirmOverwrite(entry,data)
    if app.Busy or app.Restoring then message('Подождите окончания примерки'); return end
    local snapshot=data or app.ExportOutfit()
    openConfirmDialog('Перезаписать образ?',
        '«'..entry.Name..'» будет заменён текущим образом ('..#snapshot.AssetIds..' предм.). Имя сохранится.',
        'Перезаписать',function()
            local ok,err=pcall(app.OverwriteOutfit,entry.Id,snapshot)
            if ok then message('Образ обновлён: '..entry.Name) else message(err,true) end
            if categories[category].SavedRoot and savedSection=='Образы' then renderSavedOutfits() end
        end)
end
local function openOutfitActions(entry)
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{Name='OutfitActions',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(470,288),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    modalLabel(f,entry.Name,20,16,368,36,24).TextTruncate=Enum.TextTruncate.AtEnd
    modalButton(f,'X',410,18,38,32,clearModal)
    modalButton(f,'Перезаписать текущим образом',20,76,430,48,function() confirmOverwrite(entry) end,true).Name='OverwriteOutfit'
    modalButton(f,'Переименовать',20,138,430,48,function()
        openNameDialog('Переименовать образ',entry.Name,function(name)
            local ok,err=pcall(app.RenameOutfit,entry.Id,name)
            if not ok then message(err,true) end
            renderSavedOutfits()
        end)
    end).Name='RenameOutfit'
    modalButton(f,'Удалить образ',20,212,430,44,function()
        openConfirmDialog('Удалить образ?','«'..entry.Name..'» будет удалён из сохранённого.','Удалить',function()
            local ok,err=pcall(app.DeleteOutfit,entry.Id)
            if not ok then message(err,true) end
            renderSavedOutfits()
        end)
    end).Name='DeleteOutfit'
end
renderSavedOutfits=function()
    clearResults(); pages=nil; app.SearchBusy=false
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Поиск в сохранённом...'; searchButton.Text='Найти'
    empty.Visible=#SavedOutfits==0
    empty.Text='Сохранённых образов пока нет.\nСоберите образ и нажмите «Сохранить».'
    for index,entry in ipairs(SavedOutfits) do
        if filterMatch(entry.Name) then
        local card=make('Frame',{Name='SavedOutfit',LayoutOrder=index,BackgroundColor3=C.Card,BorderSizePixel=0},results); corner(card); resultCount+=1
        local items=outfitItems(entry.Data)
        for j=1,math.min(3,#items) do
            make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',items[j].Id)..'&w=150&h=150',Size=UDim2.fromOffset(48,48),Position=UDim2.fromOffset(9+(j-1)*53,10),BackgroundTransparency=1},card)
        end
        if #items==0 then modalLabel(card,'Пустой образ',12,18,156,34,16).TextColor3=C.Muted end
        local n=label(entry.Name,10,66,160,39,card,17); n.TextTruncate=Enum.TextTruncate.AtEnd; n.Font=Enum.Font.SourceSansSemibold
        local count=label('Предметов: '..#items,10,107,160,22,card,15); count.TextColor3=C.Muted
        card:SetAttribute('OutfitId',entry.Id)
        button('Открыть',10,136,160,30,function() openOutfitPreview(entry) end,card,true).Name='PreviewOutfit'
        button('Управление',10,173,160,28,function() openOutfitActions(entry) end,card).Name='ManageOutfit'
    end
        end
    empty.Visible=resultCount==0
    moreButton.Text='Сохранённые образы: '..resultCount; moreButton.Active=false; moreButton.AutoButtonColor=false
end
local function openSaveDialog(data)
    local function createNew()
        openNameDialog('Сохранить образ','Образ '..tostring(#SavedOutfits+1),function(name)
            local ok,err=pcall(app.SaveOutfit,name,data)
            if not ok then message(err,true); return end
            message('Сохранено: '..name)
            if categories[category].SavedRoot and savedSection=='Образы' then renderSavedOutfits() end
        end)
    end
    if #SavedOutfits==0 then createNew(); return end
    clearModal(); modalShade.Visible=true
    local f=make('Frame',{Name='SaveOutfitDialog',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(510,440),BackgroundColor3=C.Bg,BorderSizePixel=0},modalShade)
    make('UIScale',{Scale=scale.Scale},f); corner(f,14); make('UIStroke',{Color=C.Border,Thickness=1},f)
    modalLabel(f,'Сохранить текущий образ',20,16,420,36,24)
    modalButton(f,'X',452,18,38,32,clearModal)
    modalButton(f,'Создать новый образ',20,72,470,44,createNew,true).Name='CreateNew'
    modalLabel(f,'Или выберите образ для перезаписи:',20,133,470,28,18).TextColor3=C.Muted
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
    assert(id and id>0,'У предмета нет корректного ID')
    local old=SavedItems[id]
    SavedItems[id]={Id=id,Name=safeText(item.Name or ('ID '..string.format('%.0f',id))),AssetType=avatarTypeName(item.AssetType),Group=group,Sub=subName}
    local ok,err=pcall(saveFavoriteLibrary)
    if not ok then SavedItems[id]=old; error(err) end
end
local function toggleFavorite(item,group,subName)
    local id=tonumber(item.Id)
    if isFavorite(id) then
        if not removeFavorite(id) then return end
        message('Удалено из сохранённого: '..safeText(item.Name))
    else
        local ok,err=pcall(addFavorite,item,group,subName)
        if not ok then message(err,true); return end
        message('Сохранено: '..safeText(item.Name))
    end
    if renderCategories then renderCategories() end
    local cat=categories[category]
    if cat and cat.SavedRoot and savedSection~='Образы' and renderSavedItems then renderSavedItems(savedGroup)
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
local function renderItemCard(item,group,subName)
    local id=tonumber(item.Id)
    if cardButtons[id] then return end
    local card=make('Frame',{Name='Item_'..string.format('%.0f',id),LayoutOrder=resultCount,BackgroundColor3=C.Card,BorderSizePixel=0},results)
    corner(card); resultCount+=1
    make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',id)..'&w=150&h=150',Size=UDim2.fromOffset(126,120),Position=UDim2.fromOffset(27,3),BackgroundTransparency=1},card)
    local fav=button('',138,7,34,34,function() toggleFavorite(item,group,subName) end,card)
    fav.Name='Favorite'; favoriteButtons[id]=fav
    make('ImageLabel',{Name='Star',Image='rbxassetid://7537715511',AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(23,23),BackgroundTransparency=1,ImageColor3=C.Muted,ScaleType=Enum.ScaleType.Fit},fav)
    local name=label(item.Name,10,125,160,41,card,17); name.TextTruncate=Enum.TextTruncate.AtEnd
    local b=button('Примерить',10,171,160,32,function()
        run(function(rev)
            if app.Items[id] then app.Remove(id); return 'Предмет снят' end
            return app.WearAsync(id,rev,{Name=item.Name,AssetType=item.AssetType})
        end)
    end,card,true)
    b.Name='Wear'; cardButtons[id]=b
end
renderSavedItems=function(group)
    clearResults(); pages=nil; app.SearchBusy=false
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Поиск в сохранённом...'; searchButton.Text='Найти'
    local items={}
    for _,entry in pairs(SavedItems) do
        if group=='Все' or entry.Group==group then table.insert(items,entry) end
    end
    table.sort(items,function(a,b) return (a.Name or '')<(b.Name or '') end)
    empty.Visible=#items==0
    empty.Text='Здесь пока нет избранных вещей.\nНажмите звёздочку на карточке в каталоге.'
    for _,item in ipairs(items) do
        if filterMatch(item.Name,item.Id) then renderItemCard(item,item.Group,item.Sub) end
    end
    empty.Visible=resultCount==0
    moreButton.Text='Найдено в избранном: '..resultCount; moreButton.Active=false; moreButton.AutoButtonColor=false
    refresh()
end
local function refreshCards()
    for id,b in pairs(cardButtons) do
        local worn=app.Items[id]~=nil
        b.Text=worn and 'Снять' or 'Примерить'
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
        if item.ItemType=='Asset' and not cardButtons[item.Id] then
            local group,subName=favoritePlacement(item)
            renderItemCard(item,group,subName)
        end
    end
    empty.Visible=resultCount==0
    empty.Text='Ничего не найдено.\nПопробуйте другое название или категорию.'
    moreButton.Text=pages.IsFinished and ('Все результаты: '..resultCount) or ('Загрузить ещё  |  Показано: '..resultCount)
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
    p.SortType=Enum.CatalogSortType[options.SortType]
    p.SortAggregation=Enum.CatalogSortAggregation[options.SortAggregation]
    p.CreatorType=Enum.CreatorTypeFilter[options.CreatorType]
    p.CreatorName=options.CreatorName
    if options.MinPrice then p.MinPrice=options.MinPrice end
    if options.MaxPrice then p.MaxPrice=options.MaxPrice end
    p.SalesTypeFilter=Enum.SalesTypeFilter[selected.SalesTypeFilter or 'All']
    local types={}; for _,name in ipairs(selected.Types) do table.insert(types,Enum.AvatarAssetType[name]) end
    p.AssetTypes=types
    return p
end
local function catalogPages(selected,keyword,active,options)
    local p=app.BuildCatalogParams(selected,keyword,options)
    local key=Http:JSONEncode({selected.Types,p.SearchKeyword,p.SortType.Name,p.SortAggregation.Name,
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
        if savedSection=='Образы' then renderSavedOutfits() else renderSavedItems(savedGroup) end
        return
    end
    local selected=cat.Sub[subcategory]; local keyword=query.Text; local options=table.clone(app.SearchOptions)
    query.Visible=true; searchButton.Visible=true; query.PlaceholderText='Поиск по каталогу'
    app.SearchBusy=true; searchButton.Text='Поиск...'; pages=nil
    clearResults(); empty.Visible=true; empty.Text='Ищем вещи...'
    moreButton.Active=false; moreButton.Text='Подождите...'
    task.spawn(function()
        task.wait(0.35)
        local function active() return app.Alive and token==searchSerial end
        if not active() then return end
        local ok,result=pcall(catalogPages,selected,keyword,active,options)
        if not app.Alive or token~=searchSerial then return end
        app.SearchBusy=false; searchButton.Text='Найти'
        if ok then pages=result; renderPage()
        else empty.Text='Каталог не ответил.\nНажмите «Найти», чтобы повторить.'; moreButton.Text='Нет результатов'; message(result,true) end
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
        chip('Outfits','Образы',104,savedSection=='Образы',function()
            savedSection='Образы'; query.Text=''; renderCategories(); search()
        end,1)
        chip('Favorites','Избранное',122,savedSection=='Избранное',function()
            savedSection='Избранное'; query.Text=''; renderCategories(); search()
        end,2)
        if savedSection=='Избранное' then
            for i,group in ipairs({'Все','Аксессуары','Волосы','Одежда','Makeup'}) do
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
    app.SearchBusy=true; moreButton.Text='Загрузка...'
    local token=searchSerial; local currentPages=pages
    task.spawn(function()
        local ok,err=pcall(function() currentPages:AdvanceToNextPageAsync() end)
        if not app.Alive or token~=searchSerial then return end
        app.SearchBusy=false
        if ok then renderPage() else moreButton.Text='Повторить загрузку'; message(err,true) end
    end)
end)
local wornTitle=label('Ваш образ',794,106,170,36,nil,23)
local retry=button('Повторить',978,111,100,30,function()
    if not app.Busy and not app.Restoring then run(function(rev)
        local failed=applyOutfit(app.ExportOutfit(),rev)
        return failed and #failed==0 and 'Все вещи надеты' or 'Некоторые вещи недоступны'
    end) end
end)
retry.TextSize=16
local worn=make('ScrollingFrame',{Name='Worn',Position=UDim2.fromOffset(792,154),Size=UDim2.fromOffset(288,230),BackgroundColor3=C.Surface,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4},panel)
corner(worn)
make('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},worn)
make('UIPadding',{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingBottom=UDim.new(0,8)},worn)
local wornEmpty=label('Пока ничего не добавлено.\nНажмите «Примерить» на карточке.',814,219,245,100,nil,18)
wornEmpty.TextColor3=C.Muted; wornEmpty.TextXAlignment=Enum.TextXAlignment.Center
redraw=function()
    for _,o in ipairs(worn:GetChildren()) do if o:IsA('Frame') then o:Destroy() end end
    local items={}; for _,it in pairs(app.Desired) do table.insert(items,it) end
    table.sort(items,function(a,b) return a.Name<b.Name end)
    wornTitle.Text='Ваш образ ('..#items..')'; wornEmpty.Visible=#items==0
    for i,it in ipairs(items) do
        local row=make('Frame',{Size=UDim2.fromOffset(267,92),LayoutOrder=i,BackgroundColor3=C.Card,BorderSizePixel=0},worn)
        corner(row)
        make('ImageLabel',{Image='rbxthumb://type=Asset&id='..string.format('%.0f',it.Id)..'&w=150&h=150',
            Position=UDim2.fromOffset(3,5),Size=UDim2.fromOffset(50,50),BackgroundTransparency=1},row)
        local n=label(it.Name,60,5,201,41,row,16); n.TextTruncate=Enum.TextTruncate.AtEnd
        if not app.Items[it.Id] then n.TextColor3=C.Muted end
        button('Снять',186,53,74,30,function()
            if not app.Busy and not app.Restoring then app.Remove(it.Id) end
        end,row).TextSize=16
        local equipped=app.Items[it.Id]
        if equipped and equipped.Weld and not equipped.Layered then
            button('Transform Item',60,53,118,30,function() app.OpenTransform(it.Id) end,row).TextSize=16
        elseif equipped and makeup[equipped.Kind] then
            button('Слой -',60,53,56,30,function() app.MoveMakeupLayer(it.Id,-1) end,row).TextSize=15
            button('Слой +',121,53,56,30,function() app.MoveMakeupLayer(it.Id,1) end,row).TextSize=15
        end
    end
    refreshCards()
end
local hideButton=button('Скрыть исходные вещи',792,445,288,38,function()
    if app.Busy or app.Restoring then return end
    local ok,err=pcall(app.SetHideOriginal,not app.HideOriginal)
    if ok then message(app.HideOriginal and 'Исходные вещи скрыты' or 'Исходные вещи снова видны') else message(err,true) end
end)
hideButton.Name='HideOriginal'
button('Вернуть исходный образ',792,493,288,38,function() app.Reset() end).Name='ResetOutfit'
local saveButton=button('Сохранить образ',792,397,288,38,function()
    if app.Busy or app.Restoring then message('Подождите окончания примерки'); return end
    if type(writefile)~='function' then message('Executor не поддерживает сохранение файлов',true); return end
    local data=app.ExportOutfit()
    if #data.AssetIds==0 and not data.HideOriginal then message('Сначала добавьте хотя бы один предмет',true); return end
    openSaveDialog(data)
end,nil,true)
saveButton.Name='SaveOutfit'
local setting=make('Frame',{Name='RespawnSetting',Position=UDim2.fromOffset(792,548),Size=UDim2.fromOffset(288,128),BackgroundColor3=C.Surface,BorderSizePixel=0},panel)
corner(setting)
label('Образ после респавна',12,9,257,26,setting,20).Font=Enum.Font.SourceSansSemibold
local keepButton=button('ВКЛ',12,45,70,31,function() app.SetKeepOnRespawn(not app.KeepOnRespawn) end,setting)
keepButton.Name='KeepOnRespawn'
local keepLabel=label('Сохранять',94,45,180,31,setting,18)
local keepHelp=label('Автоматически надеть выбранные вещи.',12,81,260,38,setting,16)
keepHelp.TextColor3=C.Muted
updateControls=function()
    keepButton.Text=app.KeepOnRespawn and 'ВКЛ' or 'ВЫКЛ'
    keepButton.BackgroundColor3=app.KeepOnRespawn and C.Green or C.Card
    keepLabel.Text=app.KeepOnRespawn and 'Сохранять' or 'Сбрасывать'
    keepHelp.Text=app.KeepOnRespawn and 'Вернуть вещи и скрытие оригинала.' or 'Оставить внешность, которую выдаёт плейс.'
    hideButton.Text=app.HideOriginal and 'Показать исходные вещи' or 'Скрыть исходные вещи'
    hideButton.BackgroundColor3=app.HideOriginal and C.Green or C.Card
    refreshCards()
end
local assetId=input('ID предмета или ссылка roblox.com/catalog/...',20,650,596,38)
assetId.Name='AssetIdInput'
local wearId=button('Примерить ID',626,650,150,38,function() run(function(rev) return app.WearAsync(assetId.Text,rev) end) end,nil,true)
wearId.Name='WearId'
assetId.FocusLost:Connect(function(enter)
    if enter then run(function(rev) return app.WearAsync(assetId.Text,rev) end) end
end)
label('RightShift',720,15,150,26,nil,16).TextColor3=C.Muted
status=label('Выберите категорию или введите название вещи.',22,696,1056,26,nil,17)
status.Name='Status'; status.TextTruncate=Enum.TextTruncate.AtEnd
do
    local sizeLabel=label('100%',433,15,62,26,nil,16)
    sizeLabel.TextXAlignment=Enum.TextXAlignment.Center
    local minus=button('-',396,14,32,32,function() app.SetInterfaceScale(app.Window.Scale-0.1) end)
    local plus=button('+',500,14,32,32,function() app.SetInterfaceScale(app.Window.Scale+0.1) end)
    minus.Name='ScaleDown'; plus.Name='ScaleUp'
    local reset=button('Сброс UI',544,14,112,32,function()
        app.Window={Width=1100,Height=736,Scale=1}; app.LayoutWindow(); fit(); saveSettings()
    end)
    reset.Name='ResetWindow'
    local layouts={}
    for _,o in ipairs(panel:GetChildren()) do if o:IsA('GuiObject') and o~=dragHeader then
        layouts[o]={X=o.Position.X.Offset,Y=o.Position.Y.Offset,W=o.Size.X.Offset,H=o.Size.Y.Offset}
        if o:IsA('GuiButton') and o.Position.Y.Offset<54 then o.ZIndex=4 end
    end end
    local grip=button('◢',0,0,26,26,nil)
    grip.Name='ResizeGrip'; grip.Text=''; grip.AnchorPoint=Vector2.new(1,1); grip.Position=UDim2.new(1,-5,1,-5); grip.ZIndex=5
    for i=1,3 do make('Frame',{Position=UDim2.fromOffset(7+i*4,19-i*4),Size=UDim2.fromOffset(2,5+i*3),Rotation=45,BackgroundColor3=C.Muted,BorderSizePixel=0},grip) end
    function app.LayoutWindow()
        local dw,dh=app.Window.Width-1100,app.Window.Height-736
        panel.Size=UDim2.fromOffset(app.Window.Width,app.Window.Height)
        for o,b in pairs(layouts) do
            local x,y,w,h=b.X,b.Y,b.W,b.H
            if b.X>=792 then
                x+=dw
                if b.Y>=397 then y+=dh end
                if o==worn then h+=dh end
                if o==wornEmpty then y+=dh/2 end
            elseif o==categoryPanel or o==subPanel then w+=dw
            elseif o==results then w+=dw; h+=dh
            elseif o==query then w=(categories[category].SavedRoot and 658 or 452)+dw
            elseif o==searchButton then x=(categories[category].SavedRoot and 686 or 480)+dw
            elseif o==optionsButton or o.Name=='NextSubcategories' then x+=dw
            elseif o==empty then x+=dw/2; y+=dh/2
            elseif o==moreButton or o==assetId or o==status then w+=dw; y+=dh
            elseif o==wearId then x+=dw; y+=dh
            elseif b.Y<54 and b.X>=700 then x+=dw end
            o.Position=UDim2.fromOffset(x,y); o.Size=UDim2.fromOffset(w,h)
        end
        sizeLabel.Text=math.floor(app.Window.Scale*100+0.5)..'%'
    end
    function app.SetWindowSize(w,h,persist)
        assert(type(w)=='number' and type(h)=='number' and w==w and h==h,'Некорректный размер окна')
        app.Window.Width=math.clamp(w,1000,1800); app.Window.Height=math.clamp(h,680,1100)
        app.LayoutWindow(); fit(); if persist~=false then saveSettings() end
    end
    function app.SetInterfaceScale(value,persist)
        assert(type(value)=='number' and value==value,'Некорректный масштаб')
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
local modeNames={Position='Сдвиг',Rotation='Поворот',Scale='Размер'}
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
local uniformButton=button('Равномерный масштаб: ВКЛ',18,321,308,34,function()
    uniform=not uniform
    if app.UpdateTransformFields then app.UpdateTransformFields(app.EditingId) end
end,editor)
label('Шаг',18,369,60,32,editor,18)
local stepInput=editInput('0.05',91,367,100,34)
stepInput.Name='StepInput'
local editorNotice=label('Меняйте числа или тяните 3D-ручки на аксессуаре.',18,410,308,53,editor,17)
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
    uniformButton.Text=uniform and 'Равномерный масштаб: ВКЛ' or 'Равномерный масштаб: ВЫКЛ'
    modeHelp.Text=mode=='Position' and 'Положение X / Y / Z в studs' or (mode=='Rotation' and 'Поворот X / Y / Z в градусах' or 'Масштаб X / Y / Z (1 = исходный)')
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
    if app.Busy or app.Restoring then message('Подождите окончания примерки'); return end
    local it=app.Items[id]
    if not it or not it.Weld or it.Layered then message('Transform Item доступен для обычных аксессуаров',true); return end
    if app.EditingId then app.CloseTransform(false) end
    app.EditingId=id; initialTransform=normalizedTransform(it.Transform)
    editName.Text=it.Name; panel.Visible=false; editor.Visible=true
    editorNotice.Text='Меняйте числа или тяните 3D-ручки на аксессуаре.'; editorNotice.TextColor3=C.Muted
    highlight=make('Highlight',{Name='LocalCatalogSelection',Adornee=it.Object,FillTransparency=1,OutlineColor=Color3.fromRGB(105,184,255),DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},it.Object)
    app.UpdateTransformFields(id)
end
function app.ToggleWindow()
    clearModal()
    if app.EditingId then editor.Visible=not editor.Visible; updateGizmos() else panel.Visible=not panel.Visible end
end
button('Сбросить трансформацию',18,473,308,34,function() applyEdited(defaultTransform()) end,editor)
button('Отмена',18,520,147,40,function() app.CloseTransform(true) end,editor)
button('Готово',178,520,148,40,function() app.CloseTransform(false); message('Трансформация сохранена в текущем образе') end,editor,true)
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
    if not processed and i.KeyCode==Enum.KeyCode.RightShift then app.ToggleWindow() end
end)
connect(player.CharacterAdded,app.HandleCharacterAdded)
-- If appearance arrives after the bounded wait, rebuild once from the completed server appearance.
connect(player.CharacterAppearanceLoaded,function(ch)
    if ch==player.Character and app.KeepOnRespawn and not app.Restoring and (next(app.Desired) or app.HideOriginal) then
        app.HandleCharacterAdded(ch)
    end
end)
function app.Unload()
    if not app.Alive then return end
    app.Reset(); app.Alive=false; searchSerial+=1
    for _,c in ipairs(app.Connections) do c:Disconnect() end
    for _,v in pairs(app.Cache) do v.Template:Destroy() end
    app.Cache={}; if modalGui then modalGui:Destroy() end; gui:Destroy()
    if env.LocalCatalog==app then env.LocalCatalog=nil end
end
refresh(); search()
if carry and (#carry.AssetIds>0 or carry.HideOriginal) then
    run(function(rev)
        local failed=applyOutfit(carry,rev)
        return failed and #failed==0 and 'Ваш образ перенесён в обновлённый каталог' or 'Часть прежнего образа не удалось загрузить'
    end)
end
