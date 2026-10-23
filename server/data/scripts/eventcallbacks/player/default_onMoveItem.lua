local ec = EventCallback

-- Valdoria: items players can't move. Staff can still move them, to rearrange the map in game.
-- Either give one item action id 100 (in RME: right-click the item > Properties > Action ID),
UNMOVABLE_ACTION_ID = 100
-- or lock every copy of an item lying on the map by putting its item id here (the id /i and RME use),
-- for example: [1442] = true, -- statue
UNMOVABLE_ITEM_IDS = {
	[26094] = true, -- protectress lamp
	[2604] = true, -- coal basin
	[32906] = true, -- warm bonfire
}

ec.onMoveItem = function(self, item, count, fromPosition, toPosition, fromCylinder, toCylinder)
	if not self:getGroup():getAccess() then
		if item:getActionId() == UNMOVABLE_ACTION_ID then
			return RETURNVALUE_NOTMOVEABLE
		end
		-- Only on the map, so a player who somehow has one in a backpack can still move it.
		if UNMOVABLE_ITEM_IDS[item:getId()] and fromPosition.x ~= CONTAINER_POSITION then
			return RETURNVALUE_NOTMOVEABLE
		end
	end

	if item:getAttribute("wrapid") ~= 0 then
		local tile = Tile(toPosition)
		if (fromPosition.x ~= CONTAINER_POSITION and toPosition.x ~= CONTAINER_POSITION) or tile and not tile:getHouse() then
			if tile and not tile:getHouse() then
				return RETURNVALUE_NOTPOSSIBLE
			end
		end
	end

	if toPosition.x ~= CONTAINER_POSITION then
		return RETURNVALUE_NOERROR
	end

	if item:getTopParent() == self and bit.band(toPosition.y, 0x40) == 0 then
		local itemType, moveItem = ItemType(item:getId())
		if bit.band(itemType:getSlotPosition(), SLOTP_TWO_HAND) ~= 0 and toPosition.y == CONST_SLOT_LEFT then
			moveItem = self:getSlotItem(CONST_SLOT_RIGHT)
		elseif itemType:getWeaponType() == WEAPON_SHIELD and toPosition.y == CONST_SLOT_RIGHT then
			moveItem = self:getSlotItem(CONST_SLOT_LEFT)
			if moveItem and bit.band(ItemType(moveItem:getId()):getSlotPosition(), SLOTP_TWO_HAND) == 0 then
				return RETURNVALUE_NOERROR
			end
		end

		if moveItem then
			local parent = item:getParent()
			if parent:isContainer() and parent:getSize() == parent:getCapacity() then
				return RETURNVALUE_CONTAINERNOTENOUGHROOM
			else
				return moveItem:moveTo(parent) and RETURNVALUE_NOERROR or RETURNVALUE_NOTPOSSIBLE
			end
		end
	end

	return RETURNVALUE_NOERROR
end

ec:register()
