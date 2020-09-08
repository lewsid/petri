pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- cells
-- by lewsidboi/smolboigames, 2020

version="a.0.6"

--game parameters
cells={}
food={}
upkeep={frames=0,seconds=0}

config={
 food_sparsity=5,--higher=less
 food_rate=1,--higher=slower
 spawn_count=5,
 border=0,
 mutation_rate=5,
 start_move_count=20,
 max_moves=200,
 food_col=4,
 show_ui=true}
 
stats={
 births=0,
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
 cls()
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
  last_move=1,
  state="alive",
  dna={}}
 
 if(parent) then
 	--spawn on parent
 	cell.x=parent.x
 	cell.y=parent.y
 	cell.last_move=1
 	
 	--inherit dna
  cell["dna"]=copy(parent["dna"])
 
 	--add pattern mutation(s)
  for i=0,config.mutation_rate do  
   if(#cell["dna"]["pattern"]+1<config.max_moves)
    then
   		cell["dna"]["pattern"]
    	[#cell["dna"]["pattern"]+1]=
    	flr(rnd(4))+1
  	end
  end
  
  --output move list
  local output="["
  for i=1,#cell["dna"]["pattern"] do
   output=output..cell["dna"]["pattern"][i];
   if(i!=#cell["dna"]["pattern"]) then
   	output=output.."|"
   end  
  end
  output=output.."]"
  printh(output)
 else
  --set random attributes
  cell["dna"]["speed"]=flr(rnd(4))
  cell["dna"]["heartiness"]=flr(rnd(4))
  cell["dna"]["pattern"]={}
 
  for i=1,config.start_move_count do
   cell["dna"]["pattern"][i]
    =flr(rnd(4))+1
  end
  
 end
 
 --update generation counter
 local dif=#cell["dna"]["pattern"]
  -config.start_move_count
 
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
 	
 	--turn it into food
 	food[cell.x][cell.y]=1
 	stats.food_count+=1
 	
 	--death sound
 	--sfx(1)
 	 
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
	if(cell.health>15) then
		cell.health-=5
		new_cell=init_cell(cell)
		stats.births+=1
	end
	
	local move=cell["dna"]["pattern"][cell.last_move]
	if(move==1) then
	 --right
		cell.dir_x=1
		cell.dir_y=0
	elseif(move==2) then
	 --down
	 cell.dir_x=0
	 cell.dir_y=1
	elseif(move==3) then
	 --up
	 cell.dir_x=0
	 cell.dir_y=-1
	elseif(move==4) then
	 --left
		cell.dir_x=-1
		cell.dir_y=0
	end
	
	--update cell move
	cell.x+=cell.dir_x
	cell.y+=cell.dir_y
	
	if(cell.last_move>=#cell["dna"]["pattern"]) then
	 cell.last_move=1
	else
	 cell.last_move+=1
	end
	
	--wrap boundaries
	if(config.border==1) then
	 if(cell.y>127) cell.y=127
	 if(cell.y<0) cell.y=0
  if(cell.x>127) cell.x=127
  if(cell.x<0) cell.x=0
	else
	 if(cell.y>127) cell.y=0
	 if(cell.y<0) cell.y=127
  if(cell.x>127) cell.x=0
  if(cell.x<0) cell.x=127
	end
	
	--consume food
	if(food[cell.x][cell.y]
	 ==1) then
	 consume_food(cell)
	end
 
 --check health every second
 if(cell.last_check
  <flr(upkeep.seconds)) then
 	cell.health-=1
 	if(cell.health==0) then
 	 cell.state="dead"
 	end
 end

	--update the last health check
	cell.last_check=flr(upkeep.seconds)
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
 print("cells: "..#cells,2,2,1)
	print("cells: "..#cells,1,1,7)
	
	print("children: "..stats.births,2,9,1)
	print("children: "..stats.births,1,8,7)
	
	print("food: "..stats.food_count,2,16,1)
	print("food: "..stats.food_count,1,15,7)

 print("gen: "..stats.generation,2,23,1)
	print("gen: "..stats.generation,1,22,7)
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
-->8
--scraps

function random_move(cell)
 --make a random move
	local move=flr(rnd(4))
	if(move==0) then
	 --right
		cell.dir_x=1
		cell.dir_y=0
	elseif(move==1) then
	 --down
	 cell.dir_x=0
	 cell.dir_y=1
	elseif(move==2) then
	 --up
	 cell.dir_x=0
	 cell.dir_y=-1
	elseif(move==3) then
	 --left
		cell.dir_x=-1
		cell.dir_y=0
	end
	
	return cell
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
0002000010550024000d5500050008550024000555003400034000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
