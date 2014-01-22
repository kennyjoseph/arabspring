topic_distro_plot <- function(terms,data,metric="F1"){
  
  p <- ggplot(data[data$Topic%in%terms,], aes_string(x="BeliefTopic",y=metric,fill="Topic")) + geom_bar(stat="identity",position='dodge')
  p <- p + facet_wrap(Charge~Belief,nrow=2, scales="free_x") + scale_y_continuous(limits=c(0,max(data[data$Topic%in%terms,metric]))) 
  p <- p + theme(axis.text.x=element_text(angle=60,size=12,hjust=1))
  p + ylab("") + xlab("") + scale_fill_grey(start = 0, end = .6, labels=c("FOOD PRICES", "INTERNET SOCIAL\nNETWORKING"))
}



plot_topic_network <- function(network,belief_data, is_revolution,min_weight=50, max_edge_size=3){ 
  nodes <- belief_data
  nodes$id <- belief_data$Topic
  nodes$names <- belief_data$Topic
  if(is_revolution){
    nodes$R <- ifelse(nodes$Revolution > 0, 128*nodes$Revolution/max(nodes$Revolution)+128,0)
    nodes$B <- ifelse(nodes$Revolution < 0, 128*abs(nodes$Revolution/min(nodes$Revolution))+128,0)
  } else{ 
    nodes$R <- ifelse(nodes$Violence > 0, 128*nodes$Violence/max(nodes$Violence)+128,0)
    nodes$B <- ifelse(nodes$Violence < 0, 128*abs(nodes$Violence/min(nodes$Violence))+128,0)
  } 
  names(network) <- c("target","source","weight")
  network <- network[network$weight > min_weight,]
  edgethicks <- (network$weight / max(network$weight))* max_edge_size
  
  nodecolors <- data.frame(r = nodes$R,
                           g = ifelse(nodes$R==0 &nodes$B==0,128,0),
                           b = nodes$B,
                           a = rep(1,nrow(nodes)))
  graph <- write.gexf(nodes=nodes[,c("id","names")],
                      edges=network[,c(1:2)],
                      nodesVizAtt=list(
                        color=nodecolors
                      ),
                      edgesVizAtt=list(
                        thickness= edgethicks
                      ),
                      nodesAtt=nodes[,c("Revolution","Violence")]                    
  )
  if(is_revolution){
    write(graph$graph, "/Users/kjoseph/Dropbox/Public/revolution.gexf")
  } else{
    write(graph$graph, "/Users/kjoseph/Dropbox/Public/violence.gexf")
  }
}

plot_agent_topic_network <- function(network, belief_data, is_revolution, min_weight=1,name="egypt_topic"){
  nodes <- data.frame(id=unique(c(network$Source,network$Destination)),
                      names=unique(c(network$Source,network$Destination)))
  
  nodes$G <- ifelse(nodes$id %in% network$Source, 255, 0)
  
  print("here")
  nodes <- merge(nodes, belief_data, by.x="id",by.y="Topic",all.x=TRUE,all.y=FALSE)
  print("here2")
  nodes$Revolution[is.na(nodes$Revolution)] <- 0
  nodes$Violence[is.na(nodes$Violence)] <- 0
  if(is_revolution){
    nodes$R <- ifelse(nodes$Revolution > 0, 128*nodes$Revolution/max(nodes$Revolution)+128,0)
    nodes$B <- ifelse(nodes$Revolution < 0, 128*abs(nodes$Revolution/min(nodes$Revolution))+128,0)
  } else{ 
    nodes$R <- ifelse(nodes$Violence > 0, 128*nodes$Violence/max(nodes$Violence)+128,0)
    nodes$B <- ifelse(nodes$Violence < 0, 128*abs(nodes$Violence/min(nodes$Violence))+128,0)
  }
  names(network) <- c("source","target","weight")
  print(nodes)
  network <- network[network$weight >= min_weight,]
  edgethicks <- (network$weight / max(network$weight))* max_edge_size
  
  nodecolors <- data.frame(r = nodes$R,
                           g = 0,
                           b = nodes$B,
                           a =  ifelse(nodes$id %in% network[,"source"], .5, 1))
  graph <- write.gexf(nodes=nodes[,c("id","names")],
                      edges=network[,c(2,1)],
                      nodesVizAtt=list(
                        color=nodecolors
                      ),
                      edgesVizAtt=list(
                        thickness= edgethicks
                      )                 
  )
  if(is_revolution){
    write(graph$graph, paste("/Users/kjoseph/Dropbox/Public/",name,"_revolution.gexf",sep=""))
  } else{
    write(graph$graph, paste("/Users/kjoseph/Dropbox/Public/",name,"_violence.gexf",sep=""))
  }
}

plots <- function(){
  p <- ggplot(z, aes(Revolution,Violence))
  p <- p + scale_x_continuous(limits=c(-.3,.3)) + scale_y_continuous(limits=c(-.3,.3)) 
  p <- p + geom_rect(aes(xmin=-.05,ymin=-.05,xmax=.05,ymax=.05,fill='red'))
  p <- p + geom_point()+scale_fill_discrete(guide='none');p
  
  ggplot(z, aes(rev,viol,label=Source)) + geom_point() + geom_text() + scale_x_continuous(limits=c(0,15)) + scale_y_continuous(limits=c(0,50))
  ggplot(z, aes(rev,viol,label=Source)) + geom_point() + geom_text() + scale_x_continuous(limits=c(-200,0)) + scale_y_continuous(limits=c(-50,0))
  ggplot(z, aes(rev,viol,label=Source)) + geom_point()  + geom_hline(y=0,color='red') + geom_vline(x=0,color='red')
  
  plot_topic_network(TT_net,TB_net_data,TRUE,min_weight=25)
  plot_topic_network(TT_net,TB_net_data,FALSE,min_weight=25)
  
  #ggplot(d, aes(rev,viol,label=Source)) + geom_point()  + geom_hline(y=0,color='red') + geom_vline(x=0,color='red') + facet_wrap(~Country)
  
  
}
