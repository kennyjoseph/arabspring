library(data.table)
library(lubridate)
library(reshape)
library(plyr)
library(stringr)
library(ggplot2)
library(scales)
library(zoo)
library(reshape2)

theme_set(theme_bw(20))
source_dir <- "github/"


lower_q <- .25
upper_q <- .75
params <- c("date","country","tp","group_flip_to_positive","group_flip_to_negative","agent_bias")
###Get results
######NOTE: the data is too big for github...email me if you're interested!
d <- fread(paste0(source_dir,"results_sim_final.csv"))
country_level <- d[,list(Violence=sum(Violence),Revolution=sum(Revolution)),by=params]
country_level$date <- ymd(country_level$date)
country_level$country[country_level$country == "IRAN ISLAMIC REPUBLIC OF"] <- "IRAN"
country_level$country[country_level$country == "LIBYAN ARAB JAMAHIRIYA"] <- "LIBYA"
country_level$country[country_level$country == "UNITED ARAB EMIRATES"] <- "U.A.E."

###Plot of results
cl <- melt(country_level, id=params)
cl <- dcast(cl,formula(paste(paste(params[params!="tp"],collapse="+"),"variable",sep="~")),value.var="value", function(d){d[2]-d[1]})
cl <- cl[!is.na(cl$Revolution),]
cl <- ddply(cl, .(date,country), summarise, Violence = mean(Violence), Revolution=mean(Revolution))

cl <- melt(cl, id=c("date","country"))
cl <- cl[cl$country != "QATAR" & cl$country !="WESTERNERS",]


iqr_per_month <- ddply(cl, .(date,variable), function(f){
  d <- quantile(f$value,probs=(c(lower_q,.5,upper_q)))
  data.frame(Lower=d[1],Median=d[2],Upper=d[3])
})

q <- ddply(cl, .(country,variable), function(d){
  f <- zoo(d$value, d$date)
  rev <- data.frame(rollapply(f,3, partial=TRUE,align="right",FUN=function(f){return(quantile(f,probs=c(lower_q,.5,upper_q)))}))
  
  data.frame(date=ymd(rownames(rev)),low=rev[,1],med=rev[,2],high=rev[,3])
})

blah <- merge(q,cl)
blah <- merge(blah, iqr_per_month)
v <- with(blah,blah[variable=="Violence" & blah$value > high & blah$value > Upper,])
r <- with(blah,blah[variable=="Revolution" & blah$value < low & blah$value < Lower,])
res <-merge(r[,c(1:3)],v[,c(1:3)],by=c("date","country"))
res[!duplicated(res$country),]
res <- res[!duplicated(res$country),1:2]
cl$Prediction <- F
cl[as.vector(unlist(adply(res, 1, function(f){which(cl$country == f$country & cl$date == f$date)})[,c("V1","V2")])),"Prediction"] <- T



v_plot <- ggplot(cl, aes(date,value,color=variable)) 
v_plot <- v_plot + theme(axis.text.x=element_text(angle=45,hjust=1), legend.title=element_blank()) + xlab("Month")
v_plot <- v_plot + geom_line(size=1.3,alpha=.7) + facet_wrap(~country,nrow=4,scales="free_y") 
v_plot <- v_plot + geom_linerange(data=iqr_per_month,aes(y=Median,ymin=Lower,ymax=Upper),color='black')
v_plot <- v_plot + geom_linerange(data=q, aes(y=med,ymin=low,ymax=high),color='dark grey')

v_plot <- v_plot + geom_point(data=cl[cl$Prediction,],color='black', size=5)
v_plot <- v_plot + ylab("Change in Belief (summation over agents)")
v_plot <- v_plot + scale_x_datetime(breaks=date_breaks("3 months"), 
                                    labels=date_format("%b %Y")) 
v_plot <- v_plot + scale_color_grey(start=0, end = .6)

res_out <- data.frame(country=unique(cl$country),actual="None",stringsAsFactors=F)
res_out <- merge(res_out,res,all.x=T)
res_out$date <- as.character(res_out$date)
res_out$date[is.na(res_out$date)] <- "None"
res_out$actual[res_out$country=="TUNISIA"] <- "2011-01-01"
res_out$actual[res_out$country=="EGYPT"] <- "2011-02-01"
res_out$actual[res_out$country=="LIBYA"] <- "2011-08-01"
res_out$actual[res_out$country=="YEMEN"] <- "2011-01-01"
write.csv(res_out, paste0(source_dir,"results_overthrow.csv"))


##Get protests data
protests <- read.csv(paste0(source_dir,"analysis/protest_counts.csv"),stringsAsFactors=F)
protests[is.na(protests)] <- 0
protests$date <- mdy(protests$date)
protests$QATAR <- NULL
names(protests)[names(protests)=="SAUDI.ARABIA"] <- "SAUDI ARABIA"
names(protests)[names(protests)=="U.A.E"] <- "U.A.E."
###Plot of protests
p1 <- ggplot(melt(protests[,-which(names(protests)=="QATAR")],id="date"), 
             aes(date,value)) 
p1 <- p1 + geom_point() + geom_line() + facet_wrap(~variable, nrow=2)
p1 <- p1 + theme(axis.text.x=element_text(angle=45,hjust=1)) 
p1 <- p1 + ylab("Number of Protests") + xlab("Month")

###Plot of protests w/ results
melt_protests <- melt(protests,id="date")
names(melt_protests) <- c("date","country","protests")
country_merge <- cl[cl$variable == "Violence",]
cl2 <- merge(country_merge, melt_protests, by=c("date","country"))
cl2$Prediction <- NULL
cl2 <- cl2[cl2$country %in% unique(res$country[! res$country %in% c("IRAQ","IRAN") ]),]
cl2$variable <- NULL
cl2 <- melt(cl2, id=c("date","country"))
cl2 <- ddply(cl2, .(date,country,variable), function(d){abs(d$value)/max(abs(cl2[cl2$country==d$country & cl2$variable==d$variable,]$value))})

prot_plot <- ggplot(cl2, aes(date,V1,color=variable))
prot_plot <- prot_plot + geom_point() + geom_line() + facet_wrap(~country,nrow=1)
prot_plot <- prot_plot + theme(axis.text.x=element_text(angle=45, hjust=1))
prot_plot <- prot_plot + scale_x_datetime(breaks=date_breaks("3 months"), 
                                          labels=date_format("%b %Y"),
                                          limits=c(ymd("2010-12-01"),
                                                   ymd("2011-12-01"))) 
prot_plot <- prot_plot + xlab("Month") + ylab("Percent of maximum value (per time series)")
prot_plot <- prot_plot + scale_color_discrete("",labels=c("Revolution Belief","Number of Protests"))
prot_plot
