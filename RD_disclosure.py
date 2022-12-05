import os,sys,re,time
from nltk import tokenize
# rd_disc - the number of R&D-related sentences in the 10-K (after cleaning HTML tags, content between XBRL tags, and special characters beginning with "\&" from Raw file of 10-K)
# lrd_disc - LN(1+rd_disc)
# fls_rd_disc - the number of future-looking R&D-related sentences in the 10-K
# fls_lrd_disc - LN(1+fls_rd_disc)
# patentapp - the number of patent-related sentences in the 10-K
# lpatentapp - LN(patentapp+1)
# rdprogress - the number of R&D-related sentences that relate to R&D progress
# lrdprogress - LN(1+rdprogress)
if __name__=="__main__":
    # define keywords and input and output files
    futuretense = ["will", "could", "should", "expect", "anticipate", "plan", "hope", "believe", "can,","may", "might", "intend", "project", "forecast", "objective", "goal"]
    # keywords = [word.strip() for word in open("C:\\Users\\lyang3\\Dropbox\\SEC Filings Scripts\\RD_Keywords.txt",'r').readlines()]
    keywords = [word.strip() for word in open("/home/work/RD_Keywords.txt",'r').readlines()]
    # conamepattern = "^\s*COMPANY\s*CONFORMED\s*NAME:\s*(.*$)"
    delimiter = ','
    file_output=open("/home/work/RD_disc.csv","w", encoding="utf-8")
    file_output.write('CIK%sFiledate%sFiletype%sFilename%sRD_Disc%sRD_Discfls%sRD_Discnum\n'%(delimiter,delimiter,delimiter,delimiter,delimiter,delimiter))
    # search R&D sentences
    for year in range(1994,2017):
            # pwd = os.getcwd()
            # file_dir = pwd+'/data_files'
            # file_dir="C:\\Users\\lyang3\\SEC10K\\"+str(year)+"\\QTR"+str(qtr)+"\\"
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
    #                 coname = re.search(r'\s*COMPANY\s*CONFORMED\s*NAME:\s*(.*)', text)
                    sentences = tokenize.sent_tokenize(text)
                    RD_sents = [sent for sent in sentences if any((w in sent) for w in keywords)]
    #                 RD_joinedsents = re.sub(r'"',r'',' '.join(RD_sents[:51]))
    #                 RD_joinedsents = re.sub(r'\n|\s+|\t',r' ',RD_joinedsents)
    #                 RD_joinedsents = '"'+RD_joinedsents+'"'
    #                 RD_sents = [sent for sent in sentences if any(re.search("\\b{}\\b".format(w), sent) for w in keywords)]
                    RD_sentsfls = [sent for sent in sentences if any(w in sent for w in keywords) and any(fls in sent for fls in futuretense)]
                    RD_sentsnum = [sent for sent in sentences if any(w in sent for w in keywords) and re.search("\\d+", sent)]
                    file_output.write("%s%s%s%s%s%s%s%s%s%s%s%s%s\n"%(elements[4], delimiter, elements[0], delimiter, elements[1], delimiter, elements[5], delimiter, len(RD_sents), delimiter, len(RD_sentsfls), delimiter, len(RD_sentsnum)))
    #                 file_output.flush()
    #                 RD_discexample.write('%s%s%s%s%s%s%s%s%s\n'%(elements[4], delimiter, '"'+coname.group(1)+'"', delimiter, elements[0], delimiter, len(RD_sents), delimiter, RD_joinedsents))
    #                 RD_discexample.flush()

    file_output.close()
    # RD_discexample.close()
