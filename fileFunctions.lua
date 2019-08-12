local _M = {}

function _M.writeFile(filename, pool)
	local file = io.open(filename, "w")
    file:write(pool.generation .. "\n")
    file:write(pool.maxFitness .. "\n")
    file:write(#pool.species .. "\n")
	
    for n,species in pairs(pool.species) do
        file:write(species.topFitness .. "\n")
        file:write(species.staleness .. "\n")
        file:write(#species.genomes .. "\n")
		
        for m,genome in pairs(species.genomes) do
            file:write(genome.fitness .. "\n")
            file:write(genome.maxneuron .. "\n")
			
            for mutation,rate in pairs(genome.mutationRates) do
                file:write(mutation .. "\n")
                file:write(rate .. "\n")
            end
			file:write("done\n")
			
			file:write(#genome.genes .. "\n")
			for l,gene in pairs(genome.genes) do
				file:write(gene.into .. " ")
				file:write(gene.out .. " ")
				file:write(gene.weight .. " ")
				file:write(gene.innovation .. " ")
				
				if(gene.enabled) then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end
		end
	end
    file:close()
end

function _M.splitGeneStr(inputstr, sep)
    sep = sep or "%s"
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
	
    return t
end


return _M