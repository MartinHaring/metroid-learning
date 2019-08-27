cnfg = require "config"
game = require "game"
mf = require "mathFunctions"
ff = require "fileFunctions"
nf = require "neatFunctions"

Inputs = cnfg.InputSize+1
Outputs = #cnfg.ButtonNames

form = forms.newform(450, 650, "Metroid-Learning")
netPicture = forms.pictureBox(form, 5, 300, 420, 300)

event.onexit(onExit)

function newInnovation() 
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

function linkMutate(genome, forceBias)
	local neuron1 = nf.randomNeuron(genome.genes, false)
	local neuron2 = nf.randomNeuron(genome.genes, true)
	local newLink = nf.newGene()
	
	-- if both neurons are input nodes, stop
	if neuron1 <= Inputs and neuron2 <= Inputs then return end
	
	-- make sure neuron2 is higher than neuron1
	if neuron2 <= Inputs then
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	
	if forceBias then newLink.into = Inputs	end
	if nf.containsLink(genome.genes, newLink) then return end
	
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
	if #genome.genes == 0 then return end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then return end
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

function enableDisableMutate(genome, enable)
	local candidates = {}
	
	for _,gene in pairs(genome.genes) do 
		if gene.enabled == not enable then table.insert(candidates, gene) end 
	end
	
	if #candidates == 0 then return end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function submutate(p, g, option)
	if p > 0 then
		if option == 0 then
			if math.random() < p then linkMutate(g, false)	end
		elseif option == 1 then
			if math.random() < p then linkMutate(g, true) end
		elseif option == 2 then
			if math.random() < p then nodeMutate(g) end
		elseif option == 3 then
			if math.random() < p then enableDisableMutate(g, true) end
		elseif option == 4 then
			if math.random() < p then enableDisableMutate(g, false) end
		end
		submutate(p-1, option)
	end
end

function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then genome.mutationRates[mutation] = 0.95*rate else genome.mutationRates[mutation] = 1.05263*rate end
	end

	if math.random() < genome.mutationRates["connections"] then genome = nf.pointMutate(genome) end
	
	submutate(genome.mutationRates["link"], genome, 0)
	submutate(genome.mutationRates["bias"], genome, 1)
	submutate(genome.mutationRates["node"], genome, 2)
	submutate(genome.mutationRates["enable"], genome, 3)
	submutate(genome.mutationRates["disable"], genome, 4)
end

function basicGenome()
	local genome = nf.newGenome()

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
	
	for i=1,Inputs do network.neurons[i] = nf.newNeuron() end
	for o=1,Outputs do network.neurons[cnfg.NeatConfig.MaxNodes+o] = nf.newNeuron() end
	
	table.sort(genome.genes, function (a,b) return (a.out < b.out) end)
	
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
	--	console.writeline("Incorrect number of neural network inputs.")
		return {}
	end

	for i=1,Inputs do network.neurons[i].value = inputs[i] * inputDeltas[i] end
	
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
		if network.neurons[cnfg.NeatConfig.MaxNodes+o].value > 0 then outputs[button] = true else outputs[button] = false end
	end
	
	return outputs
end

function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	local inputDeltas = {}
	inputs, inputDeltas = game.getInputs()
	controller = evaluateNetwork(genome.network, inputs, inputDeltas)
	joypad.set(controller)
end

function initializeRun()
	savestate.load(cnfg.StateDir .. cnfg.Filename);
	
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
	samusXprev = nil
	samusYprev = nil

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

function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b) return (a.fitness > b.fitness) end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then remaining = 1 end
		
		while #species.genomes > remaining do table.remove(species.genomes) end
	end
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		table.sort(species.genomes, function (a,b) return (a.fitness > b.fitness) end)
		
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
		if breed >= 1 then 	table.insert(survived, species) end
	end

	pool.species = survived
end

function rankSpecies()
	local global = {}
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do table.insert(global, species.genomes[g]) end
	end
	
	table.sort(global, function (a,b) return (a.fitness < b.fitness) end)
	
	for g=1,#global do global[g].globalRank = g end
end

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
	for g=1,#genome.genes do table.insert(genome2.genes, nf.copyGene(genome.genes[g])) end
	
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
	ff.writeFile(cnfg.PoolDir .. cnfg.Filename .. ".gen" .. pool.generation .. ".pool", pool)
end

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
	for mutation,rate in pairs(g1.mutationRates) do child.mutationRates[mutation] = rate end
	
	return child
end

--##########################################################
-- Display
--##########################################################

function displayGenome(genome)
	forms.clear(netPicture, 0xFFDDDDDD)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	
	for dy=-cnfg.BoxRadius,cnfg.BoxRadius do
		for dx=-cnfg.BoxRadius,cnfg.BoxRadius do
			cell = {}
			cell.x = 50 + 5 * dx
			cell.y = 70 + 5 * dy
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
		cell.x = 320
		cell.y = 30 + 11 * o
		cell.value = network.neurons[cnfg.NeatConfig.MaxNodes + o].value
		cells[cnfg.NeatConfig.MaxNodes + o] = cell
		
		local color
		if cell.value > 0 then color = 0xFF0000FF else color = 0xFF000000 end
		
		forms.drawText(netPicture, 330, 22 + 11 * o, cnfg.ButtonNames[o], color, 9)
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
					c1.x = 0.75 * c1.x + 0.25 * c2.x
					
					if c1.x >= c2.x then c1.x = c1.x - 40 end
					if c1.x < 90 then c1.x = 90 end
					if c1.x > 220 then c1.x = 220 end
					
					c1.y = 0.75 * c1.y + 0.25 * c2.y
				end
				
				if gene.out > Inputs and gene.out <= cnfg.NeatConfig.MaxNodes then
					c2.x = 0.25 * c1.x + 0.75 * c2.x
					
					if c1.x >= c2.x then c2.x = c2.x + 40 end
					if c2.x < 90 then c2.x = 90 end
					if c2.x > 220 then c2.x = 220 end
					
					c2.y = 0.25 * c1.y + 0.75 * c2.y
				end
			end
		end
	end
	
	forms.drawBox(netPicture, 50 - cnfg.BoxRadius * 5 - 3, 70 - cnfg.BoxRadius * 5 - 3, 50 + cnfg.BoxRadius * 5 + 2, 70 + cnfg.BoxRadius * 5 + 2, 0xFF000000, 0x80808080)
	
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value + 1) / 2 * 256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			
			local opacity = 0xFF000000
			if cell.value == 0 then opacity = 0x50000000 end
			
			color = opacity + color * 0x10000 + color * 0x100 + color
			forms.drawBox(netPicture, cell.x - 2, cell.y - 2, cell.x + 2, cell.y + 2, opacity, color)
		end
	end
	
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			
			local opacity = 0xA0000000
			if c1.value == 0 then opacity = 0x20000000 end
			
			local color = 0x80 - math.floor(math.abs(mf.sigmoid(gene.weight)) * 0x80)
			if gene.weight > 0 then color = opacity + 0x8000 + 0x10000 * color else color = opacity + 0x800000 + 0x100 * color end
			
			forms.drawLine(netPicture, c1.x + 1, c1.y, c2.x - 3, c2.y, color)
		end
	end
	
	forms.drawBox(netPicture, 49, 71, 51, 78, 0x00000000, 0x80FF0000)
	
	local pos = 160
	for mutation,rate in pairs(genome.mutationRates) do
		forms.drawText(netPicture, 40, pos, mutation .. ": " .. rate, 0xFF000000, 10)
		pos = pos + 15
	end
	
	forms.refresh(netPicture)
end

--##########################################################
-- File Management
--##########################################################

ff.writeFile(cnfg.PoolDir .. "temp.pool", pool)

function loadFile(filename)
	local file = io.open(filename, "r")
	if file == nil then return end
	print("Loading pool from " .. filename)
    pool = nf.newPool()
    pool.generation = file:read("*number")
    pool.maxFitness = file:read("*number")
    forms.settext(maxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	
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
				
                if enabled == 0 then gene.enabled = false else gene.enabled = true end
				
				table.insert(genome.genes, gene)
            end
        end
    end
    file:close()   
    
    while nf.fitnessAlreadyMeasured(pool) do nextGenome() end
	
    initializeRun()
    pool.currentFrame = pool.currentFrame + 1
	print("Pool loaded.")
end

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
	local filename = cnfg.PoolDir .. forms.gettext(saveLoadFile) .. ".gen" .. pool.generation .. ".pool"
	print("Saved: " .. filename)
	ff.writeFile(filename, pool)
end

function loadPool()
	filename = forms.openfile()
	loadFile(filename)
	forms.settext(saveLoadFile, string.sub(filename, string.len(cnfg.PoolDir) + 1, (string.len(".gen" .. pool.generation .. ".pool") + 1) * -1))
end

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
	forms.settext(maxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
	return
end

function onExit() forms.destroy(form) end

generationLabel = forms.label(form, "Generation: " .. pool.generation, 5, 25)
speciesLabel = forms.label(form, "Species: " .. pool.currentSpecies, 110, 25)
genomeLabel = forms.label(form, "Genome: " .. pool.currentGenome, 230, 25)
measuredLabel = forms.label(form, "Measured: " .. "", 330, 25)

fitnessLabel = forms.label(form, "Fitness: " .. "", 5, 50)
maxLabel = forms.label(form, "Max: " .. "", 110, 50)

healthLabel = forms.label(form, "Health: " .. "", 5, 95)
tanksLabel = forms.label(form, "Energy Tanks: " .. "", 110, 95)
dmgLabel = forms.label(form, "Damage: " .. "", 230, 95)

missilesLabel = forms.label(form, "Missiles: " .. "", 5, 120)
superMissilesLabel = forms.label(form, "Super Missiles: " .. "", 110, 120)
bombsLabel = forms.label(form, "Power Bombs: " .. "", 230, 120)

saveButton = forms.button(form, "Save", savePool, 15, 170)
loadButton = forms.button(form, "Load", loadPool, 95, 170)
startButton = forms.button(form, "Start", flipState, 175, 170)
if cnfg.Running == true then forms.settext(startButton, "Stop") end
restartButton = forms.button(form, "Restart", initializePool, 255, 170)
playTopButton = forms.button(form, "Play Top", playTop, 335, 170)

saveLoadLabel = forms.label(form, "Save as:", 15, 210)
saveLoadFile = forms.textbox(form, cnfg.Filename, 170, 25, nil, 15, 233)


--##########################################################
-- Reinforcement Learning
--##########################################################

while true do	
	if cnfg.Running == true then
		local species = pool.species[pool.currentSpecies]
		local genome = species.genomes[pool.currentGenome]
		
		displayGenome(genome)
		if pool.currentFrame % 5 == 0 then evaluateCurrent() end
		joypad.set(controller)

		-- Algorithm
		game.getPositions()
		if samusXprev == nil then samusXprev = samusX end
		if samusYprev == nil then samusYprev = samusY end

		if samusX ~= samusXprev or samusY ~= samusYprev then
			diffX = samusX - samusXprev
			if diffX < 0 then diffX = diffX * -1 end

			diffY = samusY - samusYprev
			if diffY < 0 then diffY = diffY * -1 end

			explorationFitness = explorationFitness + diffX + diffY
			timeout = cnfg.NeatConfig.TimeoutConstant
		else
			timeout = timeout - 1
		end
		samusXprev = samusX
		samusYprev = samusY

		local hitTimer = game.getSamusHitTimer()
		if checkSamusCollision == true then
			if hitTimer > 0 then
				samusHitCounter = samusHitCounter + 1
				console.writeline("Samus took damage, hit counter: " .. samusHitCounter)
				checkSamusCollision = false
			end
		end
		if hitTimer == 0 then checkSamusCollision = true end
		
		if pool.currentFrame > 300  and pool.currentFrame % (cnfg.NeatConfig.TimeoutConstant * 10) == 0 then
			if samusX == samusXprev then 
				explorationFitness = explorationFitness - 10000
				console.writeline("Cheating detected, abort.")
				timeout = -500 
			end
		end

		local timeoutBonus = pool.currentFrame / 4
		if timeout + timeoutBonus <= 0 then
			local missiles = game.getMissiles() - startMissiles
			local superMissiles = game.getSuperMissiles() - startSuperMissiles
			local bombs = game.getBombs() - startBombs
			local tanks = game.getTanks() - startTanks
			
			local pickupFitness = (missiles * 10) + (superMissiles * 100) + (bombs * 100) + (tanks * 1000)
			if (missiles + superMissiles + bombs + tanks) > 0 then 
				console.writeline("Collected Pickups added " .. pickupFitness .. " fitness")
			end
			
			local hitPenalty = samusHitCounter * 100
		
			local fitness = explorationFitness + pickupFitness - hitPenalty

			health = game.getHealth()
			if startHealth < health then
				local extraHealthBonus = (health - startHealth) * 1000
				fitness = fitness + extraHealthBonus
				console.writeline("Extra Health added " .. extraHealthBonus .. " fitness")
			end

			if explorationFitness > 20000 then
				fitness = fitness + 10000
				console.writeline("!!!!!!Reached Ridley!!!!!!!")
			end

			if fitness == 0 then fitness = -1 end
			genome.fitness = fitness
			
			if fitness > pool.maxFitness then
				pool.maxFitness = fitness
				ff.writeFile(cnfg.PoolDir .. cnfg.Filename .. ".gen" .. pool.generation .. ".pool", pool)
			end
			
			console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
			pool.currentSpecies = 1
			pool.currentGenome = 1
			while nf.fitnessAlreadyMeasured(pool) do nextGenome() end

			initializeRun()
		end

		local measured = 0
		local total = 0
		for _,species in pairs(pool.species) do
			for _,genome in pairs(species.genomes) do
				total = total + 1
				if genome.fitness ~= 0 then	measured = measured + 1 end
			end
		end
		
		gui.drawEllipse(game.screenX-95, game.screenY-85, 200, 200, 0xAA000000) 
		forms.settext(generationLabel, "Generation: " .. pool.generation)
		forms.settext(speciesLabel, "Species: " .. pool.currentSpecies)
		forms.settext(genomeLabel, "Genome: " .. pool.currentGenome)
		forms.settext(measuredLabel, "Measured: " .. math.floor(measured / total * 100) .. "%")
		forms.settext(fitnessLabel, "Fitness: " .. math.floor(explorationFitness - (pool.currentFrame) / 2 - (timeout + timeoutBonus) * 2 / 3))
		forms.settext(maxLabel, "Max: " .. math.floor(pool.maxFitness))
		forms.settext(healthLabel, "Health: " .. health)
		forms.settext(tanksLabel, "Energy Tanks: " .. (game.getTanks() - startTanks))
		forms.settext(dmgLabel, "Damage: " .. samusHitCounter)
		forms.settext(missilesLabel, "Missiles: " .. (game.getMissiles() - startMissiles))
		forms.settext(superMissilesLabel, "Super Missiles: " .. (game.getSuperMissiles() - startSuperMissiles))
		forms.settext(bombsLabel, "Power Bombs: " .. (game.getBombs() - startBombs))

		pool.currentFrame = pool.currentFrame + 1
	end
	emu.frameadvance();
end
