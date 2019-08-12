cnfg = require "config"
game = require "game"
sl = require "spritelist"
mf = require "mathFunctions"
ff = require "fileFunctions"
nf = require "neatFunctions"

Inputs = cnfg.InputSize+1
Outputs = #cnfg.ButtonNames

form = forms.newform(500, 500, "Metroid-Learning")
netPicture = forms.pictureBox(form, 5, 250,470, 200)

event.onexit(onExit)

-- shorten logic? ( += )
function newInnovation()
	pool.innovation = pool.innovation + 1
	
	return pool.innovation
end

-- optimize empty if
function linkMutate(genome, forceBias)
	local neuron1 = nf.randomNeuron(genome.genes, false)
	local neuron2 = nf.randomNeuron(genome.genes, true)
	local newLink = nf.newGene()
	
	if neuron1 <= Inputs and neuron2 <= Inputs then
		--Both input nodes
		return
	end
	
	if neuron2 <= Inputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	
	if forceBias then newLink.into = Inputs	end
	
	if nf.containsLink(genome.genes, newLink) then
		return
	end
	
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

-- optimize empty if
function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	
	gene.enabled = false
	
	local gene1 = nf.copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = nf.copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

-- optimize empty if
function enableDisableMutate(genome, enable)
	local candidates = {}
	
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

-- replace while with recursion
function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then genome = nf.pointMutate(genome) end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then linkMutate(genome, false)	end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then linkMutate(genome, true) end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then nodeMutate(genome) end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then enableDisableMutate(genome, true) end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then enableDisableMutate(genome, false) end
		p = p - 1
	end
end

-- innovation needed?
function basicGenome()
	local genome = nf.newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

function addToSpecies(child)
	local foundSpecies = false
	
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and nf.sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = nf.newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

function newNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = nf.newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[cnfg.NeatConfig.MaxNodes+o] = nf.newNeuron()
	end
	
	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then network.neurons[gene.out] = nf.newNeuron() end
			
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			
			if network.neurons[gene.into] == nil then network.neurons[gene.into] = nf.newNeuron() end
		end
	end
	
	genome.network = network
end

function evaluateNetwork(network, inputs, inputDeltas)
	table.insert(inputs, 1)
	table.insert(inputDeltas,99)
	
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end

	for i=1,Inputs do
		network.neurons[i].value = inputs[i] * inputDeltas[i]
	end
	
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then neuron.value = mf.sigmoid(sum) end
	end
	
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. cnfg.ButtonNames[o]
		if network.neurons[cnfg.NeatConfig.MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	local inputDeltas = {}
	inputs, inputDeltas = game.getInputs()
	controller = evaluateNetwork(genome.network, inputs, inputDeltas)
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)
end

-- make var init extra?
function initializeRun()
	savestate.load(cnfg.NeatConfig.Filename);
	
	pool.currentFrame = 0
	timeout = cnfg.NeatConfig.TimeoutConstant
	game.clearJoypad()
	
	startHealth = game.getHealth()
	startMissiles = game.getMissiles()
	startSuperMissiles = game.getSuperMissiles()
	startBombs = game.getBombs()
	startTanks = game.getTanks()
	
	checkSamusCollision = true
	samusHitCounter = 0
	explorationFitness = 0
	samusXprev = 0
	samusYprev = 0

	if health == nil then health = 0 end

	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	newNetwork(genome)
	evaluateCurrent()
end

function initializePool()
	pool = nf.newPool()

	for i=1,cnfg.NeatConfig.Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun()
end

if pool == nil then initializePool() end

--##########################################################
-- NEAT Functions
--##########################################################

-- extract anon function?
function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then remaining = 1 end
		
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

-- extract anon function?
function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		
		if species.staleness < cnfg.NeatConfig.StaleSpecies or species.topFitness >= pool.maxFitness then table.insert(survived, species) end
	end

	pool.species = survived
end

function removeWeakSpecies()
	local survived = {}
	local sum = nf.totalAverageFitness(pool)
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * cnfg.NeatConfig.Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

-- extract anon function? list functions?
function rankSpecies()
	local global = {}
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

-- enhance return
function crossoverSpecies(species)
	local child = {}
	
	if math.random() < cnfg.NeatConfig.CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(child)
	
	return child
end

function copyGenome(genome)
	local genome2 = nf.newGenome()
	
	for g=1,#genome.genes do
		table.insert(genome2.genes, nf.copyGene(genome.genes[g]))
	end
	
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

function nextGenome()
	pool.currentGenome = pool.currentGenome + 1
	
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
end

-- optimizable
function newGeneration()
	-- Cull the bottom half of each species
	cullSpecies(false)
	rankSpecies()
	removeStaleSpecies()
	rankSpecies()
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		species = nf.calculateAverageFitness(species)
	end
	
	removeWeakSpecies()
	
	local sum = nf.totalAverageFitness(pool)
	local children = {}
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		breed = math.floor(species.averageFitness / sum * cnfg.NeatConfig.Population) - 1
		for i=1,breed do
			table.insert(children, crossoverSpecies(species))
		end
	end
	
	-- Cull all but the top member of each species
	cullSpecies(true)
	
	while #children + #pool.species < cnfg.NeatConfig.Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, crossoverSpecies(species))
	end
	
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
	
	pool.generation = pool.generation + 1
	ff.writeFile(forms.gettext(saveLoadFile) .. ".gen" .. pool.generation .. ".pool")
end

-- list functions instead of for loop?
function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = nf.newGenome()
	local innovations2 = {}
	
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, nf.copyGene(gene2))
		else
			table.insert(child.genes, nf.copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

--##########################################################
-- Display
--##########################################################

-- shorten, divide, break down?
function displayGenome(genome)
	forms.clear(netPicture,0x80808080)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	
	for dy=-cnfg.BoxRadius,cnfg.BoxRadius do
		for dx=-cnfg.BoxRadius,cnfg.BoxRadius do
			cell = {}
			cell.x = 50+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end
	
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
		cell = {}
		cell.x = 220
		cell.y = 30 + 8 * o
		cell.value = network.neurons[cnfg.NeatConfig.MaxNodes + o].value
		cells[cnfg.NeatConfig.MaxNodes+o] = cell
		
		local color
		if cell.value > 0 then
			color = 0xFF0000FF
		else
			color = 0xFF000000
		end
		
		forms.drawText(netPicture, 263, 24+8*o, cnfg.ButtonNames[o], color, 9)
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= cnfg.NeatConfig.MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				
				if gene.into > Inputs and gene.into <= cnfg.NeatConfig.MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					
					if c1.x >= c2.x then c1.x = c1.x - 40 end
					if c1.x < 90 then c1.x = 90 end
					if c1.x > 220 then c1.x = 220 end
					
					c1.y = 0.75*c1.y + 0.25*c2.y
				end
				
				if gene.out > Inputs and gene.out <= cnfg.NeatConfig.MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					
					if c1.x >= c2.x then c2.x = c2.x + 40 end
					if c2.x < 90 then c2.x = 90 end
					if c2.x > 220 then c2.x = 220 end
					
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	forms.drawBox(netPicture, 50-cnfg.BoxRadius*5-3,70-cnfg.BoxRadius*5-3,50+cnfg.BoxRadius*5+2,70+cnfg.BoxRadius*5+2,0xFF000000, 0x80808080)
	
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			
			local opacity = 0xFF000000
			if cell.value == 0 then opacity = 0x50000000 end
			
			color = opacity + color*0x10000 + color*0x100 + color
			forms.drawBox(netPicture,cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end
	
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			
			local opacity = 0xA0000000
			if c1.value == 0 then opacity = 0x20000000 end
			
			local color = 0x80-math.floor(math.abs(mf.sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
			
			forms.drawLine(netPicture,c1.x+1, c1.y, c2.x-3, c2.y, color)
		end
	end
	
	forms.drawBox(netPicture, 49,71,51,78,0x00000000,0x80FF0000)
	
	local pos = 100
	for mutation,rate in pairs(genome.mutationRates) do
		forms.drawText(netPicture,100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
		
		pos = pos + 8
	end
	
	forms.refresh(netPicture)
end


--##########################################################
-- File Management
--##########################################################

ff.writeFile("temp.pool", pool)

-- divide and conquer?
function loadFile(filename)
	print("Loading pool from " .. filename)
    local file = io.open(filename, "r")
    pool = nf.newPool()
    pool.generation = file:read("*number")
    pool.maxFitness = file:read("*number")
    forms.settext(MaxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	
    local numSpecies = file:read("*number")
    for s=1,numSpecies do
        local species = nf.newSpecies()
        table.insert(pool.species, species)
        species.topFitness = file:read("*number")
        species.staleness = file:read("*number")
		
        local numGenomes = file:read("*number")
        for g=1,numGenomes do
            local genome = nf.newGenome()
            table.insert(species.genomes, genome)
            genome.fitness = file:read("*number")
            genome.maxneuron = file:read("*number")
			
            local line = file:read("*line")
            while line ~= "done" do
                genome.mutationRates[line] = file:read("*number")
                line = file:read("*line")
            end
			
            local numGenes = file:read("*number")
            for n=1,numGenes do
                local gene = nf.newGene()
                local enabled				
				local geneStr = file:read("*line")
				
				local geneArr = ff.splitGeneStr(geneStr)
				gene.into = tonumber(geneArr[1])
				gene.out = tonumber(geneArr[2])
				gene.weight = tonumber(geneArr[3])
				gene.innovation = tonumber(geneArr[4])
				enabled = tonumber(geneArr[5])
				
                if enabled == 0 then
                    gene.enabled = false
                else
                    gene.enabled = true
                end
				
				table.insert(genome.genes, gene)
            end
        end
    end
    file:close()   
    
    while nf.fitnessAlreadyMeasured() do
        nextGenome()
    end
	
    initializeRun()
    pool.currentFrame = pool.currentFrame + 1
	print("Pool loaded.")
end

-- switch?
function flipState()
	if cnfg.Running == true then
		cnfg.Running = false
		forms.settext(startButton, "Start")
	else
		cnfg.Running = true
		forms.settext(startButton, "Stop")
	end
end

function savePool()
	local filename = forms.gettext(saveLoadFile)
	print(filename)
	ff.writeFile(filename, pool)
end

function loadPool()
	filename = forms.openfile("default.State.pool")
	forms.settext(saveLoadFile, filename)
	ff.loadFile(filename)
end

-- optimize x = x + 1?
function playTop()
	local maxfitness = 0
	local maxs, maxg
	
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(MaxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
	return
end

function onExit()
	forms.destroy(form)
end

GenerationLabel = forms.label(form, "Generation: " .. pool.generation, 5, 5)
SpeciesLabel = forms.label(form, "Species: " .. pool.currentSpecies, 130, 5)
GenomeLabel = forms.label(form, "Genome: " .. pool.currentGenome, 230, 5)
MeasuredLabel = forms.label(form, "Measured: " .. "", 330, 5)

FitnessLabel = forms.label(form, "Fitness: " .. "", 5, 30)
MaxLabel = forms.label(form, "Max: " .. "", 130, 30)

HealthLabel = forms.label(form, "Health: " .. "", 5, 65)
TankLabel = forms.label(form, "Reserve Tanks: " .. "", 130, 65, 90, 14)
MissilesLabel = forms.label(form, "Missiles: " .. "", 130, 80, 90, 14)
SuperMissilesLabel = forms.label(form, "Super Missiles: " .. "", 230, 65, 90, 14)
BombLabel = forms.label(form, "Power Bombs: " .. "", 230, 80, 110, 14)
DmgLabel = forms.label(form, "Damage: " .. "", 330, 65, 110, 14)

startButton = forms.button(form, "Start", flipState, 155, 102)
restartButton = forms.button(form, "Restart", initializePool, 155, 102)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
playTopButton = forms.button(form, "Play Top", playTop, 230, 102)

saveLoadFile = forms.textbox(form, cnfg.NeatConfig.Filename .. ".pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)

sl.InitSpriteList()
sl.InitExtSpriteList()


--##########################################################
-- Reinforcement Learning
--##########################################################

-- optimize 'x = x + 1'
while true do	
	if cnfg.Running == true then
		local species = pool.species[pool.currentSpecies]
		local genome = species.genomes[pool.currentGenome]
		
		-- update visual interface
		displayGenome(genome)
		
		-- evaluate actions every 5th frame
		if pool.currentFrame%5 == 0 then
			evaluateCurrent()
		end

		-- set next action
		joypad.set(controller)

		-- calculate exploration fitness / manage timeout
		game.getPositions()
		if samusX ~= samusXprev or samusY ~= samusYprev then
			diffX = samusX - samusXprev
			if diffX < 0 then diffX = diffX * -1 end

			diffY = samusY - samusYprev
			if diffY < 0 then diffY = diffY * -1 end

			explorationFitness = explorationFitness + diffX + diffY
			timout = cnfg.NeatConfig.TimeoutConstant
		else
			timeout = timeout - 1
		end
		samusXprev = samusX
		samusYprev = samusY

		-- check for hits
		local hitTimer = game.getSamusHitTimer()
		if checkSamusCollision == true then
			if hitTimer > 0 then
				samusHitCounter = samusHitCounter + 1
				console.writeline("Samus took damage, hit counter: " .. samusHitCounter)
				checkSamusCollision = false
			end
		end
		if hitTimer == 0 then checkSamusCollision = true end
		
		-- react to timeout
		local timeoutBonus = pool.currentFrame / 4
		if timeout + timeoutBonus <= 0 then
			-- calculate pickupFitness
			local missiles = game.getMissiles() - startMissiles
			local superMissiles = game.getSuperMissiles() - startSuperMissiles
			local bombs = game.getBombs() - startBombs
			local tanks = game.getTanks() - startTanks
			
			local pickupFitness = (missiles * 10) + (superMissiles * 100) + (bombs * 100) + (tanks * 1000)
			if (missiles + superMissiles + bombs + tanks) > 0 then 
				console.writeline("Collected Pickups added " .. pickupFitness .. " fitness")
			end
			
			-- calculate hitPenalty
			local hitPenalty = samusHitCounter * 100
		
			-- calculate fitness
			local fitness = explorationFitness + pickupFitness - hitPenalty - pool.currentFrame / 2

			-- calculate extraHealthBonus
			health = game.getHealth()
			if startHealth < health then
				local extraHealthBonus = (health - startHealth)*1000
				fitness = fitness + extraHealthBonus
				console.writeline("Extra Health added " .. extraHealthBonus .. " fitness")
			end

			-- give exploration bonus when reaching Ridley
			if explorationFitness > 5000 then
				fitness = fitness + 10000
				console.writeline("!!!!!!Reached Ridley!!!!!!!")
			end
			if fitness == 0 then
				fitness = -1
			end
			genome.fitness = fitness
			
			-- save best fitness
			if fitness > pool.maxFitness then
				pool.maxFitness = fitness
				ff.writeFile(forms.gettext(saveLoadFile) .. ".gen" .. pool.generation .. ".pool", pool)
			end
			
			-- final report, pool update, next genome 
			console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
			pool.currentSpecies = 1
			pool.currentGenome = 1
			while nf.fitnessAlreadyMeasured(pool) do
				nextGenome()
			end

			-- after fitness is measured, start next generation
			initializeRun()
		end

		-- keep track of measured species
		local measured = 0
		local total = 0
		for _,species in pairs(pool.species) do
			for _,genome in pairs(species.genomes) do
				total = total + 1
				if genome.fitness ~= 0 then
					measured = measured + 1
				end
			end
		end
		
		-- update interface
		gui.drawEllipse(game.screenX-84, game.screenY-84, 192, 192, 0x50000000) 
		forms.settext(FitnessLabel, "Fitness: " .. math.floor(explorationFitness - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3))
		forms.settext(GenerationLabel, "Generation: " .. pool.generation)
		forms.settext(SpeciesLabel, "Species: " .. pool.currentSpecies)
		forms.settext(GenomeLabel, "Genome: " .. pool.currentGenome)
		forms.settext(MaxLabel, "Max: " .. math.floor(pool.maxFitness))
		forms.settext(MeasuredLabel, "Measured: " .. math.floor(measured/total*100) .. "%")
		forms.settext(HealthLabel, "Health: " .. health)
		forms.settext(MissilesLabel, "Missiles: " .. (game.getMissiles() - startMissiles))
		forms.settext(SuperMissilesLabel, "Super Missiles: " .. (game.getSuperMissiles() - startSuperMissiles))
		
		-- quickfix: remove bombs & tanks label because of invalid argument exception (too little space?)
		--forms.settext(BombsLabel, "Power Bombs: " .. (game.getBombs() - startBombs))
		--forms.settext(TanksLabel, "Reserve Tanks: " .. (game.getTanks() - startTanks))
		
		forms.settext(DmgLabel, "Damage: " .. samusHitCounter)

		pool.currentFrame = pool.currentFrame + 1
	end
	emu.frameadvance();
end