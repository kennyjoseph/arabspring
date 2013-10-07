require(ggplot2)
require(reshape2)
require(doBy)
require(plyr)
require(network)
require(rgexf)
require(mclust)
require(snowfall)
require(data.table)

##This dirctory
source_dir="github/"

##Same directory as networks_from_text.py
data_dir ="PATH_TO_TOP_LEVEL"
ncpu=20

source(paste0(source_dir,"setup/data_functions.R"))
source(paste0(source_dir,"setup/plotting_functions.R"))
countries <- read.csv(paste0(source_dir,"gold_topics/countries.txt"),header=FALSE,stringsAsFactors=FALSE)
westerners <- read.csv(paste0(source_dir,"gold_topics/westerners.csv"),header=FALSE,stringsAsFactors=FALSE)

sfInit(parallel=TRUE, cpus=ncpu)
sfLibrary(reshape2)
sfLibrary(doBy)
sfLibrary(plyr)
sfLibrary(mclust)
sfLibrary(ggplot2)
sfLibrary(data.table)
sfExportAll()


#sapply(list.files(paste(data_dir,"output_to_R",sep=""),full.names=TRUE),function(file){
parSapply(sfGetCluster(),list.files(paste(data_dir,"output_to_R",sep=""),full.names=TRUE),function(file){
  theme_set(theme_bw(20))
  ##READ IN DATA
  TT_net <- read.csv(paste(file,"/TT.csv",sep=""),stringsAsFactors=FALSE)
  AA_net <- read.csv(paste(file,"/AA.csv",sep=""),stringsAsFactors=FALSE)
  AT_net <- read.csv(paste(file,"/AT.csv",sep=""),stringsAsFactors=FALSE)
  CTA_net <- read.csv(paste(file,"/ATC.csv",sep=""),stringsAsFactors=FALSE)
  F1 <- read.csv(paste(file,"/F1.csv",sep=""),stringsAsFactors=FALSE)
  names(CTA_net) <- c("Country","Topic","Agent","Weight")

  ##CREATE DIRECTORY
  this_dir <-paste0(data_dir,"final_nets/",basename(file))
  dir.create(this_dir)
  cluster_output_dir <- paste(this_dir,"/cluster_output",sep="")
  dir.create(cluster_output_dir)
  
  ####GEN TB_net#####
  TB_net_data <- get_tb_data(F1,this_dir)
  TB_net <- melt(TB_net_data)
  TB_net <- TB_net[TB_net$value != 0,]
  TB_net$v2 <- sign(TB_net$value)* ceiling(log(abs(TB_net$value)))
  TB_net$v2 <- ifelse(TB_net$v2==0,1,TB_net$v2)
  TB_net <- TB_net[,c(2,1,4)]
  names(TB_net) <- c("Belief","Topic","Weight")
  
  ###ONLY USE TOPICS ASSOCIATED WITH BELEIFS
  CTA_net <- data.table(CTA_net[CTA_net$Topic %in% TB_net_data$Topic,])
  TT_net <- TT_net[TT_net$Source %in% TB_net_data$Topic & 
                  TT_net$Destination %in% TB_net_data$Topic,]
  
  AT_net <- data.table(AT_net[AT_net$Destination %in% TB_net_data$Topic,])
  AT_trans_net <- AT_net[,list(Topic=Destination[1],Weight=Weight/sum(Weight)),by="Source"]
  CTA_net <- data.table(CTA_net[CTA_net$Topic %in% TB_net_data$Topic,])
  
  ##ASSOCIATE AGENTS WITH A SINGLE COUNTRY
  atc_sub <- CTA_net[,list(weight_sum=sum(Weight)), by=c("Agent","Country")]
  atc_sub <- atc_sub[, list(Country=Country[which.max(weight_sum)],
                                Weight=max(weight_sum)),
                         by=c("Agent")]

  ###ONLY CARE ABOUT AGENTS IN THE CURRENT COUNTRIES
  AC_net <- atc_sub[atc_sub$Country %in% countries$V1,]
  names(AC_net) <- c("Source","Destination","Weight")
  AT_net <- AT_net[AT_net$Source %in% AC_net$Source,]
  AT_trans_net <- AT_trans_net[AT_trans_net$Source %in% AC_net$Source,]
  AA_net <- AA_net[AA_net$Source %in% AC_net$Source & AA_net$Destination %in% AC_net$Source,]
  
  ##Create within-group countries using model-based clustering on the belief space
  ##Westerners simply stay in their own group
  AC_net[grep(paste(westerners$V1,collapse="|"),AC_net$Source),]$Destination <-"WESTERNERS"
  groups <- create_groups(AT_net, AC_net[AC_net$Destination!="WESTERNERS",],TB_net_data,
                          dir_to_save=cluster_output_dir)
  names(AC_net) <- c("Source","Group","Weight")
  ##Create group network of agents to countries and agents to within-country groups
  AG_net <- rbind(AC_net,groups)
  
  write.csv(AA_net,paste(this_dir,"AA.csv",sep="/"),row.names=FALSE)
  write.csv(AT_net,paste(this_dir,"AT.csv",sep="/"),row.names=FALSE)
  write.csv(TB_net,paste(this_dir,"TB.csv",sep="/"),row.names=FALSE)
  write.csv(TT_net,paste(this_dir,"TT.csv",sep="/"),row.names=FALSE)
  write.csv(AG_net,paste(this_dir,"AG.csv",sep="/"),row.names=FALSE)
  write.csv(AT_trans_net,paste(this_dir,"AT_trans.csv",sep="/"),row.names=FALSE)
})
sfStop()
