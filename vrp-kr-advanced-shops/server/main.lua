local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRPAdvancedShop = {}
vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vrp_advanced_shop")
ASclient = Tunnel.getInterface("vrp_advanced_shop","vrp_advanced_shop")
Tunnel.bindInterface("vrp_advanced_shop",vRPAdvancedShop)

ESX = nil

-- ESX
--TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local number = {}


--[[GET INVENTORY ITEM

ESX.RegisterServerCallback('esx_kr_shop:getInventory', function(source, cb)
  local xPlayer = ESX.GetPlayerFromId(source)
  local items   = xPlayer.inventory

  cb({items = items})

end)]]

function vRPAdvancedShop.getInventory()
    local user_id = vRP.getUserId({source})
    if user_id then
        local data = vRP.getUserDataTable(user_id)
        if data then
            local itens = {items = data.inventory}
            return itens
        end
    end
end

--Removes item from shop
--RegisterServerEvent('esx_kr_shops:RemoveItemFromShop')
AddEventHandler('esx_kr_shops:RemoveItemFromShop', function(source, number, count, item)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT count, item FROM shops WHERE item = @item AND ShopNumber = @ShopNumber',
        {
            ['@ShopNumber'] = number,
            ['@item'] = item,
        },
        function(data)
            if count > data[1].count then
                vRPclient.notify(_source, {'~r~You can\' t take out more than you own'})
            else
                if data[1].count ~= count then
                    MySQL.Async.fetchAll("UPDATE shops SET count = @count WHERE item = @item AND ShopNumber = @ShopNumber",
                    {
                        ['@item'] = item,
                        ['@ShopNumber'] = number,
                        ['@count'] = data[1].count - count
                    }, function(result)
                        vRP.giveInventoryItem({user_id,data[1].item,count,true})
                    end)
                elseif data[1].count == count then
                    MySQL.Async.fetchAll("DELETE FROM shops WHERE item = @name AND ShopNumber = @Number",
                    {
                        ['@Number'] = number,
                        ['@name'] = data[1].item
                    })
                    vRP.giveInventoryItem({user_id,data[1].item,count,true})
                end
            end
        end)
    end
end)


--Setting selling items.
--RegisterServerEvent('esx_kr_shops:setToSell')
--TriggerEvent('esx_kr_shops:setToSell', player, data[1].ShopNumber, idname, amount, price)
AddEventHandler('esx_kr_shops:setToSell', function(source, id, Item, ItemCount, Price)
    local _source = source
    local user_id = vRP.getUserId({source})
    if user_id then
      MySQL.Async.fetchAll(
        'SELECT price, count FROM shops WHERE item = @items AND ShopNumber = @ShopNumber',
        {
            ['@items'] = Item,
            ['@ShopNumber'] = id,
        },
        function(data)
            if data[1] == nil then
                imgsrc = 'img/box.png'

                for i=1, #Config.Images, 1 do
                    if Config.Images[i].item == Item then
                        imgsrc = Config.Images[i].src
                    end
                end
                local ItemName = vRP.getItemName({Item}) or "NoName"
                MySQL.Async.execute('INSERT INTO shops (ShopNumber, src, label, count, item, price) VALUES (@ShopNumber, @src, @label, @count, @item, @price)',
                {
                    ['@ShopNumber']    = id,
                    ['@src']           = imgsrc,
                    ['@label']         = ItemName,
                    ['@count']         = ItemCount,
                    ['@item']          = Item,
                    ['@price']         = Price
                })

                vRP.tryGetInventoryItem({user_id,Item,ItemCount,true})
                --xPlayer.removeInventoryItem(Item, ItemCount)

            elseif data[1].price == Price then
            
                MySQL.Async.fetchAll("UPDATE shops SET count = @count WHERE item = @name AND ShopNumber = @ShopNumber",
                {
                    ['@name'] = Item,
                    ['@ShopNumber'] = id,
                    ['@count'] = data[1].count + ItemCount
                })
                vRP.tryGetInventoryItem({user_id,Item,ItemCount,true})
                --xPlayer.removeInventoryItem(Item, ItemCount)


            elseif data ~= nil and data[1].price ~= Price then
                Wait(250)
                vRPclient.notify(_source, {'~r~You already have a same item in your shop, ~r~but for ' .. data[1].price .. '. you put the price ' .. Price})
                Wait(250)
                vRPclient.notify(_source, {'~r~Remove the item and put a new price or put the same price'})
            end
        end)  
    end
end)

-- BUYING PRODUCT
RegisterServerEvent('esx_kr_shops:Buy')
AddEventHandler('esx_kr_shops:Buy', function(id, Item, ItemCount)
    print("esx_kr_shops:Buy Item " .. Item .. " - ItemCount " .. ItemCount)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        local ItemCount = tonumber(ItemCount)

        MySQL.Async.fetchAll(
        'SELECT * FROM shops WHERE ShopNumber = @Number AND item = @item',
        {
            ['@Number'] = id,
            ['@item'] = Item,
        }, function(result)

            MySQL.Async.fetchAll(
            'SELECT * FROM owned_shops WHERE ShopNumber = @Number',
            {
                ['@Number'] = id,
            }, function(result2)

                if ItemCount <= 0 then
                    vRPclient.notify(_source, {'~r~Invalid quantity.'})
                elseif vRP.tryPayment({user_id, (ItemCount * result[1].price)}) then
                    vRP.tryPayment({user_id, (ItemCount * result[1].price)})
                    local ItemName = vRP.getItemName({Item}) or "NoName"
                    vRPclient.notify(_source, {'~g~You bought ' .. ItemCount .. 'x ' .. ItemName .. ' for $' .. ItemCount * result[1].price})
                    vRP.giveInventoryItem({user_id,result[1].item,ItemCount,true})

                    MySQL.Async.execute("UPDATE owned_shops SET money = @money WHERE ShopNumber = @Number",
                    {
                        ['@money']      = result2[1].money + (result[1].price * ItemCount),
                        ['@Number']     = id,
                    })

                    if result[1].count ~= ItemCount then
                        MySQL.Async.execute("UPDATE shops SET count = @count WHERE item = @name AND ShopNumber = @Number",
                        {
                            ['@name'] = Item,
                            ['@Number'] = id,
                            ['@count'] = result[1].count - ItemCount
                        })
                    elseif result[1].count == ItemCount then
                        MySQL.Async.fetchAll("DELETE FROM shops WHERE item = @name AND ShopNumber = @Number",
                        {
                            ['@Number'] = id,
                            ['@name'] = result[1].item
                        })
                    end
                else
                    vRPclient.notify(_source, {'~r~You don\'t have enough money.'})
                end
            end)
        end)
    end
end)

--CALLBACKS
function vRPAdvancedShop.getShopList()
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE user_id = @user_id',
        {
            ['@user_id'] = '0',
        }, function(result)
            return result
        end)
    end
end

function vRPAdvancedShop.getShopListMenu()
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE user_id = @user_id',
        {
            ['@user_id'] = '0',
        }, function(result)
            if result then
                local player = vRP.getUserSource({user_id})
                local data = result
                local menudata = {name="Shop List",css={top="75px",header_color="rgba(0,125,255,0.75)"}}
                local kitems = {}

                local choose = function(player,choice)
                    local data = kitems[choice]
                    vRP.closeMenu({player})
                    vRP.prompt({player,"What whould you like to name your shop to?","",function(player,nome)
                        if nome then
                            TriggerEvent('esx_kr_shops:BuyShop', player, nome, data.ShopValue, data.ShopNumber, false)    
                        end
                        vRP.closeMenu({player})
                    end})
                end
                local show_choose = function(player,choice)
                    ASclient.menuShowBlip(player,{})
                end
                local hide_choose = function(player,choice)
                    ASclient.menuHideBlip(player,{})
                end
                menudata["Show ALL shops on the map"] = {show_choose,""}
                menudata["Hide ALL shops on the map"] = {hide_choose,""}

                --table.insert(elements, {label = "Buy shop " .. data[i].ShopNumber .. ' [$' .. data[i].ShopValue .. ']', value = 'kop', price = data[i].ShopValue, shop = data[i].ShopNumber})
                for i=1, #data, 1 do
                    local text = "Buy shop " .. data[i].ShopNumber .. ' [$' .. data[i].ShopValue .. ']'
                    kitems[text] = data[i] -- reference item by display name
                    menudata[text] = {choose,"Buy shop " .. data[i].ShopNumber .. ' [$' .. data[i].ShopValue .. ']'}
                end

                -- open menu
                vRP.openMenu({player,menudata})
            end
        end)
    end
end

local business_name = {"\"[]{}+=?!_#",false}

function vRPAdvancedShop.openBossMenu(id)
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber AND user_id = @user_id',
        {
            ['@ShopNumber'] = id,
            ['@user_id'] = user_id,
        }, function(result)
            if result[1] ~= nil then

                --[[
        table.insert(elements, {label = 'You have: $' .. data[1].money .. ' in your company',    value = ''})
        table.insert(elements, {label = 'Shipments',    value = 'shipments'})
        table.insert(elements, {label = 'Put in a item for sale', value = 'putitem'})
        table.insert(elements, {label = 'Take out a item for sale',    value = 'takeitem'})
        table.insert(elements, {label = 'Put in money in your company',    value = 'putmoney'})
        table.insert(elements, {label = 'Take out money from your company',    value = 'takemoney'})
        table.insert(elements, {label = 'Change name on your company: $' .. Config.ChangeNamePrice,    value = 'changename'})
        table.insert(elements, {label = 'Sell your company for $' .. math.floor(data[1].ShopValue / Config.SellValue),   value = 'sell'})
                ]]
                local player = vRP.getUserSource({user_id})
                local data = result
                local menudata = {name="Shop Boss Actions",css={top="75px",header_color="rgba(0,125,255,0.75)"}}
                local kitems = {}
                local shopNumber = data[1].ShopNumber

                local choose_none = function(player,choice) end
                local choose_shipments = function(player,choice) end
                local choose_putitem = function(player,choice)
                    local data = vRP.getUserDataTable({user_id})
                    if data.inventory ~= nil then
                        local menudata_pt = {name="Put Item",css={top="75px",header_color="rgba(0,125,255,0.75)"}}
                        local kitems_pt = {}
                        -- add each item to the menu

                        local choose_sub_putitem = function(player,choice)
                            vRP.closeMenu({player})
                            local idname = kitems_pt[choice]
                            local citem = data.inventory[idname]
                            vRP.prompt({player,"How much whould you like to sell?","",function(player,amount)
                                amount = parseInt(amount)
                                if amount > 0 and amount <= citem.amount then
                                    vRP.prompt({player,"Set price on what you want to sell.","",function(player,price)
                                        price = parseInt(price)
                                        if price > 0 then
                                            TriggerEvent('esx_kr_shops:setToSell', player, shopNumber, idname, amount, price)
                                        end
                                        vRP.closeMenu({player})
                                    end})
                                end
                                vRP.closeMenu({player})
                            end})

                        end

                        for k,v in pairs(data.inventory) do
                            local name,description,weight,itemlistname = vRP.getItemDefinition({k})
                            if name ~= nil then
                                kitems_pt[itemlistname] = k -- reference item by display name
                                menudata_pt[itemlistname] = {choose_sub_putitem,"x" .. v.amount .. " - " .. name}
                            end
                        end

                        vRP.openMenu({player,menudata_pt})
                    end

                    --TriggerServerEvent('esx_kr_shops:setToSell', number, itemName, count, price)
                end
                local choose_takeitem = function(player,choice)
                    MySQL.Async.fetchAll('SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
                    {
                        ['@ShopNumber'] = shopNumber
                    }, function(result)
                        if result ~= nil then
                            local menudata_ti = {name="Take Item",css={top="75px",header_color="rgba(0,125,255,0.75)"}}
                            local kitems_ti = {}
                            local kitems_count_ti = {}

                            local choose_sub_takeitem = function(player,choice)
                                vRP.closeMenu({player})
                                local idname = kitems_ti[choice]
                                local count = kitems_count_ti[choice]
                                vRP.prompt({player,"How much whould you like to take out?","",function(player,amount)
                                    amount = parseInt(amount)
                                    if amount > 0 and amount <= count then
                                        TriggerEvent('esx_kr_shops:RemoveItemFromShop', player, shopNumber, amount, idname)
                                    end
                                end})
                                
                            end

                            for i=1, #result, 1 do
                                if result[i].count > 0 then
                                    local name,description,weight,itemlistname = vRP.getItemDefinition({result[i].item})
                                    --table.insert(elements, {label = result[i].label .. ' | ' .. result[i].count ..' pieces in storage [' .. result[i].price .. ' $ per piece', value = 'removeitem', ItemName = result[i].item})
                                    if name ~= nil then
                                        kitems_ti[result[i].label] = result[i].item -- reference item by display name
                                        kitems_count_ti[result[i].label] = result[i].count
                                        menudata_ti[result[i].label] = {choose_sub_takeitem,"x" .. result[i].count .. " - " .. name .. " - " .. result[i].price}
                                    end
                                end
                            end

                            vRP.openMenu({player,menudata_ti})
                        end
                    end)
                    --TriggerServerEvent('esx_kr_shops:RemoveItemFromShop', number, count, name)
                end
                local choose_takemoney = function(player,choice)
                    vRP.closeMenu({player})
                    vRP.prompt({player,"How much whould you like to take out?","",function(player,amount)
                        if amount then
                            amount = tonumber(amount)
                            TriggerEvent('esx_kr_shops:takeOutMoney', player, amount, data[1].ShopNumber)
                        end
                        vRP.closeMenu({player})
                    end})
                end
                local choose_putmoney = function(player,choice)
                    vRP.closeMenu({player})
                    vRP.prompt({player,"How much whould you like to put in?","",function(player,amount)
                        if amount then
                            amount = tonumber(amount)
                            TriggerEvent('esx_kr_shops:addMoney', player, amount, data[1].ShopNumber)
                        end
                        vRP.closeMenu({player})
                    end})
                end
                local choose_changename = function(player,choice)
                    vRP.closeMenu({player})
                    vRP.prompt({player,"What whould you like to name your shop?","",function(player,name)
                        if string.len(name) >= 2 and string.len(name) <= 30 then
                            name = sanitizeString(name, business_name[1], business_name[2])
                            TriggerEvent('esx_kr_shops:changeName', player, data[1].ShopNumber, name)
                        end
                        vRP.closeMenu({player})
                    end})
                end
                local choose_sellcompany = function(player,choice)
                    vRP.closeMenu({player})
                    vRP.request({player,"Confirm Sell SHOP?",15,function(player,ok)
                        if ok then
                            TriggerEvent('esx_kr_shops:SellShop', player, data[1].ShopNumber)
                        end
                        vRP.closeMenu({player})
                    end})
                    
                end

                menudata['1. You have: $' .. data[1].money .. ' in your company'] = {choose_none,""}
                menudata['2. Change name on your company: $' .. Config.ChangeNamePrice] = {choose_changename,""}
                menudata['3. Shipments'] = {choose_none,""}
                menudata['4. Sell your company for $' .. math.floor(data[1].ShopValue / Config.SellValue)] = {choose_sellcompany,""}

                menudata['5. Put in a item for sale'] = {choose_putitem,""}
                menudata['6. Take out a item for sale'] = {choose_takeitem,""}
                menudata['7. Put in money in your company'] = {choose_putmoney,""}
                menudata['8. Take out money from your company'] = {choose_takemoney,""}
                
                -- open menu
                vRP.openMenu({player,menudata})
            end
        end)
    end
end

--[[ESX.RegisterServerCallback('esx_kr_shop:getShopList', function(source, cb)
  local identifier = ESX.GetPlayerFromId(source).identifier
  local xPlayer = ESX.GetPlayerFromId(source)

        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE identifier = @identifier',
        {
            ['@identifier'] = '0',
        }, function(result)

      cb(result)
    end)
end)]]

function vRPAdvancedShop.getOwnedBlips()
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE NOT user_id = @user_id',
        {
            ['@user_id'] = '0',
        }, function(result)
            local player = vRP.getUserSource({user_id})
            ASclient.returnGetOwnedBlips(player, {result})
        end)
    end
end
--[[ESX.RegisterServerCallback('esx_kr_shop:getOwnedBlips', function(source, cb)

        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE NOT identifier = @identifier',
        {
            ['@identifier'] = '0',
        }, function(results)
        cb(results)
    end)
end)]]

function vRPAdvancedShop.getAllShipments(id)
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM shipments WHERE id = @id AND identifier = @identifier',
        {
            ['@id'] = id,
            ['@user_id'] = user_id,
        }, function(result)
            return result
        end)
    end
end
--[[ESX.RegisterServerCallback('esx_kr_shop:getAllShipments', function(source, cb, id)
  local identifier = ESX.GetPlayerFromId(source).identifier

        MySQL.Async.fetchAll(
        'SELECT * FROM shipments WHERE id = @id AND identifier = @identifier',
        {
            ['@id'] = id,
            ['@identifier'] = identifier,
        }, function(result)
        cb(result)
    end)
end)]]

function vRPAdvancedShop.getTime(id)
    return os.time()
end

--[[ESX.RegisterServerCallback('esx_kr_shop:getTime', function(source, cb)
    cb(os.time())
end)]]

function vRPAdvancedShop.getOwnedShop(id)
    local user_id = vRP.getUserId({source})
    if user_id then
        print("getOwnedShop #" .. user_id)
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber AND user_id = @user_id',
        {
            ['@ShopNumber'] = id,
            ['@user_id'] = user_id,
        }, function(result)
            if result[1] ~= nil then
                return result
            else
                return nil
            end
        end)
    end
end

function vRPAdvancedShop.getOwnedShopAndItems(id)
    local source = source
    local user_id = vRP.getUserId({source})
    local shop = nil
    local id = id
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber AND user_id = @user_id',
        {
            ['@ShopNumber'] = id,
            ['@user_id'] = user_id,
        }, function(result)
            if result[1] ~= nil then
                shop = result
            end
            MySQL.Async.fetchAll('SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
            {
                ['@ShopNumber'] = id
            }, function(result2)
                local items = result2
                local player = vRP.getUserSource({user_id})
                ASclient.returnGetOwnedShopAndItems(player, {shop, items})
            end)
        end)
    end
end

--[[ESX.RegisterServerCallback('esx_kr_shop:getOwnedShop', function(source, cb, id)
local src = source
local identifier = ESX.GetPlayerFromId(src).identifier

        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber AND identifier = @identifier',
        {
            ['@ShopNumber'] = id,
            ['@identifier'] = identifier,
        }, function(result)

        if result[1] ~= nil then
            cb(result)
        else
            cb(nil)
        end
    end)
end)]]

function vRPAdvancedShop.getShopItems(number)
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll('SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
        {
            ['@ShopNumber'] = number
        }, function(result)
            return result
        end)
    end
end

--[[ESX.RegisterServerCallback('esx_kr_shop:getShopItems', function(source, cb, number)
  local identifier = ESX.GetPlayerFromId(source).identifier
  
        MySQL.Async.fetchAll('SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
        {
            ['@ShopNumber'] = number
        }, function(result)
        cb(result)
    end)
end)]]

RegisterServerEvent('esx_kr_shops:GetAllItems')
AddEventHandler('esx_kr_shops:GetAllItems', function(id)
    local _source = source
    local identifier = ESX.GetPlayerFromId(_source).identifier
    local xPlayer = ESX.GetPlayerFromId(_source)

    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE id = @id AND identifier = @identifier',
    {
        ['@id'] = id,
        ['@identifier'] = identifier
    }, function(result)

        for i=1, #result, 1 do
            xPlayer.addInventoryItem(result[i].item, result[i].count)
            MySQL.Async.fetchAll('DELETE FROM shipments WHERE id = @id AND identifier = @identifier',{['@id'] = id,['@identifier'] = identifier,})
        end
    end)
end)


RegisterServerEvent('esx_kr_shops-robbery:UpdateCanRob')
AddEventHandler('esx_kr_shops-robbery:UpdateCanRob', function(id)
    MySQL.Async.fetchAll("UPDATE owned_shops SET LastRobbery = @LastRobbery WHERE ShopNumber = @ShopNumber",{['@ShopNumber'] = id,['@LastRobbery']    = os.time(),})
end)

RegisterServerEvent('esx_kr_shop:MakeShipment')
AddEventHandler('esx_kr_shop:MakeShipment', function(id, item, price, count, label)
  local _source = source
  local identifier = ESX.GetPlayerFromId(_source).identifier

    MySQL.Async.fetchAll('SELECT money FROM owned_shops WHERE ShopNumber = @ShopNumber AND identifier = @identifier',{['@ShopNumber'] = id,['@identifier'] = identifier,}, function(result)

        if result[1].money >= price * count then

            MySQL.Async.execute('INSERT INTO shipments (id, label, identifier, item, price, count, time) VALUES (@id, @label, @identifier, @item, @price, @count, @time)',{['@id']       = id,['@label']      = label,['@identifier'] = identifier,['@item']       = item,['@price']      = price,['@count']      = count,['@time']       = os.time()})
            MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @ShopNumber",{['@ShopNumber'] = id,['@money']    = result[1].money - price * count,})  
            TriggerClientEvent('esx:showNotification', _source, '~g~You ordered' .. count .. ' pieces ' .. label .. ' for $' .. price * count)
        else
            TriggerClientEvent('esx:showNotification', _source, '~r~You don\'t have enough money in your shop.')
        end
    end)
end)

--RegisterServerEvent('esx_kr_shops:BuyShop')
AddEventHandler('esx_kr_shops:BuyShop', function(source, name, price, number, hasbought)
    print("esx_kr_shops:BuyShop")
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT user_id FROM owned_shops WHERE ShopNumber = @ShopNumber',
        {
          ['@ShopNumber'] = number,
        }, function(result)
            if result[1].user_id == '0' then
                if vRP.tryPayment({user_id,price}) then
                    MySQL.Async.fetchAll("UPDATE owned_shops SET user_id = @user_id, ShopName = @ShopName WHERE ShopNumber = @ShopNumber",{['@user_id']  = user_id,['@ShopNumber'] = number,['@ShopName'] = name},function(result) end)
                    TriggerClientEvent('esx_kr_shops:removeBlip', -1)
                    TriggerClientEvent('esx_kr_shops:setBlip', -1)
                    vRPclient.notify(_source, {'~g~You bought a shop for $' ..  price})
                else    
                    vRPclient.notify(_source, {'~r~You can\'t afford this shop'})
                end
            else
                vRPclient.notify(_source, {'~r~You can\'t afford this shop'})
            end
        end)
    end
end)


--BOSS MENU STUFF
--RegisterServerEvent('esx_kr_shops:addMoney')
AddEventHandler('esx_kr_shops:addMoney', function(source, amount, number)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        MySQL.Async.fetchAll(
            'SELECT * FROM owned_shops WHERE user_id = @user_id AND ShopNumber = @Number',
            {
              ['@user_id'] = user_id,
              ['@Number'] = number,
            },
            function(result)
                if os.time() - result[1].LastRobbery <= 900 then
                    time = os.time() - result[1].LastRobbery
                    vRPclient.notify(_source, {'~r~Your shop money has been locked due to robbery, please wait ' .. math.floor((900 - time) / 60) .. ' minutes'})
                    return
                end

                if vRP.tryPayment({user_id, amount}) then
                    MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE user_id = @user_id AND ShopNumber = @Number",
                    {
                        ['@money']      = result[1].money + amount,
                        ['@Number']     = number,
                        ['@user_id'] = user_id
                    })
                    vRPclient.notify(_source, {'~g~You put in $' .. amount .. ' in your shop'})
                else
                    vRPclient.notify(_source, {'~r~You can\'t put in more than you own'})
                end
        end)
    end
end)

--RegisterServerEvent('esx_kr_shops:takeOutMoney')
AddEventHandler('esx_kr_shops:takeOutMoney', function(source, amount, number)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then

        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE user_id = @user_id AND ShopNumber = @Number',
        {
          ['@user_id'] = user_id,
          ['@Number'] = number,
        },

        function(result)

            if os.time() - result[1].LastRobbery <= 900 then
                time = os.time() - result[1].LastRobbery
                --TriggerClientEvent('esx:showNotification', xPlayer.source, '~r~Your shop money has been locked due to robbery, please wait ' .. math.floor((900 - time) / 60) .. ' minutes')
                vRPclient.notify(_source, {'~r~Your shop money has been locked due to robbery, please wait ' .. math.floor((900 - time) / 60) .. ' minutes'})
                return
            end
              
                if result[1].money >= amount then
                    MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE user_id = @user_id AND ShopNumber = @Number",
                    {
                        ['@money'] = result[1].money - amount,
                        ['@Number'] = number,
                        ['@user_id'] = user_id
                    })
                    --TriggerClientEvent('esx:showNotification', xPlayer.source, '~g~You took out $' .. amount .. ' from your shop')
                    vRPclient.notify(_source, {'~g~You took out $' .. amount .. ' from your shop'})
                    vRP.giveMoney({user_id,amount})
                else
                    vRPclient.notify(_source, {'~r~You can\'t put in more than you own'})
                    --TriggerClientEvent('esx:showNotification', xPlayer.source, '~r~You can\'t put in more than you own')
                end
                
        end)
    end
end)


--RegisterServerEvent('esx_kr_shops:changeName')
AddEventHandler('esx_kr_shops:changeName', function(source, number, name)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        if vRP.tryPayment({user_id, 500}) then
            MySQL.Async.fetchAll("UPDATE owned_shops SET ShopName = @Name WHERE user_id = @user_id AND ShopNumber = @Number",
            {
                ['@Number'] = number,
                ['@Name']     = name,
                ['@user_id'] = user_id
            })
            TriggerClientEvent('esx_kr_shops:removeBlip', -1)
            TriggerClientEvent('esx_kr_shops:setBlip', -1)
            vRPclient.notify(_source, {'~g~Name changed.'})
        else
            vRPclient.notify(_source, {'~r~You do not have enough money.'})
        end
    end
end)

--RegisterServerEvent('esx_kr_shops:SellShop')
AddEventHandler('esx_kr_shops:SellShop', function(source, number)
    local _source = source
    local user_id = vRP.getUserId({_source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE user_id = @user_id AND ShopNumber = @ShopNumber',
        {
          ['@user_id'] = user_id,
          ['@ShopNumber'] = number,
        },
        function(result)
            MySQL.Async.fetchAll(
            'SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
            {
              ['@ShopNumber'] = number,
            },
            function(result2)
                if result[1].money == 0 and result2[1] == nil then
                    MySQL.Async.fetchAll("UPDATE owned_shops SET user_id = @identifiers, ShopName = @ShopName WHERE user_id = @user_id AND ShopNumber = @Number",
                    {
                        ['@identifiers'] = '0',
                        ['@user_id'] = user_id,
                        ['@ShopName']    = '0',
                        ['@Number'] = number,
                    })
                    vRP.giveMoney({user_id, result[1].ShopValue / 2})
                    TriggerClientEvent('esx_kr_shops:removeBlip', -1)
                    TriggerClientEvent('esx_kr_shops:setBlip', -1)
                    vRPclient.notify(_source, {'~g~You sold your shop'})
                else
                    vRPclient.notify(_source, {'~r~You can\'t sell your shop with items or money inside of it'})
                end
            end)
        end)
    end
end)


function vRPAdvancedShop.getUnBoughtShops()
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE user_id = @user_id',
        {
            ['@user_id'] = '0',
        }, function(result)
            return result
        end)
    end
end

--[[ESX.RegisterServerCallback('esx_kr_shop:getUnBoughtShops', function(source, cb)
  local identifier = ESX.GetPlayerFromId(source).identifier
  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE identifier = @identifier',
    {
      ['@identifier'] = '0',
    },
    function(result)

        cb(result)
    end)
end)]]

function vRPAdvancedShop.getOnlinePolices()
    local user_id = vRP.getUserId({source})
    if user_id then
        local cops = vRP.getUsersByPermission({"police.base"})
        return #cops or 0
    end
end

--[[ESX.RegisterServerCallback('esx_kr_shop-robbery:getOnlinePolices', function(source, cb)
  local _source  = source
  local xPlayers = ESX.GetPlayers()
  local cops = 0

    for i=1, #xPlayers, 1 do

        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == 'police' then
        cops = cops + 1
        end
    end
    Wait(25)
    cb(cops)
end)]]

function vRPAdvancedShop.getUpdates(id)
    local user_id = vRP.getUserId({source})
    local id = id
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
        {
            ['@ShopNumber'] = id,
        },
        function(result)
            local player = vRP.getUserSource({user_id})
            local cops = vRP.getUsersByPermission({"police.base"})

            if result[1].LastRobbery == 0 then
                id = id
                MySQL.Async.fetchAll("UPDATE owned_shops SET LastRobbery = @LastRobbery WHERE ShopNumber = @ShopNumber",
                {
                    ['@ShopNumber'] = id,
                    ['@LastRobbery'] = os.time(),
                })
                print("Rob = 0")
            else
                if os.time() - result[1].LastRobbery >= Config.TimeBetweenRobberies then
                    print("CB = true")
                    ASclient.returnGetUpdates(player, {id, {cb = true, time = os.time() - result[1].LastRobbery, name = result[1].ShopName, cops = cops}})
                else
                    print("CB = false")
                    ASclient.returnGetUpdates(player, {id, {cb = nil, time = os.time() - result[1].LastRobbery, cops = cops}})
                end
            end
        end)
    end
end


--[[ESX.RegisterServerCallback('esx_kr_shop-robbery:getUpdates', function(source, cb, id)

    MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
    {
     ['@ShopNumber'] = id,
    },
     function(result)

        if result[1].LastRobbery == 0 then
            id = id
            MySQL.Async.fetchAll("UPDATE owned_shops SET LastRobbery = @LastRobbery WHERE ShopNumber = @ShopNumber",
            {
            ['@ShopNumber'] = id,
            ['@LastRobbery']   = os.time(),
            })
        else
            if os.time() - result[1].LastRobbery >= Config.TimeBetweenRobberies then
                cb({cb = true, time = os.time() - result[1].LastRobbery, name = result[1].ShopName})
            else
                cb({cb = nil, time = os.time() - result[1].LastRobbery})
            end
        end
    end)
end)]]


RegisterServerEvent('esx_kr_shops-robbery:GetReward')
AddEventHandler('esx_kr_shops-robbery:GetReward', function(id)
    local source = source
    local user_id = vRP.getUserId({source})
    local id = id
    if user_id then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
        {
            ['@ShopNumber'] = id,
        }, function(result)
            id = id
            
            MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @ShopNumber",
            {
                ['@ShopNumber'] = id,
                ['@money']     = result[1].money - result[1].money / Config.CutOnRobbery,
            })
            id = id
            local money = (result[1].money / Config.CutOnRobbery)
            vRP.giveMoney({user_id, money})
            vRPclient.notify(source, {'~g~You received ' .. money})
        end)
    end
end)

RegisterServerEvent('esx_kr_shops-robbery:NotifyOwner')
AddEventHandler('esx_kr_shops-robbery:NotifyOwner', function(msg, id)
    local user_id = vRP.getUserId({source})
    if user_id then
        local users = vRP.getUsers()
        for k,v in pairs(users) do
            local user_source = vRP.getUserSource({k})
            if user_source ~= nil then
                local nuser_id = vRP.getUserId({user_source})
                MySQL.Async.fetchAll(
                'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
                {
                    ['@ShopNumber'] = id,
                }, function(result)

                    if result[1].user_id == nuser_id then
                        vRPclient.notify(user_source, {msg})
                        --TriggerClientEvent('esx:showNotification', identifier.source, msg)
                    end
                end)
            end
        end
    end
    --[[for i=1, #vRP.getUsers({}), 1 do
            local identifier = ESX.GetPlayerFromId(ESX.GetPlayers()[i])
  
            MySQL.Async.fetchAll(
            'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
            {
                ['@ShopNumber'] = id,
            }, function(result)

            if result[1].user_id == identifier.identifier then
                TriggerClientEvent('esx:showNotification', identifier.source, msg)
            end

        end)
    end]]
end)
