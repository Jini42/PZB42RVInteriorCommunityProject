-------------------------------------------------------------------
--						DEBUG MENU
-------------------------------------------------------------------
local RVInteriorClientAdminMenu = {}
-------------------------------------------------------------------


-------------------------------------------------------------------
RVInteriorClientAdminMenu.xywh = function(w, h)
	local screenWidth = Core.getInstance():getScreenWidth()
	local screenHeight = Core.getInstance():getScreenHeight()
	return (screenWidth - w) / 2, (screenHeight - h) / 2, w, h;
end
----------------------------------------------------------------------

RVInteriorClientAdminMenu.onFillWorldObjectContextMenu = function(playerId, context, worldObjects)
	local player = getSpecificPlayer(playerId)
	if isAdmin() or isDebugEnabled() then
		local KeyMenu = context:addOption(getText('UI_rvdebug_menu'), worldObjects);
		local subMenu = ISContextMenu:getNew(context);
		RVInteriorClientAdminMenu.context = context
		RVInteriorClientAdminMenu.subMenu = subMenu
		context:addSubMenu(KeyMenu, subMenu);
		local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
		if not vehicle then
			subMenu:addOption(getText('UI_rvdebug_sit'), worldObjects)
		elseif not RVInterior.hasInteriorParameters(vehicle:getScript():getFullName()) then
			subMenu:addOption(getText('UI_rvdebug_no_interior') .. vehicle:getScript():getFullName(), worldObjects)
		else
			subMenu:addOption(getText('UI_rvdebug_num'), worldObjects, RVInteriorClientAdminMenu.getAssignedNumber, player)
			subMenu:addOption(getText('UI_rvdebug_teleport_vehicle'), worldObjects, RVInteriorClientAdminMenu.promptTeleport, player)
			subMenu:addOption(getText('UI_rvdebug_manual_assign'), worldObjects, RVInteriorClientAdminMenu.promptAssignedNumber, player)
			subMenu:addOption(getText('UI_rvdebug_reset'), worldObjects, RVInteriorClientAdminMenu.resetVehicle, player)
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(RVInteriorClientAdminMenu.onFillWorldObjectContextMenu)
-------------------------------------------------------------------
-------------------------------------------------------------------
RVInteriorClientAdminMenu.resetVehicle = function(_worldObjects, player)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	if vehicle then
		local confirmClosure = function (_this, button)
			if button.internal == "YES" then
				sendClientCommand("RVInteriorAdmin", "clientResetVehicle",
						{ vehicleId = vehicle:getId(), playerId = player:getOnlineID() })
			end
		end
		local x, y, w, h = RVInteriorClientAdminMenu.xywh(250, 150);
		local confirmDialog = ISModalDialog:new(x, y, w, h,
				getText("UI_rvdebug_reset_confirm"), true, nil, confirmClosure)
		confirmDialog:initialise()
		confirmDialog:addToUIManager()
		if JoypadState.players[player:getPlayerNum()+1] then
			setJoypadFocus(player:getPlayerNum(), confirmDialog)
		end
	end
end
-------------------------------------------------------------------
RVInteriorClientAdminMenu.getAssignedNumber = function(_worldObjects, player)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	if vehicle then
		sendClientCommand("RVInteriorAdmin", "clientGetAssignedNumber",
				{ vehicleId = vehicle:getId(), playerId = player:getOnlineID() })
	end
end
-------------------------------------------------------------------
RVInteriorClientAdminMenu.promptTeleport = function(_worldObjects, player)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	if vehicle then
		sendClientCommand("RVInteriorAdmin", "clientPromptTeleport",
				{ vehicleId = vehicle:getId(), playerId = player:getOnlineID() })
	end
end
-------------------------------------------------------------------
RVInteriorClientAdminMenu.promptAssignedNumber = function(_worldObjects, player)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
	if vehicle then
		sendClientCommand("RVInteriorAdmin", "clientPromptAssignedNumber",
				{ vehicleId = vehicle:getId(), playerId = player:getOnlineID() })
	end
end
-------------------------------------------------------------------

function comboBoxDialog(player, text, options, current, onApply)
	local x, y, w, h = RVInteriorClientAdminMenu.xywh(400, 100);
	local selectDialog = ISPanel:new(x, y, w, h);
	selectDialog.character = player;
	selectDialog:addChild(ISLabel:new(10, 10, 10, text, 1, 1, 1, 1, UIFont.Small, true));
	-- Add combobox to select
	local comboBox = ISComboBox:new((w - 50) / 2, 25, 50, 25, selectDialog);
	for index = 1, #options do
		comboBox:addOption(tostring(options[index]));
		if current == options[index] then
			comboBox.selected = index;
		end
	end
	selectDialog:addChild(comboBox);
	-- Add apply and cancel buttons
	selectDialog:addChild(ISButton:new(10, 80, 100, 15, getText('UI_btn_apply'), selectDialog, function()
		onApply(comboBox:getSelectedText());
		ISModalDialog.destroy(selectDialog);
	end));
	selectDialog:addChild(ISButton:new(w - 110, 80, 100, 15, getText('UI_btn_cancel'), selectDialog, function()
		ISModalDialog.destroy(selectDialog);
	end));
	----
	selectDialog:initialise();
	selectDialog:addToUIManager()
	if JoypadState.players[player:getPlayerNum()+1] then
		setJoypadFocus(player:getPlayerNum(), selectDialog)
	end
end


-------------------------------------------------------------------
--                         SERVER COMMANDS
-------------------------------------------------------------------

local adminServerCommandHandlers = {}

local function adminMenuOnServerCommand(module, command, arguments)
	if module ~= "RVInteriorAdmin" then
		return
	end
	if adminServerCommandHandlers[command] then
		local player = getSpecificPlayer(arguments.playerId % 4)
		adminServerCommandHandlers[command](player, arguments)
	end
end

Events.OnServerCommand.Add(adminMenuOnServerCommand)

-------------------------------------------------------------------

adminServerCommandHandlers.serverGetAssignedNumber = function(player, arguments)
	if arguments[1] == -1 then
		player:Say(getText("UI_rvdebug_none"))
	else
		player:Say(getText('UI_rvdebug_assigned_start') .. tostring(arguments[1]))
	end
end

-------------------------------------------------------------------

adminServerCommandHandlers.serverPromptTeleport = function(player, arguments)
	local current = arguments.interiorInstance;
	local options = arguments.options;
	local vehicleId = arguments.vehicleId;
	if #options > 0 then
		comboBoxDialog(player, getText('UI_rvdebug_teleport_dialog'), options, current,
				function(option)
					local interiorInstance = tonumber(option)
					sendClientCommand("RVInteriorAdmin", "clientAdminTeleport",
							{ vehicleId = vehicleId, playerId = player:getOnlineID(), interiorInstance = interiorInstance });
				end);
	end
end

-------------------------------------------------------------------

adminServerCommandHandlers.serverPromptAssignedNumber = function(player, arguments)
	local current = tostring(arguments.interiorInstance) .. '*';
	local used = arguments.used;
	local vehicleId = arguments.vehicleId;
	local options = {}
	local usedIndex = 1
	for index = 1, RVInterior.interiorSquare * RVInterior.interiorSquare do
		if usedIndex <= #used and used[usedIndex] == index then
			table.insert(options, tostring(index) .. '*')
			usedIndex = usedIndex + 1
		else
			table.insert(options, tostring(index))
		end
	end
	comboBoxDialog(player, getText('UI_rvdebug_manual_assign_dialog'), options, current,
			function(option)
				local justDigits = option:gsub('%D', '')
				local interiorInstance = tonumber(justDigits)
				sendClientCommand("RVInteriorAdmin", "clientSetAssignedNumber",
						{ vehicleId = vehicleId, playerId = player:getOnlineID(), interiorInstance = interiorInstance });
			end);
end

-------------------------------------------------------------------

adminServerCommandHandlers.serverResetVehicle = function(player)
	player:Say(getText("UI_rvdebug_isreset"))
end

-------------------------------------------------------------------
