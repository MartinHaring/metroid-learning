cnfg = require "config"

local _M = {}

function _M.newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	
	return pool
end

function _M.newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.averageFitness = 0
	species.genomes = {}
	
	return species
end

function _M.sameSpecies(genome1, genome2)
	local dd = cnfg.NeatConfig.DeltaDisjoint * _M.disjoint(genome1.genes, genome2.genes)
	local dw = cnfg.NeatConfig.DeltaWeights * _M.weights(genome1.genes, genome2.genes)
	
	return dd + dw < cnfg.NeatConfig.DeltaThreshold
end

function _M.newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	
	genome.mutationRates = {}
	genome.mutationRates["connections"] = cnfg.NeatConfig.MutateConnectionsChance
	genome.mutationRates["link"] = cnfg.NeatConfig.LinkMutationChance
	genome.mutationRates["bias"] = cnfg.NeatConfig.BiasMutationChance
	genome.mutationRates["node"] = cnfg.NeatConfig.NodeMutationChance
	genome.mutationRates["enable"] = cnfg.NeatConfig.EnableMutationChance
	genome.mutationRates["disable"] = cnfg.NeatConfig.DisableMutationChance
	genome.mutationRates["step"] = cnfg.NeatConfig.StepSize
	
	return genome
end

function _M.newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

function _M.copyGene(gene)
	local gene2 = _M.newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

function _M.containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then return true end
	end
end

function _M.newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	
	return neuron
end

function _M.randomNeuron(genes, nonInput)
	local neurons = {}
	
	if not nonInput then 
		for i=1,Inputs do neurons[i] = true	end
	end
	
	for o=1,Outputs do neurons[cnfg.NeatConfig.MaxNodes + o] = true end
	
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then neurons[genes[i].into] = true end
		if (not nonInput) or genes[i].out > Inputs then neurons[genes[i].out] = true end
	end

	local count = 0
	for _,_ in pairs(neurons) do count = count + 1 	end
	
	local n = math.random(1, count)
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then return k end
	end
	
	return 0
end

function _M.pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < cnfg.NeatConfig.PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
    end
    
    return genome
end

function _M.disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then disjointGenes = disjointGenes + 1 end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then disjointGenes = disjointGenes + 1 end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

function _M.weights(genes1, genes2)
	local i2 = {}
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end

function _M.calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
    species.averageFitness = total / #species.genomes
    
    return species
end

function _M.totalAverageFitness(pool)
	local total = 0
	
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function _M.fitnessAlreadyMeasured(pool)
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end


return _M
