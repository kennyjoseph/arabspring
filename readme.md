Disclaimer
-------
The code here was used in the following article:

```
@article{joseph2014arab,
  title={Arab Spring: from newspaper},
  author={Joseph, Kenneth and Carley, Kathleen M and Filonuk, David and Morgan, Geoffrey P and Pfeffer, J{\"u}rgen},
  journal={Social Network Analysis and Mining},
  volume={4},
  number={1},
  pages={1--17},
  year={2014},
  publisher={Springer Vienna}
}

```

All code attached was written by me.  

If you use the code, please reference the article if at all appropriate to do so!


Data
-------
The data, unfortunately, could not be released. However, I do provide:

-a sample set of the output in data/rev_2011-01/ from after the Meta-network creation has been completed.  This data can be used to run the simulation model.
-the data for table 3 in results_overthrow.csv 


The simulation results are not available here due to github's file restriction size, but you can find them at the following link:


https://dl.dropboxusercontent.com/u/53207718/results_sim_final.csv


Code
---------
Code is provided to provide more detail on the algorithms/methods used and to provide a jumping off point for future work.

If you have questions or comments, feel free to contact me!

Process
-----------
The process used in the article was the following:

0. Created the list of "seed topics" and placed them into the gold_topics directory.  Also in the directory is the list of countries of interest, countries.txt, and the list of partial westerner names, westerners.csv.

1. Ran setup/networks_from_text.py.  This runs steps 1, 2 and most of 3 from the section "Meta-network creation" in the paper, including use of the Stanford NER.  Because the NER is java-based and I wrote the code in python, I used a tool developed by the Stanford lab to communicate with the NER over a socket connection.  Therefore, you need a Stanford NER Server running locally on port 9124 for that to work.  Notice that the output from these steps are pickled so that I didn't have to redo the NER when I was making changes to the post-processing steps. Also notice months are run in parallel using pp

2. Ran setup/filter_tune.R.  This completes step 3 (the filtering part) and runs 4-7 of the section "Meta-network creation" in the paper.

3. Ran run/run_construct_local.py.  This sets up the data from the meta-network creation for Construct and runs it locally using 8 cpus. It reads in the parameters necessary for Construct from runs/conditions.csv, running each possible condition as a single replication.  The file run/deck.xml is where the simulation model is defined for Construct - see any of the publications describing Construct in more detail or get a hold of me if things don't make sense. The maximum RAM needs of a single run is 32 GB, though this was only for one month with significantly more agents.  The RAM needs for most months was much closer to 10 GB.  

4. Run analysis/gen_results.R to pull and aggregate the outcomes

5. Run analysis/analysis.R to generate the results shown in the article's results section

6. Figures 3,4,5 were generated using analysis/generate_figures_3,4,5.R and a commercial build of ORA.  This costs money, but you can build similar plots with relative ease just using R (and ggplot, if you're so inclined :) )
