get_names_data <- function(file_name){
  names <- read.csv(file_name)
  names$Term <- as.character(names$Term)
  names <- orderBy(~Mapping,names)
  names
}


get_data <- function(file_name,col_names, 
                     nAgents,aCountry,
                     aNames,timeper){
  data <- read.csv(file_name,header=FALSE)
  data <- data.table(data)
  n_data <- names(data)
  for(i in 1:length(n_data)){
    setnames(data,n_data[i],col_names[i])
  }
  data$tp <- rep(timeper,each=nAgents)
  data$agent <- rep(aNames$Term,length(timeper))
  data$country <- rep(aCountry$Group, length(timeper))
  data
}


 
