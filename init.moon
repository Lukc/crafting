
split_at = (input, limit) ->
	output = input
	current_index = 1
	line_index = 1
	last_space_index = 0

	while current_index < #output
		current_character = output\sub current_index, current_index
		current_index += 1
		line_index += 1

		if current_character == " "
			last_space_index = current_index - 1

		if line_index >= limit
			output = output\sub(1, last_space_index) ..
				"\n" ..
				output\sub(last_space_index + 1, #output)
			line_index = 1

	output

FormSpecBuilder = class
	new: (f) =>
		@._content = ""

		f @

	append: (str) =>
		@._content ..= str

	label: (x, y, text) =>
		@\append "label[#{x},#{y};#{text}]"

	size: (w, h) =>
		@\append "size[#{w},#{h}]"

	image: (x, y, w, h, texture) =>
		@\append "image[#{x},#{y};#{w},#{h};#{texture}]"
	item_image: (x, y, w, h, item_name) =>
		@\append "item_image[#{x},#{y};#{w},#{h};#{item_name}]"
	background: (x, y, w, h, texture) =>
		@\append "background[#{x},#{y};#{w},#{h};#{texture}]"

	button: (x, y, w, h, name, label) =>
		@\append "button[#{x},#{y};#{w},#{h};#{name};#{label}]"

	image_button: (x, y, w, h, image, name, label) =>
		@\append "image_button[#{x},#{y};#{w},#{h};#{image};#{name};#{label}]"

	list: (who, what, x, y, w, h) =>
		@\append "list[#{who};#{what};#{x},#{y};#{w},#{h}]"

	textlist: (x, y, w, h, name, elements) =>
		@\append "textlist[#{x},#{y};#{w},#{h};#{name};#{table.concat elements, ","}]"

	field: (x, y, w, h, label, name, default) =>
		@\append "field[#{x},#{y};#{w},#{h};#{label};#{name or ""};#{default}]"

	-- FIXME: Tables handling is particularly horrible, even by formspecs’ standards.
	table: (x, y, w, h, name, cells, selected_id) =>
		@\append "table[#{x},#{y};#{w},#{h};#{name};#{table.concat cells, ","};#{selected_id}]"
	tableoptions: (args) =>
		@\append "tableoptions[#{table.concat args, ";"}]"

	__tostring: => @._content

get_inventory_items = (player_name) ->
	player = minetest.get_player_by_name player_name
	inventory = player\get_inventory!
	stacks = inventory\get_list "main"

	available_items = {}

	for stack in *stacks
		stack = stack\to_table!

		continue unless stack and stack.item

		available_items[stack.item] or= 0
		available_items[stack.item] += count

	available_items

get_available_recipes = (player_name) ->
	recipes = {
		{
			item: "default:mese_block"
			ingredients: {
				"default:stone"
				"default:desert_stone"
				"default:sandstone"
				"default:silver_sandstone"
				"default:desert_sandstone"
				"default:cobble 4"
				"default:desert_cobble 4"
				"default:stone_with_diamond"
				"default:stone_with_coal 9"
				"default:stone_with_iron 5"
				"default:stone_with_copper 4"
				"default:stone_with_tin 3"
				"default:stone_with_mese 2"
			}
		}
		{
			item: "default:wood"
			ingredients: {
				"default:tree"
			}
		}
		{
			item: "default:stone"
			ingredients: {
				"default:cobble"
			}
		}
	}

	-- This will crash in case of unexisting node.
	-- FIXME: Check they exist. And then purposefully crash anyway.
	registered_nodes = minetest.registered_nodes
	for recipe in *recipes
		registered_node = registered_nodes[recipe.item]
		recipe.icon = registered_node.tiles[1]
		recipe.description = registered_node.description

	recipes

contexts = {}
get_context = (name) ->
	contexts[name] or= {
		available_recipes: get_available_recipes name
	}
	
	contexts[name]

-- FIXME: Define a prefix and export it in that prefix.
get_formspec = (player) ->
	context = get_context player\get_player_name!

	tostring FormSpecBuilder =>
		@\size 10, 9

		recipes = get_available_recipes player\get_player_name!

		images_list = [i .. "=" .. recipes[i].icon for i = 1, #recipes]
		@\append "tablecolumns[color,span=2;image," ..
			table.concat(images_list, ",") .. ";text]"
		table_content = {}
		for i, item in ipairs recipes
			table.insert table_content, "#FFFFFF"
			table.insert table_content, tostring i
			table.insert table_content, (item.description\gsub("\n.*", ""))
		@\table 0, 0, 4.5, 4.75, "craft:item", table_content, -1

		selected_recipe = context.selected_recipe
		if selected_recipe
			@\image 10 - 2, 0, 1.5, 1.5, selected_recipe.icon
			@\label 4.75, 0, selected_recipe.description\gsub("\n.*", "")
			@\label 4.75, 1.5, split_at (selected_recipe.description\gsub("^[^\n]*\n*", "") or ""), 50

			player_inventory = player\get_inventory!

			i = 1
			for ingredient in *selected_recipe.ingredients
				-- FIXME: Ingredients should probably already be stored as ItemStacks.
				stack = ItemStack(ingredient)\to_table!
				name = stack.name
				count = stack.count

				registration = minetest.registered_nodes[name]

				color = if player_inventory\contains_item "main", ItemStack ingredient
					"#FFFFFF"
				else
					"#FF0000"

				line_offset = if i > 8 then 0.75 else 0
				column_offset = 0.6 * if i > 8 then (i - 8) else i
				@\background 4.25 + column_offset, 2.4 + line_offset, 0.5, 0.5,
					registration.tiles[1]
				@\label 4.25 + column_offset, 2.75 + line_offset,
					minetest.colorize color, "×" .. count

				i += 1


		@\button 10 - 0.25 - 3.5,     3.75, 0.5, 1, "craft:alter_amount", "+1"
		@\field  10 - 0.25 - 4.075,   4.05, 1,   1, "craft:amount", "", "1"
		@\button 10 - 0.25 - 4.75,    3.75, 0.5, 1, "craft:alter_amount", "-1"

		@\button 10 - 0.25 - 3, 3.75, 3, 1, "craft", "Craft"

		@\list "current_player", "main", 1, 5, 8, 4

sfinv or= {}
sfinv.enabled = false

minetest.register_on_joinplayer (player) ->
	player\set_inventory_formspec get_formspec player
	minetest.chat_send_player player\get_player_name!, "Should have reset inventory formspec to #{get_formspec player}"

minetest.register_on_player_receive_fields (player, form_name, fields) ->
	if form_name != ""
		return false

	player_name = player\get_player_name!

	if fields.quit
		contexts[player_name] = nil

	context = get_context player_name
	if fields["craft:item"]

		event = minetest.explode_table_event fields["craft:item"]

		if event.type == "CHG"
			context.selected_recipe = context.available_recipes[event.row]
			player\set_inventory_formspec get_formspec player

	elseif fields.craft
		item = 1
		amount = fields["craft:amount"] or 1
		amount = tonumber amount

		selected_recipe = context.selected_recipe
		print "Requested crafting for: #{amount}× #{selected_recipe.description}"

		unless selected_recipe
			return true

		player_inventory = player\get_inventory!
		all_items_in_inventory = true
		while item <= amount and all_items_in_inventory
			for ingredient in *selected_recipe.ingredients
				-- FIXME: Ingredients should probably already be stored as ItemStacks.
				stack = ItemStack ingredient
				unless player_inventory\contains_item "main", stack
					all_items_in_inventory = false
					break

			for ingredient in *selected_recipe.ingredients
				-- FIXME: Ingredients should probably already be stored as ItemStacks.
				-- FIXME: Check they were actually removed. This might be abusable.
				stack = ItemStack ingredient
				player_inventory\remove_item "main", stack

			if all_items_in_inventory
				player_inventory\add_item "main", ItemStack context.selected_recipe.item

				item += 1
	else
		-- Something went horribly wrong here: client sent an unrecognized instruction.
		-- FIXME: Somehow notify someone of it?
		return false

	true

