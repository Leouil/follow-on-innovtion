* This code construct citation data and patent stock data after collect patent and citation data from USPTO;
filename macrodir "/sasmacro";
* SAS macros used are all available at https://github.com/Leouil/SASMacro;
%include macrodir(winsor,lagvar,leadvar,nvarlist,compfilter,filtermissing);
libname comp "/comp";
libname crsp "/crsp";
libname innov "/innovation";

* ----------------------construct patent variables----------------------;
* citation data collected from USPTO for patents granted from 1975 to 2019;
 data innov.allcitations;
   set innov.allcitations;
   if missing(input(patent_id,10.))=1 or missing(input(citation_id,10.))=1 then delete;
run;

* identify common inventor using pat inventor information - innov.patinventor;
proc sql;
create table citinginv as
select distinct a.patent_id, a.citation_id, b.inventor_id
    from innov.allcitations a, innov.patinventor b
    where input(a.patent_id,8.)=input(b.patent_id,8.)
;
create table citedinv as
select distinct a.citation_id, b.inventor_id
    from innov.allcitations a, innov.patinventor b
    where input(a.citation_id,8.)=input(b.patent_id,8.)
;
create table commoninv as
select distinct a.*, b.inventor_id as citedinventor_id
    from citinginv a left join citedinv b
    on a.citation_id=b.citation_id and a.inventor_id=b.inventor_id
;
create table citations_cominv as
select patent_id, citation_id, count(*) as cominvs
    from commoninv(where=(missing(citedinventor_id)=0))
group by patent_id, citation_id
;
create table allcitations as
select distinct a.*, coalesce(b.cominvs,0) as cominvs
    from innov.allcitations a left join citations_cominv b
on a.patent_id=b.patent_id and a.citation_id=b.citation_id
;
quit;

* add firmid (permno) and patent issue and grant date using KPSS patent-permno link table patent2019;
proc sql;
create table allcitations as 
select distinct
  a.*, b.permno as citingpermno,
  b.issue_date as citingissue_date, year(b.issue_date) as citinggyear,
  b.filing_date as citingfiling_date, year(b.filing_date) as citingappyear
from 
  allcitations a,
  innov.patent2019 b
where 
  input(a.patent_id,10.)=b.patent_num
;
create table allcitations as 
select distinct
    a.*, b.permno as citedpermno, b.xi_real as evpat_cited,
    b.issue_date as citedissue_date, year(b.issue_date) as citedgyear,
    b.filing_date as citedfiling_date, year(b.filing_date) as citedappyear
from 
  allcitations a,
  innov.patent2019 b
where 
    input(a.citation_id,10.)=b.patent_num
;
quit;

** compute average citation number ;
*patent number by USPC patent class by grantyear;
proc sort data=innov.classes7519 out=classes7519 nodupkey;
  by patent_id mainclass;
run;
proc sql;
create table patent2019 as
select distinct a.*, year(issue_date) as grantyear, b.mainclass
from 
  innov.patent2019 a
left join
  classes7519 b
on a.patent_num=input(b.patent_id,10.)
;
create table innov.patcntclassyear as
select distinct mainclass, grantyear, count(*) as patcntclassyear
from
  patent2019
group by mainclass, grantyear
;
quit;

proc sql;
* average citations in main class and year;
create table allcitations as
select distinct *, count(patent_id) as citeclass
from allcitations
group by citedclass, citedgyear, citingappyear
;
* add total patent number in a USPC tech class and a grant year;
create table allcitations as
select distinct a.*, a.citeclass/b.patcntclassyear as avgciteclass
from allcitations_all a
left join innov.patcntclassyear b
on a.citedclass=b.mainclass and a.citedgyear=b.grantyear
;
quit;
proc sort data=allcitations nodupkey;
  by patent_id citation_id;
run;

data innov.allcitations;
  set allcitations;
if missing(citedpermno) or missing(citingpermno) then delete;
self=(citedpermno=citingpermno);
examiner = (find(category,'examiner', 'i')>0;*examiner added citations;
within3=(0<=citingappyear-citedgyear<3);
within5=(0<=citingappyear-citedgyear<5);
within7=(0<=citingappyear-citedgyear<7);
within20=(0<=citingappyear-citedgyear<20);
patentage=citingappyear-citedgyear;
run;

/*
proc sql;
***************1) by citingappyear;
create table paircite as
select distinct
  citingpermno, citedpermno, citingappyear,
  sum(within20) as citenum,
  sum(within20/avgciteclass) as citenumadj,
  mean(patentage) as patentage
from 
  allcitations_all(where=(within20=1 and self=0))
group by 
  citingpermno, citedpermno, citingappyear
;
*total citations in patents applied in a year;
create table paircite as
select distinct
  a.*, sum(a.citenum) as totcited, sum(a.citenumadj) as totcitedadj,
  sum(a.citenum)-citenum as totothercited, sum(a.citenumadj)-citenumadj as totothercitedadj,
from 
  paircite a
group by 
  citedpermno, citingappyear
;
quit;
*/

** compute patent stock;
data patent2019;
  set patent2019;
  year = year(issue_date);
run;

proc sql;
create table patcnt as
select distinct permno, year, count(*) as patcnt
from patent2019
group by permno, year
;
create table allfirmyears as
  select distinct
    a.gvkey, a.fyear, a.datadate, b.lpermno as permno
  from comp.funda(where=(%compfilter)) as a,
  crsp.lnk as b
  where a.GVKEY=b.GVKEY and (b.LINKDT <= a.datadate or b.LINKDT = .B) 
  and (a.datadate <= b.LINKENDDT or b.LINKENDDT = .E)
  order by gvkey, permno, datadate
;
create table patcnt as
select distinct a.permno, a.fyear as year, coalesce(b.patcnt,0) as patcnt
from
  allfirmyears a
left join
  patcnt b
on a.permno=b.permno and a.fyear=b.year
;
create table pre20 as
select distinct a.permno, a.year, b.year as year2, (a.year-b.year) as relyear, b.patcnt
from
  patcnt a
left join
  patcnt b
on a.permno=b.permno and a.year-19 <= b.year<= a.year
;
create table patentstock as
select distinct permno, year, sum(patcnt) as patentstock,
				sum(patcnt*(relyear<=2)) as w3patcnt,
                sum(patcnt*(relyear>2 and relyear<=6)) as bw37patcnt,
                sum(patcnt*relyear)/sum(patcnt) as patentage
from pre20
group by permno, year
;
quit;

data innov.patentstock;
  set innov.patentstock;
  w3=w3patcnt/patentstock;
  bw37=bw37patcnt/patentstock;
run;

/*
proc sql;
create table paircite as 
select distinct
  a.*, b.patentstock, b.w3, b.bw37
from 
  paircite a 
left join 
  patentstock b
on 
  a.citedpermno=b.permno and a.citingappyear=b.year
;
quit;

data paircite;
  set paircite;
  logpatentstock = log(1+patentstock);
  logpatentstocksq = log(1+patentstock)**2;
run;

* add technology similarity - cosine following Jaffe (1986);
proc sql;
create table paircite as
select distinct
  a.*, b.cosinesim as techsim
from
  paircite a
left join
  innov.Techsim b
on 
  a.citedpermno=b.permno and a.citingpermno=b.permno2 and a.citingappyear=b.year
;
quit;

data innov.paircite;
  set paircite;
  if missing(citedpermno)=0 and missing(citingpermno)=0;
  if citingappyear>=1999 and citingappyear<=2017;
run;
*/

