import glob, os, random,sys,csv, math, itertools, errno, shutil, pp
from collections import defaultdict
from time import sleep

data_dir = "PATH_TO_OUTPUT_FROM_FILTER_TUNE (probably output.R)"
source_dir = "github/"

def index_file(month_dir, name, index1=None, index2=None,use_weights=False):
	in_fil = open(month_dir+"/"+name+".csv")
	out_fil = open(month_dir+"/"+name+"_indexed.csv","w")
	out_fil.write("source,target,weight\n")
	
	in_fil.readline()
	
	if index1 == None:
		index1=defaultdict(list)
	if index2 == None:
		index2=defaultdict(list)
		
	i1 = 0
	i2 = 0
	
	for line in in_fil:
		[l1,l2,weight] = [x.strip() for x in line.split(",")]
		weight = int(weight)
		if weight == 0:
			continue
		if l1 not in index1:
			index1[l1].append(i1)
			i1+=1
		if l2 not in index2:
			index2[l2].append(i2)
			i2+=1
			if use_weights:
				weight_addition = abs(weight)-1
				index2[l2] += [i2+i for i in range(weight_addition)]
				i2 += weight_addition
		for second_ind in index2[l2]:
			out_fil.write(",".join([str(index1[l1][0]),str(second_ind),str(math.copysign(1.0,weight))])+"\n")
		
	out_fil.close()
	return index1,index2,i1,i2	

def create_agent_agent_file(month_dir,agent_dict):
	in_fil = open(month_dir+"/AA.csv")
	out_fil = open(month_dir+"/AA_indexed.csv","w")
	out_fil.write("source,target,weight\n")
	
	in_fil.readline()
	
	for line in in_fil:
		[agent1,agent2,weight] = [x.strip() for x in line.split(",")]
		#bug in R script
		if agent1 not in agent_dict or agent2 not in agent_dict:
			continue
			
		weight = float(weight)
		agent1_index = str(agent_dict[agent1][0])
		agent2_index = str(agent_dict[agent2][0])
		out_fil.write(",".join([agent1_index,
								agent2_index,
								"1\n"]))
	out_fil.close()

	
def create_agent_knowledge_file(month_dir,agent_dict,knowledge_dict,fil_name,is_transmission):
	in_fil = open(month_dir+"/"+fil_name+".csv")
	out_fil = open(month_dir+"/"+fil_name+"_indexed.csv","w")
	out_fil.write("source,target,weight\n")

	in_fil.readline()
	
	for line in in_fil:
		[agent,knowledge,weight] = [x.strip() for x in line.split(",")]
		#bug in R script
		if agent not in agent_dict:
			continue
			
		weight = float(weight)
		agent_index = str(agent_dict[agent][0])
		knowledge_indicies = knowledge_dict[knowledge]
		likelihood = weight/len(knowledge_indicies)
		for ki in range(len(knowledge_indicies)):
			if is_transmission:
				out_fil.write(",".join([agent_index,
										str(knowledge_indicies[ki]),
										str(likelihood)])+"\n")
			elif random.random() < likelihood:
				out_fil.write(",".join([agent_index,
										str(knowledge_indicies[ki]),
										"1\n"]))
	out_fil.close()

def run_data_transformation(month_dir):

	[agents, groups, num_agents,num_groups] = index_file(month_dir, "AG")
	[beliefs,knowledge,num_beliefs,num_facts] = index_file(month_dir,"TB",use_weights=True)
	
	dicts = [agents,groups,knowledge,beliefs]
	dict_names = ["agent","groups","knowledge","beliefs"]
	
	create_agent_agent_file(month_dir,agents)
	create_agent_knowledge_file(month_dir,agents,knowledge,"AT",False)
	create_agent_knowledge_file(month_dir,agents,knowledge,"AT_trans",True)

	for i in range(len(dicts)):
		d = dicts[i]
		f = open(month_dir+"/"+dict_names[i]+"_map.csv","w")
		f.write("Term,Mapping\n")
		for key, values in d.iteritems():
			for v in values:
				f.write(",".join([key,str(v)])+"\n")
		f.close()
		
	return [num_agents,num_groups,num_facts,num_beliefs]	

def mkdir_p(path):
	try:
		os.makedirs(path)
	except OSError as exc: # Python >2.5
		if exc.errno == errno.EEXIST and os.path.isdir(path):
			pass
		else: raise
		
def run(exp_dir,data_dir,source_dir):
	import shutil
	import os
	import subprocess
	print 'running?'
	shutil.copyfile(source_dir+"/run/Construct.exe",exp_dir+"/Construct.exe")
	shutil.copyfile(source_dir+"/run/deck.xml",exp_dir+"/deck.xml")
	
	output_fil = open(exp_dir+"/out.txt","w")
	
	print exp_dir
	p = subprocess.Popen([exp_dir+'/Construct.exe',exp_dir+'/deck.xml'],
			stdout=output_fil,
			stderr=subprocess.PIPE,
			cwd=exp_dir)
	err = p.communicate()
	print err

#####Set up parameters passed in from command line
if(len(sys.argv) < 1  ):
	print("Usage: run_new.py [conditionsCSV]")
	sys.exit(-1)

experimental_conds_file_name = sys.argv[1]

####Read in conditions file
cond_file = open(experimental_conds_file_name, "rU")
reader = csv.reader(cond_file)
values = []
condition_titles =[]
for line in reader:
	condition_titles.append(line[0]);
	values.append([val for val in line[1:] if val != ""])

experimental_set = list(itertools.product(*values))
num_vals = len(condition_titles)

print "Num Conditions: " + str(len(experimental_set))

month_nets = glob.glob(data_dir+"/rev*")
print(month_nets)

experimental_dirs = []
for month in month_nets:
	[num_agents,
	 num_groups,
	 num_facts,
	 num_beliefs] = run_data_transformation(month)

	## Then the experimental conditions
	for experiment in experimental_set:
		conds_string = "_".join(experiment)
		experimental_dir_name=month+"/"+conds_string
		mkdir_p(experimental_dir_name)
		##Write parameters file
		with open(os.path.join(experimental_dir_name,"params.csv"), "w") as param_file:
				param_file.write('parameter,value\n')
				param_file.write("Agent Count,"+str(num_agents)+"\n")
				param_file.write("Group Count,"+str(num_groups)+"\n")
				param_file.write("Knowledge Count,"+str(num_facts)+"\n")
				param_file.write("Belief Count,"+str(num_beliefs)+"\n")
				for i in range(num_vals):
						param_file.write(condition_titles[i] + "," + experiment[i] + '\n')
				param_file.write("Date,"+os.path.basename(month).split("_")[1]+"\n")
		experimental_dirs.append(experimental_dir_name)
	print month
job_server = pp.Server(ncpus=8, ppservers=())
jobs = [job_server.submit(run,
                         (exp_dir,data_dir,source_dir),
                         (),
                         ())
                         for exp_dir in experimental_dirs ]
                                
for job in jobs:
	print job()

