library(reshape2)
library(plyr)
library(data.table)
library(ggplot2)
library(mclust)

top_dir <- "~/github/"

countries <- read.csv(paste0(top_dir,"gold_topics/countries.txt"),header=FALSE,stringsAsFactors=FALSE)
westerners <- read.csv(paste0(top_dir,"gold_topics/westerners.csv"),header=FALSE,stringsAsFactors=FALSE)
source(paste0(top_dir,"setup/data_functions.R"))
source(paste0(top_dir,"setup/plotting_functions.R"))

file <- paste0(top_dir,"/data/rev_2011-01/")
TT_net <- read.csv(paste0(file,"TT.csv"),stringsAsFactors=FALSE)
AA_net <- read.csv(paste0(file,"AA.csv"),stringsAsFactors=FALSE)
AT_net <- read.csv(paste0(file,"AT.csv"),stringsAsFactors=FALSE)
CTA_net <- read.csv(paste0(file,"ATC.csv"),stringsAsFactors=FALSE)
F1 <- read.csv(paste(file,"F1.csv",sep=""),stringsAsFactors=FALSE)
names(CTA_net) <- c("Country","Topic","Agent","Weight")

TB_net_data <- get_tb_data(F1,file)
TB_net <- melt(TB_net_data)
TB_net <- TB_net[TB_net$value != 0,]
TB_net$v2 <- sign(TB_net$value)* ceiling(log(abs(TB_net$value)))
TB_net$v2 <- ifelse(TB_net$v2==0,1,TB_net$v2)
TB_net <- TB_net[,c(2,1,4)]
names(TB_net) <- c("Belief","Topic","Weight")
TT_net <- TT_net[TT_net$Source %in% TB_net_data$Topic &
TT_net$Destination %in% TB_net_data$Topic,]

####First plot, f1_file is from get_tb_data
f1_file <- data.table(F1)
f1_file <- f1_file[f1_file$SameCount > 0,]
f1_file$Precision <- f1_file$SameCount/f1_file$TopicArticleCount
f1_file$Recall <- f1_file$SameCount/f1_file$BeliefTopicCount
f1_file$F1 <- 2*(f1_file$Precision*f1_file$Recall)/(f1_file$Precision+f1_file$Recall)
f1_file$WF1 <- log(f1_file$SameCount) * f1_file$F1
f1_file$Metric <- f1_file[,"WF1",with=F]
f1_file <- f1_file[f1_file$Topic !=f1_file$BeliefTopic,]
#######Figure 3
topic_distro_plot(c("INTERNET SOCIAL NETWORKING",
                    "FOOD PRICES"),
                    data.frame(f1_file),"WF1") 
########SAVE AT SIZE 11.5 x 8.5

###Figure 4
ggplot(TB_net_data, aes(Revolution,Violence)) + geom_point() 

######Work for Figure 5
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

z <- merge(data.frame(AT_net), TB_net_data, by.x="Destination",by.y="Topic",all.x=TRUE,all.y=FALSE)

z <- ddply(z, .(Source),summarise,rev = sum(Revolution),viol=sum(Violence))
d <- merge(z, AC_net, by.x="Source",by.y="Source")
t <- d[d$Destination=="EGYPT",]

clust <- Mclust(t[,c("rev","viol")],2:20)
f <- data.frame(agent=t$Source,group=paste(t$Destination[1],class=clust$classification))
t <- merge(t, f, by.x="Source",by.y="agent")
##Have to do this for ORA
t$viol <- t$viol*-1
egypt_agents <- AC_net[AC_net$Destination =="EGYPT","Source",with=F]$Source
egypt_aa <- AA_net[AA_net$Source %in% egypt_agents & AA_net$Destination %in% egypt_agents,]

####Go create figure 5 in ORA
write.csv(egypt_aa, "~/Desktop/aa.csv")
write.csv(t, "~/Desktop/countries.csv")







#######Topic by topic network, colored by belief

network <- TT_net
belief_data <- TB_net_data
nodes <- data.frame(id=unique(c(network$Source,network$Destination)))
nodes <- merge(nodes, belief_data, by.x="id",by.y="Topic",all.x=TRUE,all.y=FALSE)

c_palatte <- colorRampPalette(c("dark red","white","dark blue"))(nrow(nodes))
nodes <- orderBy(~-Revolution, nodes)
nodes$Rev_Color <- c_palatte
nodes <- orderBy(~-Violence, nodes)
nodes$Viol_Color <- c_palatte
write.csv(nodes,"~/Desktop/nodes_as.csv")
write.csv(network,"~/Desktop/nodes_net.csv")

