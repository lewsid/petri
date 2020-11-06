pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- petri
-- by lewsidboi/smolboigames, 2020

version="a.0.9.2"

--game parameters
cells={}
food={}

upkeep={frames=0,seconds=0}

config={
	food_sparsity=5,	  --higher=less
	food_rate=1,		  --higher=slower
	spawn_count=10,	  	  --initial number of cells
	border=1,			  --trap them in if you want
	mutation_rate=2, 	  --higher=more mutations per birth
	start_move_count=20,  --base number of moves per cell
	max_moves=60,		  --max number of moves stored in DNA
	max_health=20,		  --max health (limits infinite food consumption)
	food_col=4,			  --color of food
	reproduction_req=15,  --health required to reproduce
	reproduction_cost=5,  --health lost from reproduction
	show_ui=true		  --show stats
}

stats={
	births=0,
	deaths=0,
	generation=0,
	food_count=0
}

function _init()
	cls()
	init_food()
	for i=1,config.spawn_count do
		init_cell()
	end
end

function _update()
	--clock upkeep
	upkeep.seconds=upkeep.frames/30
	upkeep.frames+=1
	
	--respawn food
	if(flr(rnd(config.food_rate))==0
		and #cells>0) then
		init_pellet()
	end
	
	--update cells
	foreach(cells,update_cell)
	
	--toggle stats display
	if(btnp(❎)) then
		config.show_ui=not(config.show_ui)
	end
end

function _draw()
	cls(0)
	foreach(cells,draw_cell)
	draw_food()
	if(config.show_ui) draw_ui()
end

-->8
--inits

function init_food()
	for x=0,127 do
		food[x]={}
		for y=0,127 do
			food[x][y]=flr(rnd(config.food_sparsity))+1
			if(food[x][y]==1) then
				stats.food_count+=1
			end
		end
	end
end

--spawn a food pellet
function init_pellet()
	local r_x=flr(rnd(128))
	local r_y=flr(rnd(128))
 
	if(food[r_x][r_y]!=1) then
		food[r_x][r_y]=1
		stats.food_count+=1
	end
end

function init_cell(parent)
	--basic template
	cell={
		health=10,x=64,y=64,
		col=3,dir_x=0,dir_y=0,
		last_check=0,
		last_dir=1,
		state="alive",
		dna={}
	}
 
	if(parent) then
		--spawn on parent
		cell.x=parent.x
		cell.y=parent.y
		cell.last_dir=1
	
		--inherit dna
		cell["dna"]=copy(parent["dna"])
 
		--add pattern mutations
		for i=1,config.mutation_rate do  
			if(#cell["dna"]["pattern"]+1<config.max_moves) then
				cell["dna"]["pattern"][#cell["dna"]["pattern"]+1]=flr(rnd(4))+1
			else
				--max moves was reached, randomly replace an existing one
				--this prevents eventual out-of-memory issues
				local slot = rnd(#cell["dna"]["pattern"])+1;
				cell["dna"]["pattern"][slot]=flr(rnd(4))+1
			end
		end

		--add attribute mutations
		if(flr(rnd(10-config.mutation_rate))==0) then
			local roll=flr(rnd(3))
			local spin=rnd(2)
			local mod=nill

			if(spin==0) then
				mod=1
			else
				mod=-1
			end

			if(roll==0) then
				if(cell["dna"]["agility"]>0 and cell["dna"]["agility"]<10) then
					cell["dna"]["agility"]+=mod
				end
			elseif(roll==1) then
				if(cell["dna"]["speed"]>0 and cell["dna"]["speed"]<10) then
					cell["dna"]["speed"]+=mod
				end
			elseif(roll==2) then
				if(cell["dna"]["heartiness"]>0 and cell["dna"]["heartiness"]<10) then
					cell["dna"]["heartiness"]+=mod
				end
			end
				
		end
	else
		--set random attributes
		cell["dna"]["agility"]=flr(rnd(10))+1
		cell["dna"]["speed"]=flr(rnd(10))+1
		cell["dna"]["heartiness"]=flr(rnd(10))+1
		cell["dna"]["pattern"]={}
 
		for i=1,config.start_move_count do
			cell["dna"]["pattern"][i]=flr(rnd(4))+1
		end
	end

	--output DNA
	local output="["
	output=output.."(agility: "..cell["dna"]["agility"]..")"
	output=output.."(heartiness: "..cell["dna"]["heartiness"]..")"
	output=output.."(speed: "..cell["dna"]["speed"]..")(moves: "
	for i=1,#cell["dna"]["pattern"] do
		output=output..cell["dna"]["pattern"][i];
		if(i!=#cell["dna"]["pattern"]) then
			output=output.."|"
		end  
	end
	output=output..")]"
	printh(output,"pertri_log.md",false,true)
 
	--update generation counter
	local dif=#cell["dna"]["pattern"]-config.start_move_count
 
	local gen=flr(dif/config.mutation_rate)
  
	if(gen>stats.generation) then
		stats.generation=gen
	end
 
	--add cell
	add(cells,cell)
 
	--play birth sound
 	sfx(0)
 
	return cell
end

-->8
--updates

function update_cell(cell)
	--handle cell death
	if(cell.state=="dead") then
		del(cells,cell)

		--death sound
		sfx(1)
		
		--turn it into food
		food[cell.x][cell.y]=1
		stats.food_count+=1
		
		--count it
		stats.deaths+=1
		 
		return false
	end

	--change cell color
	if(cell.health>=8) then
		cell.col=3
	elseif(cell.health>=6) then
		cell.col=11
	elseif(cell.health>=4) then
		cell.col=10
	elseif(cell.health>=2) then
		cell.col=9
	elseif(cell.health>=1) then
		cell.col=8
	else
		cell.col=0
	end
	
	--reproduce
	if(cell.health>config.reproduction_req) then
		cell.health-=config.reproduction_cost
		new_cell=init_cell(cell)
		stats.births+=1
	end

	--higher agility leads to more directional variation
	--lower agility leads to straighter paths
	local agility_coefficient=10-cell["dna"]["agility"]
	local dir=cell["dna"]["pattern"][cell.last_dir]
	local changed_dir=false

	if(flr(rnd(agility_coefficient))==0) then
		if(dir==1) then
			--right
			cell.dir_x=1
			cell.dir_y=0
		elseif(dir==2) then
			--down
			cell.dir_x=0
			cell.dir_y=1
		elseif(dir==3) then
			--up
			cell.dir_x=0
			cell.dir_y=-1
		elseif(dir==4) then
			--left
			cell.dir_x=-1
			cell.dir_y=0
		end

		changed_dir=true
	end

	--higher speed=more likely to move this cycle
	local speed_coefficient=10-cell["dna"]["speed"]

	if(flr(rnd(speed_coefficient))==0) then
		--update cell move
		cell.x+=cell.dir_x
		cell.y+=cell.dir_y
	
		if(changed_dir) then
			--track the last move and loop 
			--back to the first if end is reached
			if(cell.last_dir>=#cell["dna"]["pattern"]) then
				cell.last_dir=1
			else
				cell.last_dir+=1
			end
		end
	end
	
	if(config.border==1) then
		--trap them in
		if(cell.y>127) cell.y=127
		if(cell.y<0) cell.y=0
		if(cell.x>127) cell.x=127
		if(cell.x<0) cell.x=0
	else
		--wrap boundaries
		if(cell.y>127) cell.y=0
		if(cell.y<0) cell.y=127
		if(cell.x>127) cell.x=0
		if(cell.x<0) cell.x=127
	end
	
	--consume food, if there is room in its belly
	if(food[cell.x][cell.y]==1 
		and cell.health<config.max_health) then
		consume_food(cell)
	end
 
 	--higher heartiness=higher chance to not lose health on this cycle
 	if(flr(rnd(cell["dna"]["heartiness"]))==0) then
 		--check health every second if the heartiness gate is passed
		if(cell.last_check<flr(upkeep.seconds)) then
			cell.health-=1
			if(cell.health<=0) then
				cell.state="dead"
			end

			--update the last health check
			cell.last_check=flr(upkeep.seconds)
		end
	end
end

function consume_food(cell)
	cell.health+=1
	food[cell.x][cell.y]=0
	stats.food_count-=1
end

-->8
--draws

function draw_food()
	for x=0,127 do
		for y=0,127 do
			if(food[x][y]==1) then
				pset(x,y,config.food_col)
			end
		end
	end
end

function draw_ui()
	print("alive: "..#cells,2,2,1)
	print("alive: "..#cells,1,1,7)
	
	print("births: "..stats.births,2,9,1)
	print("births: "..stats.births,1,8,7)
	
	print("deaths: "..stats.deaths,2,16,1)
	print("deaths: "..stats.deaths,1,15,7)

	print("food: "..stats.food_count,2,23,1)
	print("food: "..stats.food_count,1,22,7)

	print("gen: "..stats.generation,2,30,1)
	print("gen: "..stats.generation,1,29,7)
end

function draw_cell(cell)
	if(cell.state!="dead") then
		pset(cell.x,cell.y,cell.col)
	end
end

-->8
--helpers

--deep table copy
--https://stackoverflow.com/a/26367080
function copy(obj,seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
	return res
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00030000157001674018700197401a7001b7401c7001f740217002274025700267402670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000100500e050100500050008500024000550003400034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
