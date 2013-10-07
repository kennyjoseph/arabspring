#####REQUIRES A STANFORD NER SERVER ON PORT 9124

#Index item format
#	DOCUMENT	2010-07-01_1	GEOGRAPHIC	DUBAI, UNITED ARAB EMIRATES	0.93	DOCUMENT-GEOGRAPHIC


from glob import glob
import itertools,os,ner,re,pp
from collections import defaultdict
import editdist
import cPickle as pickle
import multiprocessing


MIN_NAME_LENGTH = 2
MAX_NAME_LENGTH = 5
TERMS_TO_REMOVE= [r"^abd ",  r"^/o ", r"^mr\.{0,1} ", r"^mrs\.{0,1} ", r"^ms\.{0,1} ",
				 r"^dr\.{0,1} ",r"^[a-z]\.{0,1} ",r" [a-z]\. "]

def merge_into(shorter_term,longer_term):
	MIN_EDIT_DISTANCE = 3
	MIN_WORD_EDIT_DISTANCE = .75
	##simple comparison	
	if (longer_term.endswith(" "+shorter_term) or
		longer_term.startswith(shorter_term+" ")):
		return True
	
	edit_distance = editdist.distance(shorter_term.replace(" ","_").replace("-","_"),
									  longer_term.replace(" ","_").replace("-","_"))
	##String edit distance
	if edit_distance <= MIN_EDIT_DISTANCE:
		return True
	
	return False
	##"Word" edit distance
	count = 0
	for term in shorter_term.split(" "):
		if term in longer_term:
			count += 1
	return (count/float(len(longer_term.split(" ")))) >= MIN_WORD_EDIT_DISTANCE
	
def get_max_country(country_set):
	max_val = -1
	top_country = ""
	for country in country_set:
		if country[1] > max_val:
			top_country = country
			max_val = country[1]
			
	return [top_country]

def get_max_words(name_set):
	max_val = -1
	top_name = ""
	for name in name_set:
		if len(name.split(" ")) > max_val:
			top_name = name
			max_val = len(name.split(" "))
			
	return top_name
	
def gen_month_network(output_dir, articles_by_month):
	import itertools,os
	from collections import defaultdict
	###De-duplicate agents
	all_people = []
	person_trans_dict_tmp = defaultdict(set)
	for day_network in articles_by_month:
		for article in day_network.values():
			all_people += [person[0] for person in article[2]]
	
	for person in all_people:
		person_trans_dict_tmp[person].add(person)
		
	for p1,p2 in itertools.combinations(all_people,2):
		if len(p1) < len(p2):
			if merge_into(p1,p2):
				person_trans_dict_tmp[p1].add(p2)
		else: 
			if merge_into(p2,p1):
				person_trans_dict_tmp[p2].add(p1)
				
	person_trans_dict = dict()
	for k,v in person_trans_dict_tmp.iteritems():
		person_trans_dict[k] = get_max_words(v)
			
	cc_net = defaultdict(float)
	tt_net = defaultdict(float)	
	aa_net = defaultdict(float)
	single_nets = [cc_net,tt_net,aa_net]
	single_net_fnames = ["CC.csv","TT.csv","AA.csv"]

	at_net = defaultdict(float)
	ac_net = defaultdict(float)
	tc_net = defaultdict(float)
	two_mode = [at_net,ac_net,tc_net]
	two_mode_fnames=["AT.csv","AC.csv","TC.csv"]
	
	atc_net = defaultdict(float)
	
	all_nets = single_nets + two_mode + [aa_net]
	all_net_fnames = single_net_fnames + two_mode_fnames + ["AA.csv"]
	
	
	for day_network in articles_by_month:
		for article in day_network.values():
			##ONE MODE
			article[0] = get_max_country(article[0])
			article[2] = [[person_trans_dict[p[0]],p[1]] for p in article[2]]
			for i in range(0,len(single_net_fnames)):
				for combo in itertools.combinations(article[i],2):
					single_nets[i][(combo[0][0],combo[1][0])] += 1
			
			##AA NET SEPARATE FOR DEDUPLICATION
			for combo in itertools.combinations(article[2],2):
				person_one= combo[0][0]
				person_two= combo[1][0]
				aa_net[(person_one,person_two)] += 1
			
			##TWO MODE
			j = 0
			for i in [[2,1],[2,0],[1,0]]:	
				for combo in list(itertools.product(*[article[i[0]],article[i[1]]])):
					two_mode[j][(combo[0][0],combo[1][0])] += 1
				j+=1
			
			##THREE MODE
			for combo in list(itertools.product(*article)):
					atc_net[(combo[0][0],combo[1][0],combo[2][0])] += 1	
				
	output_dir += "/"
	for i in range(0,len(all_net_fnames)):
		out_fil = open(output_dir+all_net_fnames[i],"w")
		out_fil.write("Source,Destination,Weight\n")
		for k,v in all_nets[i].iteritems():
			out_fil.write(",".join([k[0].replace(",",""),k[1].replace(",",""),str(v)])+"\n")
		
	out_fil = open(output_dir+"ATC.csv","w")
	out_fil.write("Country,Topic,Agent,Weight\n")
	for k,v in atc_net.iteritems():
		out_fil.write(",".join([k[0].replace(",",""),k[1].replace(",",""),k[2].replace(",",""),str(v)])+"\n")
	
def gen_f1_scores(output_dir, articles_by_month, 
				  pro_violence, anti_violence,
				  pro_revolution,anti_revolution):
	import itertools,os
	from collections import defaultdict
	out_fil = open(output_dir + "/F1.csv","w")
	out_fil.write("Topic,BeliefTopic,Charge,Belief,TopicArticleCount,BeliefTopicCount,SameCount\n")
	topic_sets = [pro_violence,anti_violence,pro_revolution,anti_revolution]
	topic_set_names = ["Pro,Violence","Anti,Violence","Pro,Revolution","Anti,Revolution"]
	
	word_map= defaultdict(set)
	i = 0
	for day_network in articles_by_month:
		for article in day_network.values():
			for topic in article[1]:
				word_map[topic[0]].add(i)
			i+=1
	
	##build sentiment_word array so we don't have to do look-ups
	sentiment_word_array = []
	for topic_set in topic_sets:
		word_article_array = []
		for word in topic_set:
			if word in word_map:
				word_article_array.append([word, word_map[word]])
			else:
				word_article_array.append([word, set()])
		sentiment_word_array.append(word_article_array)
	
	
	for topic,articles in word_map.iteritems():
		topic_set_it = 0
		for topic_set_it in range(0,len(topic_sets)):
			for sentiment_word in sentiment_word_array[topic_set_it]:
				out_fil.write(",".join([
									topic, 
									sentiment_word[0],
									topic_set_names[topic_set_it],
									str(len(articles)),
									str(len(sentiment_word[1])),
									str(len(sentiment_word[1].intersection(articles)))])
							+"\n")
def gen_nets(pickled_fil,output_dir,
								pro_violence, anti_violence,
			  	 				pro_revolution,anti_revolution,):
	month_output_dir = output_dir+ os.path.basename(pickled_fil)
	print month_output_dir
	try:
		os.mkdir(month_output_dir)
	except:
		x=0
	month_article = pickle.load(open(pickled_fil))
	gen_month_network(month_output_dir,month_article)
	gen_f1_scores(month_output_dir,month_article, 
			  	  pro_violence, anti_violence,
			  	  pro_revolution,anti_revolution)

				  
def gen_named_entities(articles, raw_text_day, tagger):
	##for each article
	line = ""
	while line.strip() == "":
		line = raw_text_day.readline()
	
	n_docs = len(articles)
	seperator = re.compile('\s*[0-9]* of [0-9]* DOCUMENTS*', re.M)
	raw_articles =  re.split(seperator, raw_text_day.read())

	print line
	print n_docs
	print len(raw_articles)
	
	for i in range(1,len(raw_articles)+1):
		if str(i) not in articles:
			continue
		##pull the raw text
		e = tagger.get_entities(raw_articles[i-1])
		person_dict = defaultdict(int)
		people = []
		if 'PERSON' in e:
			##CLEAN PEOPLE LIST - remove pre-words, small names and long names
			to_remove = set()
			for person in e['PERSON']:
				person = person.lower()
				for term in TERMS_TO_REMOVE:
					person = re.sub(term,"",person)
				people.append(person.strip())

			ppl_tmp = []
			for person in people:
				if (len(person.split(" ")) >= MIN_NAME_LENGTH and 
				len(person.split(" ")) <= MAX_NAME_LENGTH and
				re.search(' street$',person) == None):
					person_dict[person]+=1
					ppl_tmp.append(person)
					
			people = ppl_tmp
			for p1,p2 in itertools.combinations(people,2):
				if len(p1) < len(p2):
					if merge_into(p1,p2):
						to_remove.add(p1)
						person_dict[p2] += 1
				else:
					if merge_into(p2,p1):
						to_remove.add(p2)
						person_dict[p1] += 1
						
			for k in person_dict.keys():
				if k in to_remove:
					person_dict.pop(k)

			people = [[k,v] for k,v in person_dict.iteritems()]
	
		##combine named entities not in tags into network		
		articles[str(i)].append(people)

	return articles
	
def get_gold_topics(file_name):
	topics = []
	in_fil = open(file_name)
	for line in in_fil:
		topics.append(line.strip())
	return topics

def generate_pickled_files_by_month(years,months,
									countries_of_interest,tagger):
	combinations = list(itertools.product(*[years,months]))
	for year_month in combinations:
		ym_raw_text_dir = raw_text_dir+"rev-"+"-".join(year_month)
		ym_name = "rev_"+"-".join(year_month)
		if not os.path.exists(ym_raw_text_dir):
			continue
		
		##now, for each day, pull all articles
		articles_by_month = []
		for index_day in glob(index_nets+ym_name+"*"):
			date = index_day.split("_")[1].replace(".net","")
			net_fil = open(index_day)
			
			articles_by_day = dict()
			article_subjects = []
			article_countries = []
			
			line_spl = net_fil.readline().strip().split("\t")
			prev_article = line_spl[1].split("_")[1]
			curr_article = prev_article
			if(line_spl[2] == 'GEOGRAPHIC'):
				article_countries.append(line_spl[3:5])
			elif(line_spl[2] == 'SUBJECT'):
				article_subjects.append(line_spl[3:5])
			
			for line in net_fil:
				line_spl = line.strip().split("\t")
				curr_article = line_spl[1].split("_")[1]
				if curr_article != prev_article:
					if len(countries_of_interest & set([x[0] for x in article_countries])) > 0:
						articles_by_day[prev_article] = [article_countries,article_subjects]
					prev_article=curr_article
					article_countries = []
					article_subjects = []
				if(line_spl[2] == 'GEOGRAPHIC'):
					article_countries.append(line_spl[3:5])
				elif(line_spl[2] == 'SUBJECT'):
					article_subjects.append(line_spl[3:5])
			if len(countries_of_interest & set([x[0] for x in article_countries])) > 0:
				articles_by_day[curr_article] = [article_countries,article_subjects]
			##Now we have all articles for that day.  We need to create the networks for that day
			raw_text_day = open(ym_raw_text_dir+"/rev_"+date+".txt")
			articles_by_month.append(gen_named_entities(articles_by_day, raw_text_day,tagger))

		pickle_fil = pickle_output_dir+ym_name
		pickle.dump(articles_by_month,open(pickle_fil,"w"))



##This is the location of the top level dir containing the raw text and input items	
top_dir = "PATH_TO_TOP_LEVEL"

##raw_txt holds the raw text, indexitems the index items from LexusNexus
raw_text_dir = top_dir+"raw_txt/"
index_nets = top_dir+"indexitems/"

##We pickle out the output of the NER so we don't have to re-run
pickle_output_dir = top_dir+"pickled_out/"

##Output to R code for filtering, tuning
output_dir = top_dir+"output_to_R/"

gold_standard_dir = "gold_topics/"

####Commented out, expensive (on the order of hours/a day for all months)
#os.mkdir(output_dir)
#os.mkdir(pickle_output_dir)
#tagger = ner.SocketNER(host='localhost', port=9124, output_format='slashTags')
#generate_pickled_files_by_month(years,months,countries_of_interest,tagger)

years = ['2010','2011','2012']
months = ['0'+str(x) for x in range(1,10)] + ['10','11','12']

pro_violence = get_gold_topics(gold_standard_dir+"pro_violence.csv")
anti_violence = get_gold_topics(gold_standard_dir+"anti_violence.csv")
pro_revolution = get_gold_topics(gold_standard_dir+"pro_revolution.csv")
anti_revolution = get_gold_topics(gold_standard_dir+"anti_revolution.csv")
countries = get_gold_topics(gold_standard_dir+"countries.txt")
countries_of_interest = set(countries)

pickled_files = glob(pickle_output_dir+"*")
#for pickled_fil in pickled_files:
#	gen_nets(pickled_fil,output_dir,
#								pro_violence, anti_violence,
#			  	 				pro_revolution,anti_revolution)

job_server = pp.Server(ncpus=len(pickled_files), ppservers=())
jobs = [job_server.submit(gen_nets,
                               (pickled_fil,output_dir,
								pro_violence, anti_violence,
			  	 				pro_revolution,anti_revolution,),
                               (gen_month_network,gen_f1_scores,merge_into,
								get_max_words,get_max_country),
                               ("csv","editdist"))
                               for pickled_fil in pickled_files]
for job in jobs:
	print job()

                                