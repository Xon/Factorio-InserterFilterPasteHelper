local filterBlackListTargets = {
    ["container"] = true,
    ["logistic-container"] = true,
}

local filterWhiteListTargets = {
    ["transport-belt"] = true,
    ["splitter"] = true,
    ["underground-belt"] = true,
    -- belt-boxes are furances
    ["furnace"] = true,
}

script.on_event(defines.events.on_entity_settings_pasted, function(event)
	local source = event.source
	local destination = event.destination

	if (source.type == 'assembling-machine') and (destination.type == 'inserter') then
        local machine = source
        local inserter = destination
        local x = 0
        local num_slots = inserter.prototype.filter_count
        inserter.inserter_filter_mode = "blacklist"

        local dropTarget = inserter.drop_target
        if (dropTarget ~= nill) then
            local dropTargetType = dropTarget.type
            local applyBlackList = filterBlackListTargets[dropTargetType] ~= nil
            local applyWhiteList = filterWhiteListTargets[dropTargetType] ~= nil

            if applyBlackList or applyWhiteList then
                -- special case dropping into a non requester/buffer container as these are likely outputs not inputs
                if (dropTargetType == "logistic-container") then
                    local ctrl = inserter.get_or_create_control_behavior()
                    local c1 = ctrl.get_circuit_network(defines.wire_type.red)
                    local c2 = ctrl.get_circuit_network(defines.wire_type.green)
                    if (ctrl ~= nil and c1 == nil and c1 == nil) then
                        ctrl.connect_to_logistic_network = false
                    end

                    local logisticsMode = dropTarget.prototype.logistic_mode
                    if (logisticsMode ~= "requester" and logisticsMode ~= "buffer") then
                        applyBlackList = false
                        applyWhiteList = true
                    end
                end

                local recipe = machine.get_recipe()
                local products = recipe.products
                local ingredients = recipe.ingredients
                local cyclicIngredients = {}
                local hasCyclicIngredients = false

                for _, product in pairs(products) do
                    if (product.type == 'item') then
                        local item_name = product.name
                        for _, ingredient in pairs(ingredients) do
                            if (ingredient.type == 'item' and item_name == ingredient.name) then
                                cyclicIngredients[item_name] = 1
                                hasCyclicIngredients = true
                            end
                        end
                    end
                end

                if (hasCyclicIngredients) then
                    if applyWhiteList then
                        inserter.inserter_filter_mode = "whitelist"
                        for item_name, _ in pairs(cyclicIngredients) do
                            if (x < num_slots) then
                                x = x + 1
                                inserter.set_filter(x, item_name)
                            end
                        end
                    else
                        local hasNonCyclicOutputs = false
                        local nonCyclicOutputs = {}
                        for _, product in pairs(products) do
                            if (product.type == 'item') then
                                local item_name = product.name
                                if (cyclicIngredients[item_name] == nil) then
                                    nonCyclicOutputs[item_name] = 1
                                    hasNonCyclicOutputs = true
                                end
                            end
                        end

                        inserter.inserter_filter_mode = "whitelist"
                        if (hasNonCyclicOutputs) then
                            for item_name, _ in pairs(nonCyclicOutputs) do
                                if (x < num_slots) then
                                    x = x + 1
                                    inserter.set_filter(x, item_name)
                                end
                            end
                        end
                    end
                end
            end
        end

        while (x < num_slots) do
            x = x + 1
            inserter.set_filter(x, nil)
        end
	end
end)