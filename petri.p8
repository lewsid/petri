pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- petri
-- by lewsidboi/smolboigames, 2021

version="a.1.0.1"

--game parameters
cells={}
food={}
reticle={}

upkeep={frames=0,seconds=0}

--smolboi games splash
splash={
	logo_step=0,
	logo_x=37,
	logo_y=1,
	complete=false
}

intro={
	sprite=128,
	width=45,
	height=30,
	complete=false
}

config={
	debug=false, --enable debug mode/logging
	show_log=false, --show log
	last_log={},
	last_dna={},
	food_sparsity=8, --initial food amount, higher=less
	food_rate=5, --spawn rate higher=slower
	food_batch_size=1, --how many food pellets spawn at once
	spawn_count=30, --initial number of cells
	border=1, --trap them in if you want
	mutation_rate=2, --higher=more mutations per birth
	start_move_count=20, --base number of moves per cell
	max_moves=60, --max number of moves stored in dna
	max_health=20, --max health (limits infinite food consumption)
	food_col=4,	--color of food
	reproduction_req=15, --health required to reproduce
	reproduction_cost=5, --health lost from reproduction
	show_stats=true, --show stats
	show_tails=true, --show cell tails
	show_reticle=false, --show reticle
	pause=false
}

stats={
	births=0,
	deaths=0,
	generation=0,
	food_count=0
}

function _init()
	init_menu()
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

	if(splash.complete!=true) then
		update_logo()
	elseif(intro.complete!=true) then
		update_intro()
	else
		update_food()
		foreach(cells,update_cell)
		handle_input()
	end
end

function _draw()
	pal(15, 129, 1)
	cls(15)

	if(config.debug == true) then
		splash.complete=true
		intro.complete=true
	end

	if(splash.complete!=true) then
		draw_splash()
	elseif(intro.complete!=true) then
		draw_intro()
	else
		if(config.show_log) then
			draw_log()
		else
			foreach(cells,draw_cell)
			draw_food()
			if(config.show_stats) draw_stats()
			if(config.show_reticle) draw_reticle()
			if(config.border==1) rect(0,0,127,127,6)
		end
	end
end

-->8
--inits

function init_menu()
	menuitem(0, "spawn "..config.spawn_count.." cells", function(b) 
		if(b&1>0) then
			if(config.spawn_count>1) then
				config.spawn_count-=1
			end
		elseif(b&2>0) then
			if(config.spawn_count<60) then
				config.spawn_count+=1
			end
		elseif(b&32 > 0) then
			for i=1,config.spawn_count do
				init_cell()
			end
		end
		menuitem(1, "spawn "..config.spawn_count.." cells")
		
		return false
	end)

	menuitem(1, "disable border", function()
		if(config.border==1) then
			config.border=0
			menuitem(1, "enable border")
		else
			config.border=1
			menuitem(1, "disable border")
		end
		return true
	end)

	menuitem(2, "food delay:"..config.food_rate, function(b)
		if(b&1>0) then
			if(config.food_rate>1) then
				config.food_rate-=1
			end
		elseif(b&2>0) then
			if(config.food_rate<40) then
				config.food_rate+=1
			end
		end
		menuitem(3, "food delay:"..config.food_rate)
		return true
	end)

	menuitem(3, "food density:"..config.food_batch_size, function(b)
		if(b&1>0) then
			if(config.food_batch_size>1) then
				config.food_batch_size-=1
			end
		elseif(b&2>0) then
			if(config.food_batch_size<10) then
				config.food_batch_size+=1
			end
		end
		menuitem(4, "food density:"..config.food_batch_size)
		return true
	end)

	menuitem(4, "mutation rate:"..config.mutation_rate, function(b)
		if(b&1>0) then
			if(config.mutation_rate>1) then
				config.mutation_rate-=1
			end
		elseif(b&2>0) then
			if(config.mutation_rate<10) then
				config.mutation_rate+=1
			end
		end
		menuitem(5, "mutation rate:"..config.mutation_rate)
		return true
	end)

	menuitem(5, "toggle tails", function()
		if(config.show_tails) then
			config.show_tails=false
			menuitem(2, "show tails")
		else
			config.show_tails=true
			menuitem(2, "hide tails")
		end
		return true
	end)
end

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

	--output dna
	output=""
	output=output.."GEN:"..cell.gen.." "
	output=output.."AGI:"..cell["dna"]["agility"].." "
	output=output.."STR:"..cell["dna"]["heartiness"].." "
	output=output.."SPD:"..cell["dna"]["speed"].." "
	
	--push output to log table
	add(config.last_log,output)
	add(config.last_dna,cell["dna"]["pattern"])

	if(#config.last_log>18) then
		del(config.last_log,1)
		del(config.last_dna,1)
	end

	if(config.debug==true) then
		printh(output,"pertri_log.md",false,true)
	end
 
	--add cell
	add(cells,cell)
 
	--play birth sound
	if(splash.complete) then
 		sfx(0)
 	end
 
	return cell
end

-->8
--updates

function update_intro()
	if(btnp(4) or btnp(5)) then
		intro.complete=true
	end
end

function update_clock()
	if(upkeep.frames<30) then
		upkeep.frames+=1
	elseif(upkeep.frames==30) then
		upkeep.seconds+=1
		upkeep.frames=0
	end
end

function update_logo()
	if(splash.logo_y<58) then
		splash.logo_y+=1
	elseif(splash.logo_step==0 and upkeep.seconds>2) then
		splash.logo_step=1
	elseif(splash.logo_step==1) then
		splash.logo_step=2
	elseif(splash.logo_step==2) then
		splash.logo_step=3
	elseif(splash.logo_step==3 and upkeep.seconds>3) then
		splash.complete=true
	end
end

function update_food()
	if(flr(rnd(config.food_rate))==0
		and #cells>0) then
		for i=1,config.food_batch_size do
			init_pellet()
		end
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
		if(cell.y>126) cell.y=126
		if(cell.y<1) cell.y=1
		if(cell.x>126) cell.x=126
		if(cell.x<1) cell.x=1
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
		if(config.show_stats and not config.show_log) then
			config.show_log=true
		elseif(config.show_log) then
			config.show_stats=false
			config.show_log=false
		else
			config.show_stats=true
		end
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

function draw_intro()
 sspr(0,64,47,87,15,20,100,200)
 print("press ❎ to start",31,101,0)
 print("press ❎ to start",30,100,6)
end

function draw_splash()
	if(splash.logo_step==0) then
		print("SMOLBOI labs",
			splash.logo_x,splash.logo_y-1,0)
		print("SMOLBOI labs",
			splash.logo_x,splash.logo_y,12)
	elseif(splash.logo_step==1) then
		print("SMOLBOI labs",
			splash.logo_x,splash.logo_y,13)
	elseif(splash.logo_step==2) then
		print("SMOLBOI labs",
			splash.logo_x,splash.logo_y,1)
	elseif(splash.logo_step==3) then
		print("SMOLBOI labs",
			splash.logo_x,splash.logo_y,15)
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

function draw_stats()
	print("ALIVE: "..#cells,3,3,0)
	print("ALIVE: "..#cells,2,2,7)
	
	print("BIRTHS: "..stats.births,3,10,0)
	print("BIRTHS: "..stats.births,2,9,7)
	
	print("DEATHS: "..stats.deaths,3,17,0)
	print("DEATHS: "..stats.deaths,2,16,7)

	print("FOOD: "..stats.food_count,3,24,0)
	print("FOOD: "..stats.food_count,2,23,7)

	print("GENERATION: "..stats.generation,3,31,0)
	print("GENERATION: "..stats.generation,2,30,7)
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

--display dna move set as sprite
function draw_dna(dna,x,y)
	for i=1,#dna do
		if(dna[i]==1) then
			pset(x+i,y,12)
		elseif(dna[i]==2) then
			pset(x+i,y,9)
		elseif(dna[i]==3) then
			pset(x+i,y,10)
		elseif(dna[i]==4) then
			pset(x+i,y,11)
		end
	end
end

function draw_log()
	--print out the most recent additions to the log
	cls(1)
	for i=1,18 do
		if(config.last_log[#config.last_log-i+1]!=nil) then
			--output last log scroll from the bottom up, with some padding
			print(config.last_log[#config.last_log-i+1],0,127-i*7,7)
			
			--apend image of DNA
			draw_dna(config.last_dna[#config.last_dna-i+1],-1,i*7)
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ccccc11111111111111ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ccc111111111111111111111111ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000cc11111111ccccccccccccccc1111111cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000cc1111cccccc11111111111111ccccc11111cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c1111ccc111111111111111111111111ccc1111c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c11ccc111111111111411111111111111111ccc11c000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c11cc1113111111111111111411111411111111cc11c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
c11c11111133bbbb14111111111111111111131111c11c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c11111111311113111111111b1111111113111111c1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc111411111b11113111111111b13111111111111111cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1111111111b111131133311bbbb11b13311b11111111c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1111111111bbbbb11b111b111b111bb1111b11111141c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1111111111b111111b111b111b111b11111b11141111c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc141111113b111111bbbbb111b111b11111b1111111cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c11111111b141111b1111111b111b11111b111111c1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c11c111111b3111111b1113111b111b11111b11111c11c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c11cc111b3111111113331111bb11b11111b111cc11c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c111cc111111111111111111111311111111cc111c000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c1111ccc111111111111141111111111ccc1111c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000cc11111ccccc11111111111111ccccc11111cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000cc11111111cccccccccccccc11111111cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ccc111111111111111111111111ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ccccc11111111111111ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00030000157001674018700197401a7001b7401c7001f740217002274025700267402670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000100500e050100500050008500024000550003400034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e0000220551b0551e05519055250551300531005300052f0052f0051e0552e0052d00524005270552d00522005330552d0052400525005260052e005280052e005290052f0052c00530005300053100532005
