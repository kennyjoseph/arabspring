
get_tb_data <- function(f1_file,top_dir,metric="WF1"){
  require(reshape)
  f1_file <- data.table(f1_file)
  f1_file <- f1_file[f1_file$SameCount > 0,]
  
  f1_file$Precision <- f1_file$SameCount/f1_file$TopicArticleCount
  f1_file$Recall <- f1_file$SameCount/f1_file$BeliefTopicCount
  f1_file$F1 <- 2*(f1_file$Precision*f1_file$Recall)/(f1_file$Precision+f1_file$Recall)
  f1_file$WF1 <- log(f1_file$SameCount) * f1_file$F1
  #f1_file$PMI <- log( (f1_file$SameCount/n_articles) / ((f1_file$TopicArticleCount/n_articles)*
  #                                                      (f1_file$BeliefTopicCount/n_articles)))
  #f1_file$WPMI<- log(f1_file$SameCount)*f1_file$PMI
  f1_file$Metric <- f1_file[,metric,with=F]
  f1_file <- f1_file[f1_file$Topic !=f1_file$BeliefTopic,]
  tb_summary <- melt(f1_file[,list(Violence=sum(Metric[Charge=="Pro"&Belief=="Violence"])-
                                     sum(Metric[Charge=="Anti"&Belief=="Violence"]),
                                   Revolution=sum(Metric[Charge=="Pro"&Belief=="Revolution"])-
                                     sum(Metric[Charge=="Anti"&Belief=="Revolution"])),
                             by="Topic"])
  names(tb_summary) <- c("Topic","Belief","Weight")
  tb_summary2 <- dcast(tb_summary, Topic~Belief, value.var=c("Weight"))
  
  dist_from_sd <- 2
  
  cutoff_revolution = with(tb_summary2,abs(mean(Revolution))+dist_from_sd*sd(Revolution))
  cutoff_violence = with(tb_summary2,(abs(mean(Violence))+dist_from_sd*sd(Violence)))
  
  tb_plot_data <- tb_summary2[abs(tb_summary2$Revolution) > cutoff_revolution |
                              abs(tb_summary2$Violence) > cutoff_violence,]  
  tb_plot_data[abs(tb_plot_data$Revolution) < cutoff_revolution, "Revolution"] <- 0
  tb_plot_data[abs(tb_plot_data$Violence) < cutoff_violence,"Violence"] <- 0
  ggsave(filename=paste0(top_dir,"/topic_distro.pdf"),
                         plot=topic_distro_plot(c("INTERNET SOCIAL NETWORKING",
                                              "FOOD PRICES",
                                              "ELECTION FRAUD"),
                                            data.frame(f1_file),"WF1"),
                         width=12,height=8)
  
  tb_plot_data
}

create_groups <- function(AT_net,AC_net,TB_net_data,dir_to_save){
  AT_net <- data.frame(AT_net)
  z <- merge(AT_net, TB_net_data, by.x="Destination",by.y="Topic",all.x=TRUE,all.y=FALSE)
  z$Violence[is.na(z$Violence)] <- 0
  z$Revolution[is.na(z$Revolution)] <- 0

  z <- ddply(z, .(Source),summarise,rev = sum(Revolution),viol=sum(Violence))
  d <- merge(z, AC_net, by.x="Source",by.y="Source")
  
  clustering_by_country <- ddply(d,.(Destination), function(t){
              clust <- Mclust(t[,c("rev","viol")],2:20) 
              save(clust, file=paste(dir_to_save,"/",t$Destination[1],".rdata",sep=""))
              f <- data.frame(agent=t$Source,group=paste(t$Destination[1],class=clust$classification))
              f
  })

  d <- merge(d,clustering_by_country[,c("agent","group")],by.x="Source",by.y="agent")
  write.csv(d,paste(dir_to_save,"/d.csv",sep=""))
  clust <- Mclust(d[,c("rev","viol")],2:20)
  d$Group_All <- paste("Overall",clust$classification)
  save(clust, file=paste(dir_to_save,"/full.rdata",sep=""))
  
  within_groups <- d[,c("Source","group","Group_All")]
  within_groups <- melt(within_groups,id=c("Source"),measure=c("group","Group_All"))[,c("Source","value")]
  names(within_groups) <- c("Source","Group")
  within_groups$Weight <- 1
  within_groups
  
}
