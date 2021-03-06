library(tidyverse)
library(rentrez)
library(Biostrings)
library(muscle)
library(DECIPHER)
library(ape)
library(phangorn)
library(plyr)
#install.packages("phytools")
library(phytools)
library(seqRFLP)
#################### Load the function before using it 
searchlist <- function(x,y){      # function that can search a list of names in a variable from a dataframe and return row that contain the element from the search list. the first argument is names that you want to search from a dataframe's varible, the second argument is the dataframe's variable that you want to search. 
  n<-NULL
  nn <- NULL
  for (i in x) {
    n <- grep(i,y)   #return the row number 
    print(i)    #print the name of element from the list
    print(n)    # print which row contain that element
    nn <- c(nn,n)  #return a vector of row number which corresponded to the input search list
  }
  return(nn)
}
#########################

#Biological question: Does the sister species of Anthophora live in the same geological place
#The bee genus Anthophora is one of the largest in the family Apidae, with over 450 species worldwide in 14 different subgenera.
Anthophora_table <- read_tsv("http://www.boldsystems.org/index.php/API_Public/combined?taxon=Anthophora&format=tsv")

Anthophora_sub <- Anthophora_table %>%
  filter(!is.na(lat) & !is.na(lon)) %>%  #filter out the sample without geological data and species_names
  filter(!is.na(species_name))

View(Anthophora_sub)

Anthophora_small <- data.frame(Anthophora_sub$species_name, Anthophora_sub$processid, 
                               Anthophora_sub$lon,Anthophora_sub$lat,Anthophora_sub$nucleotides) # subset the data with varibles: species name, processid, lontitude, latitude, nucleotide) 

Anthophora_small <- Anthophora_small %>%
  filter(!is.na(Anthophora_sub.processid) & !is.na(Anthophora_sub.nucleotides)) # filter out the samples without bin_uri and sequences

names(Anthophora_small) <- c("species_names", "process_id", "lon", "lat", "nucleotides") #assign names

Anthophora_small <- Anthophora_small %>% #arrange data as species names 
  arrange(species_names)

unique_list <- unique(Anthophora_small$species_names) # find the unique species names
searchlist(unique_list,Anthophora_small$species_names) # load the function searchlist (at top of the script) and read the return values from console which are row number for each specie

Anthophora_small <- Anthophora_small %>% # arrange data by species names and the lontitude, also it will put the specimen with similar geological information together (lontidute in ascend order)
  arrange(species_names,lon) #help me filter the repatitive data

#next step is filter out the sample with very similar geological information 
s_lon <- round(Anthophora_small$lon)  #round the lontitude data to integer for selection
Anthophora_small_x <- Anthophora_small   #create a new copy of Anthophora_small for selection
Anthophora_small_x$lon <- s_lon      #change the lontitude data to rounded data
Anthophora_small_xx <- ddply(Anthophora_small_x,~lon) %>%    #ddply function is from plyr package to splict dataframe according to lontitdue 
  group_by(species_names,lon) %>%    #randomly select a lontitude number from lontitude values from each species name
  sample_n(1)

selectlist <- searchlist(Anthophora_small_xx$process_id,Anthophora_small$process_id) #each sample has a unique process id; use process id to retrive actual lontitude data 
Anthophora_fi <- Anthophora_small[selectlist,] #retrieved data
rownames(Anthophora_fi) <- c(1:78) #rename the row name to make dataframe look nice
# so Anthophora_fi is the subset data with randomly selected according to their geological locations and species.
# the data size is downsized to 78

Anthophora_seq <- data.frame(Anthophora_fi$species_names,Anthophora_fi$nucleotides) #extract the species name and nucleotides into new dataframe
dataframe2fas(Anthophora_seq, file = "Anho.fasta") #convert seqences to fastafile by dataframe2fas function from seqRFLP package to working directory 
#the output fasta file is used for blast for quailty check, the quality is acceptable

Anthophora_set <- readDNAStringSet("Anho.fasta", format = "fasta") #load genterated fasta file to string set format

Anthophora_msa <- DNAStringSet(muscle::muscle(Anthophora_set, maxiters = 5)) # perform multiple sequence alignment by using muscle algroithm
Anthophora_msa

Anthophora_bin <- as.DNAbin(Anthophora_msa) #transfer to DNAbin format 
dis_Antho<-dist.dna(Anthophora_bin, model = "TN93", as.matrix = T, pairwise.deletion = F) #calculate distance matrix by using TN93 model
phylo_Antho<-bionj(dis_Antho) #consturct tree by improved version of neighbour joining algorithm from ape package
parsimony(phylo_Antho,as.phyDat(Anthophora_bin)) #use Maximum parsimony phylogenies to reconstruct the phylogeny tree
tree<-optim.parsimony(phylo_Antho,as.phyDat(Anthophora_bin))
plot(tree,cex =0.6) # simple visualisation of tree
#There are three main clusters formed in phylogenetic tree, but Maximum parsimony phylogenies method tend to increase the divergence.


#next step is matching geological data with phylogenetic tree
#I use phytools package to create a phylogenetic tree along with geological information 
#I try to use tree produced from Maximum parsimony phylogenies to produce the map, but it failed. So I use UPGMA clustering which is used in the function demonstration to build the tree rather than neighour joining.

tree_1<-untangle(upgma(dis_Antho),"read.tree")#upgma clustering from phangorn package
Antho_lon_lat <- as.matrix(data.frame(Anthophora_fi$lat, Anthophora_fi$lon)) # construct coordinates matrix for map building
row.names(Antho_lon_lat) <- tree_1$tip.label  #row names should be the same as tree$tip.label

 
#the tree is bit different from the tree constructed by Maximum parsimony phylogenies and it group few species into the wrong group
mapplot <- phylo.to.map(tree_1, Antho_lon_lat,plot=F)

plot(mapplot,fsize=0.01,asp=1.2,type="phylogram",ftype="i") # the phylogenetic tree plot along with geological information

#Even though, the clustering is bit sketchy, but it is very clear that every sister species from each group are point to the similar area. Although I can not conclude they are in the same place, at least they look very close in the word map.
#And another noteworthy thing is that the majority of the species are collect in central Europe, and rest of them were collected from North America. Geologically speaking, The sample collection lack diversity 
