pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- petri
-- by lewsidboi/smolboigames, 2021

version="a.0.9.9"

--game parameters
cells={}
food={}
reticle={}

upkeep={frames=0,seconds=0}

splash={
	logo_step=0,
	logo_x=37,
	logo_y=1
}

config={
	debug=true,		  	  --enable debug mode/logging
	food_sparsity=5,	  --initial food amount, higher=less
	food_rate=1,		  --higher=slower
	spawn_count=10,	  	  --initial number of cells
	border=false,		  --trap them in if you want
	mutation_rate=2, 	  --higher=more mutations per birth
	start_move_count=20,  --base number of moves per cell
	max_moves=60,		  --max number of moves stored in DNA
	max_health=20,		  --max health (limits infinite food consumption)
	food_col=4,			  --color of food
	reproduction_req=15,  --health required to reproduce
	reproduction_cost=5,  --health lost from reproduction
	show_ui=true,		  --show stats
	show_tails=true,	  --show cell tails
	show_reticle=true,    --show reticle
	pause=false
}

stats={
	births=0,
	deaths=0,
	generation=0,
	food_count=0
}

function _init()
	cls()
	sfx(2,0)
	init_food()
	init_reticle()
	for i=1,config.spawn_count do
		init_cell()
	end
end

function _update()
	update_clock()

	if(config.started!=true) then
		update_logo()
	else
		update_food()
	
		--update cells
		foreach(cells,update_cell)
		
		handle_input()
	end
end

function _draw()
	cls(0)

	if(config.started!=true) then
		draw_logo()
	else
		foreach(cells,draw_cell)
		draw_food()
		if(config.show_ui) draw_ui()
		if(config.show_reticle) draw_reticle()
	end
end

-->8
--inits

function init_reticle()
	reticle={
		sprite=2,
		x=48,
		y=48,
		dir_x=0,
		dir_y=0
	}
end

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
	local roll=nil
	local spin=nil
	local mod=nil
	local output=nil
	local slot=nil
	local new_agility=nil
	local new_speed=nil
	local new_heartiness=nil

	--basic template
	cell={
		health=10,
		x=64,
		y=64,
		col=3,
		dir_x=0,
		dir_y=0,
		last_check=0,
		last_dir=1,
		state="alive",
		gen=0,
		tail={},
		dna={}
	}
 
	if(parent) then
		--spawn on parent
		cell.x=parent.x
		cell.y=parent.y
		cell.last_dir=1
	
		--inherit dna
		cell["dna"]=copy(parent["dna"])

		--increase the cell generation
		cell.gen=parent.gen+1

		--if this is the highest new gen make note
		if(cell.gen>stats.generation) then
			stats.generation=cell.gen
		end

		--set tail starts
		if(config.show_tails) then
			cell.tail['x1']=cell.x
			cell.tail['y1']=cell.y
			cell.tail['x2']=cell.x
			cell.tail['y2']=cell.y
		end
 
		--add pattern mutations
		for i=1,config.mutation_rate do  
			if(#cell["dna"]["pattern"]+1<config.max_moves) then
				cell["dna"]["pattern"][#cell["dna"]["pattern"]+1]=flr(rnd(4))+1
			else
				--max moves was reached, randomly replace an existing one
				--this prevents eventual out-of-memory issues
				slot = flr(rnd(#cell["dna"]["pattern"]))+1;
				cell["dna"]["pattern"][slot]=flr(rnd(4))+1
			end
		end

		--add attribute mutations
		if(flr(rnd(10-config.mutation_rate))==0) then
			roll=flr(rnd(3))
			spin=flr(rnd(2))

			if(spin==0) then
				mod=1
			else
				mod=-1
			end

			if(roll==0) then
				new_agility = cell["dna"]["agility"]+mod
				if(new_agility>0 and new_agility<=10) then
					cell["dna"]["agility"]=new_agility
				end
			elseif(roll==1) then
				new_speed = cell["dna"]["speed"]+mod
				if(new_speed>0 and new_speed<=10) then
					cell["dna"]["speed"]=new_speed
				end
			elseif(roll==2) then
				new_heartiness = cell["dna"]["heartiness"]+mod
				if(new_heartiness>0 and new_heartiness<=10) then
					cell["dna"]["heartiness"]=new_heartiness
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
	output="["
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
	if(config.debug==true) then
		printh(output,"pertri_log.md",false,true)
	end
 
	--add cell
	add(cells,cell)
 
	--play birth sound
 	sfx(0)
 
	return cell
end

-->8
--updates

function update_clock()
	if(upkeep.frames<30) then
		upkeep.frames+=1
	elseif(upkeep.frames==30) then
		upkeep.seconds+=1
		upkeep.frames=0
	end
end

function update_logo()
	if(splash.logo_y<60) then
		splash.logo_y+=1
	elseif(splash.logo_step==0 and upkeep.seconds>2) then
		splash.logo_step=1
	elseif(splash.logo_step==1) then
		splash.logo_step=2
	elseif(splash.logo_step==2) then
		splash.logo_step=3
		config.started=true
	end
end

function update_food()
	if(flr(rnd(config.food_rate))==0
		and #cells>0) then
		init_pellet()
	end
end

function update_cell(cell)
	local agility_coefficient=nil
	local direction=nil
	local changed_dir=false

	--handle cell death
	if(cell.state=="dead") then
		del(cells,cell)

		--death sound
		sfx(1)
		
		--turn it into food
		food[cell.x][cell.y]=1
		stats.food_count+=1

		--if tails are on, turn those into food too
		if(config.show_tails) then
			food[cell.tail['x1']][cell.tail['y1']]=1
			food[cell.tail['x2']][cell.tail['y2']]=1
			stats.food_count+=2
		end
		
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
	agility_coefficient=10-cell["dna"]["agility"]
	direction=cell["dna"]["pattern"][cell.last_dir]

	if(flr(rnd(agility_coefficient))==0) then
		if(direction==1) then
			--right
			cell.dir_x=1
			cell.dir_y=0
		elseif(direction==2) then
			--down
			cell.dir_x=0
			cell.dir_y=1
		elseif(direction==3) then
			--up
			cell.dir_x=0
			cell.dir_y=-1
		elseif(direction==4) then
			--left
			cell.dir_x=-1
			cell.dir_y=0
		end

		changed_dir=true
	end

	--higher speed=more likely to move this cycle
	local speed_coefficient=10-cell["dna"]["speed"]

	if(flr(rnd(speed_coefficient))==0) then
		if(config.show_tails) then
			--update tail
			last_x=cell.tail['x1']
			last_y=cell.tail['y1']
			
			--only update if necessary (otherwise tails appear shrunken)
			if(cell.x!=last_x) cell.tail['x1']=cell.x
			if(cell.y!=last_y) cell.tail['y1']=cell.y
			if(cell.tail['x2']!=last_x) cell.tail['x2']=last_x
			if(cell.tail['y2']!=last_y) cell.tail['y2']=last_y
		end

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

function handle_input()
	--toggle stats display
	if(btnp(5)) then
		config.show_ui=not(config.show_ui)
	end

	--toggle pause
	if(btnp(4)) then
		config.pause=not(config.pause)
	end

	--left
	if(btn(0)) then
		if(reticle.dir_x>-5) then
			reticle.dir_x+=-1
		end
	elseif(reticle.dir_x<0) then
		reticle.dir_x=0
	end

	--right
	if(btn(1)) then
		if(reticle.dir_x<5) then
			reticle.dir_x+=1
		end
	elseif(reticle.dir_x>0) then
		reticle.dir_x=0
	end
	
	--up
	if(btn(2)) then
		if(reticle.dir_y>-5) then
			reticle.dir_y-=1
		end
	elseif(reticle.dir_y<0) then
		reticle.dir_y=0
	end

	--down
	if(btn(3)) then
		if(reticle.dir_y<5) then
			reticle.dir_y+=1
		end
	elseif(reticle.dir_y>0) then
		reticle.dir_y=0
	end

	reticle.x+=reticle.dir_x
	reticle.y+=reticle.dir_y

	--loop reticle x pos
	if(reticle.x<0) then
		reticle.x=128
	elseif(reticle.x>128) then
		reticle.x=0
	end

	--loop reticle y pos
	if(reticle.y<0) then
		reticle.y=128
	elseif(reticle.y>128) then
		reticle.y=0
	end
end

-->8
--draws

function draw_logo()
	if(splash.logo_step==0) then
		print("smolboi games",
			splash.logo_x,splash.logo_y-1,0)
		print("smolboi games",
			splash.logo_x,splash.logo_y,12)
	elseif(splash.logo_step==1) then
		print("smolboi games",
			splash.logo_x,splash.logo_y,13)
	elseif(splash.logo_step==2) then
		print("smolboi games",
			splash.logo_x,splash.logo_y,1)
	elseif(splash.logo_step==3) then
		print("smolboi games",
			splash.logo_x,splash.logo_y,0)
	end
end

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

function draw_reticle()
	spr(2,reticle.x,reticle.y)
end

function draw_cell(cell)
	if(cell.state!="dead") then
		pset(cell.x,cell.y,cell.col)
		if(config.show_tails) then
			pset(cell.tail['x1'],cell.tail['y1'],cell.col)
			pset(cell.tail['x2'],cell.tail['y2'],cell.col)
		end
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
00700700000cc0000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700000caac000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000cc0000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00030000157001674018700197401a7001b7401c7001f740217002274025700267402670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000100500e050100500050008500024000550003400034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e0000220551b0551e05519055250551300531005300052f0052f0051e0552e0052d00524005270552d00522005330552d0052400525005260052e005280052e005290052f0052c00530005300053100532005