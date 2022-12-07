import os,sys,re,time
from nltk import tokenize
# We first clean 10-K by following Professor Bill McDonald to exclude markup tags, ASCII-encoded graphics, XBRL content, and tables
# rd_disc - the number of R&D-related sentences in the 10-K
# rd_discfls - the number of forward looking R&D-related sentences in the 10-K
# rd_discnum - the number of future-looking R&D-related sentences with numerical information in the 10-K
if __name__=="__main__":
    # define keywords and input and output files
    futuretense = ["will", "could", "should", "expect", "anticipate", "plan", "hope", "believe", "can,","may", "might", "intend", "project", "forecast", "objective", "goal"]
    keywords = [word.strip() for word in open("/home/work/RD_Keywords.txt",'r').readlines()]
    delimiter = ','
    file_output=open("/home/work/RD_disc.csv","w", encoding="utf-8")
    file_output.write('CIK%sFiledate%sFiletype%sFilename%sRD_Disc%sRD_Discfls%sRD_Discnum\n'%(delimiter,delimiter,delimiter,delimiter,delimiter,delimiter))
    # search R&D sentences
    for year in range(1994,2017):
            file_dir="/home/work/10K_cleaned/"+str(year)+"/"
            # get the path of files to process
            file_list = os.listdir(file_dir)
            for file_name in file_list:
                elements = file_name.split("_")
                if elements[1] not in ["10-K","10KSB"]:
                    continue
                filetoparse = file_dir + file_name
                with open(filetoparse, 'r') as file:
                    text = file.read().strip()
                    sentences = tokenize.sent_tokenize(text)
                    RD_sents = [sent for sent in sentences if any((w in sent) for w in keywords)]
                    RD_sentsfls = [sent for sent in sentences if any(w in sent for w in keywords) and any(fls in sent for fls in futuretense)]
                    RD_sentsnum = [sent for sent in sentences if any(w in sent for w in keywords) and re.search("\\d+", sent)]
                    file_output.write("%s%s%s%s%s%s%s%s%s%s%s%s%s\n"%(elements[4], delimiter, elements[0], delimiter, elements[1], delimiter, elements[5], delimiter, len(RD_sents), delimiter, len(RD_sentsfls), delimiter, len(RD_sentsnum)))
    file_output.close()
    # RD_discexample.close()
