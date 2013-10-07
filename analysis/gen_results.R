require(data.table)
require(ggplot2)
require(plyr)
require(doBy)
require(reshape)
require(lubridate)
require(stringr)
require(snowfall)
require(data.table)
source_dir = "github/"

sfInit(parallel=TRUE,cpus=10)
sfSource(paste0(source_dir,"analysis/results_functions.R"))
sfExport("source_dir")
sfLibrary(data.table)
sfLibrary(ggplot2)
sfLibrary(plyr)
sfLibrary(doBy)
sfLibrary(reshape)
sfLibrary(lubridate)
sfLibrary(stringr)
####Agent Country Replication Date TP RevB ViolB Rev+K Rev-K Viol+K Viol-K


parSapply(sfGetCluster(),Sys.glob("final_nets/rev_*/30*"), function(this_dir){
  print(this_dir)
  con <- file(paste0(this_dir,"/out.txt"))
  z <- readLines(con)
  if(sum(unlist(sapply(z,function(l){grep("End time:",l)}))) ==0){
    return;
  }
  
  tps <- c(2,30)
  #get replication num, date, from param
  params <- read.csv(paste0(this_dir,"/params.csv"),stringsAsFactors=FALSE)
  num_agents <- as.numeric(params[params$parameter=="Agent Count","value"])
  

  date <- ymd(paste0(params[params$parameter=="Date","value"],"-01"))

  ##Agent-Country
  groups <- read.csv(paste0(this_dir,"/../AG.csv"))
  countries <- read.csv(paste0(source_dir,"gold_topics/countries.txt"),header=FALSE,stringsAsFactors=F)
  countries <- rbind(countries,data.frame(V1="WESTERNERS"))
  agent_countries <- groups[groups$Group %in% countries$V1,]
  

  ##Agent-Belief (has country as well)
  agent_names <- get_names_data(paste0(this_dir,"/../agent_map.csv"))
  belief_names <- get_names_data(paste0(this_dir,"/../beliefs_map.csv"))
  beliefs <- get_data(paste0(this_dir,"/belief_output.csv"),
                      belief_names$Term,
                      num_agents,agent_countries,
                      agent_names,tps)

  knowledge_names <- get_names_data(paste0(this_dir,"/../knowledge_map.csv"))
  kn <- ddply(knowledge_names,.(Term),function(l){data.frame(v=1:nrow(l))})
  knowledge_names <- orderBy(~Term,knowledge_names)
  kn<- orderBy(~Term,kn)
  knowledge_names$index <- kn$v
  knowledge_names <- orderBy(~Mapping, knowledge_names)
  
  ##Agent-KnowledgeBelief
  ##Get Agent-Knowledge
  knowledge <- get_data(paste0(this_dir,"/knowledge_output.csv"),
                        paste(knowledge_names$Term,knowledge_names$index),
                        num_agents,agent_countries,
                        agent_names,tps)
  ##Get Knowledge-Belief
  tb <- read.csv(paste0(this_dir,"/../TB_indexed.csv"))
  tb$target <- tb$target+1
  tb <- merge(tb, belief_names,by.x="source",by.y="Mapping")
  tb$PN <- ifelse(tb$weight >0, "Pos","Neg")
  tb$Belief <- paste(tb$Term,tb$PN,sep="_")
  indicies <- tapply(tb$target,tb$Belief, unique)
  ###***####
  length(intersect(indicies[[2]],indicies[[4]])) 

  ##Sum agent knowledge to beliefs
  ab_mat <- matrix(data=0,nrow=nrow(knowledge),ncol=length(indicies))
  for(i in 1:(length(indicies))){
    kb_set <- indicies[[i]]
    z <-  apply(knowledge,1,function(l){sum(as.numeric(l[kb_set]))})
    ab_mat[,i] <- z
  }
  ab_by_k <- data.frame(ab_mat)
  names(ab_by_k) <- names(indicies)
  ab_by_k$agent <- knowledge$agent
  ab_by_k$tp <- knowledge$tp
  
  gfp <- params[params$parameter=="group_flip_to_positive","value"]
  gfn <- params[params$parameter=="group_flip_to_negative","value"]
  ab <-params[params$parameter=="agent_bias","value"]
  out <- cbind(beliefs,ab_by_k[,1:4])
  out$replication <- 1
  out$date <- date
  out$group_flip_to_positive <- gfp
  out$group_flip_to_negative <- gfn
  out$agent_bias <- ab

  out[, RevolutionByKnowledge:= Revolution_Pos-Revolution_Neg]
  out[, ViolenceByKnowledge:= Violence_Pos-Violence_Neg]
  write.csv(out, paste0(this_dir,"/",date,paste(gfp,gfn,ab,"agg_out.csv",sep="_")))
  print("DONE")
})


files = Sys.glob("final_nets/rev*/30_*/*_agg_out.csv")
l <- vector("list",length(files))
for(i in 1:length(files) ){
  l[[i]] <- fread(files[i])
}
dt <- rbindlist(l)
write.csv(dt, "github/results_sim_final.csv")




