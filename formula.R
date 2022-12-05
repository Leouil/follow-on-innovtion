# define linear regression formula
lmfm <- function(dv, ivs, fes=NULL) {
  # run a linear model with text arguments for dv and ivs
	iv_part <- paste(ivs, collapse=" + ")
  if(is.null(fes)){
    iv_string <- iv_part
  }else{
    fe_part <- paste(paste0("factor(", fes, ")"), collapse=" + ")
    iv_string <- paste(iv_part, fe_part, sep=" + ")
  }
	as.formula(paste(dv, iv_string, sep=" ~ "))
  # lm(formula, data)
  # pdf <- pdata.frame(df, index = c("sic2_j", "citingappyear"))
  # plm(formula, pdf, model = "within", effect = "twoways")
}

fefm <- function(dv, ivs, fes='0', clu='0') {
    # run a multi-group fixed effect linear model
    iv_part <- paste(ivs, collapse=" + ")
    fe_part <- paste(fes, collapse=" + ")
    cluster <- paste(clu, collapse=" + ")
    iv_string <- paste(iv_part,fe_part,'0',cluster, sep=" | ")
    as.formula(paste(dv, iv_string, sep=" ~ "))
    # plm(formula, data, model = "within", effect = "twoways")
}

befm <- function(dv, ivs, fes) {
    iv_part <- paste(ivs, collapse=" + ")
    fe_part <- paste(fes, collapse=" + ")
    iv_string <- paste(iv_part,fe_part, sep=" | ")
    as.formula(paste(dv, iv_string, sep=" ~ "))
    # plm(formula, data, model = "within", effect = "twoways")
}

pgfm <- function(dv, ivs, gminst=NULL) {
    # run a multi-group fixed effect linear model
    iv_part <- paste(ivs, collapse=" + ")
    dv_lag <- paste('lag(',dv,',1:3)', sep="")
    lagdv_iv <- paste(dv_lag,iv_part, sep=" + ")
    gminst_part <- paste('lag(',gminst,',2:99)', sep="")
    iv_string <- paste(lagdv_iv,gminst_part, sep=" | ")
    as.formula(paste(dv, iv_string, sep=" ~ "))
    # plm(formula, data, model = "within", effect = "twoways")
}

lfeicpt <- function(tb){
  coeff=c()
  t_stat=c()
  for(est in tb){
    fes = getfe(est, ef='zm2',se=TRUE)
    icpt=fes[rownames(fes)=="icpt.1",]
    coeff=c(coeff,icpt$effect)
    t_stat=c(t_stat,icpt$effect/icpt$clusterse)
  }
  linecoeff=c("Intercept",round(coeff,3))
  linetstat=c("",paste("t =",'"',round(t_stat,2)),'"')
  return(list(linecoeff,linetstat))
}

# output regression table
outhtm <- function(tb,outfile,addicpt=NULL) {
   library(stargazer)
   stgzout = capture.output(stargazer(tb,type = "html",header=FALSE,report = "vc*t",add.lines=addicpt))
   # stgzout = gsub("t = (-?[0-9]+[.][0-9][0-9])[0-9]","\\(\\1\\)",stgzout,perl=TRUE)
   cat(paste(stgzout, collapse = "\n"), "\n", file=outfile, append=FALSE)
}
outcsv <- function(tb,outfile=NULL,addicpt=NULL,omitfe=NULL) {
   library(stargazer)
   stgzout = capture.output(stargazer(tb,type = "html",header=FALSE, report = "vc*t", add.lines=addicpt, omit=omitfe))
   stgzout = gsub("t = (-?[0-9]+[.][0-9][0-9])[0-9]","\\(\\1\\)",stgzout,perl=TRUE)
   stgzout = gsub("<td.*?>(.*?)</td>",'<td>="\\1"</td>',stgzout,perl=TRUE)
   stgzout = gsub("</tr><tr>",'\n',stgzout,perl=TRUE)
   stgzout = gsub("<(/?)table.*?>|<(/?)tr>|<td.*?>|<(/?)sup>|<(/?)em>|,",'',stgzout,perl=TRUE)
   stgzout = gsub("</td>",',',stgzout,perl=TRUE)
   index=c(1,2)
   for(i in 1:length(stgzout)){
    if(!grepl('[0-9a-zA-Z]',stgzout[i]))
      index=c(index,i)
   }
   stgzout=stgzout[-index]
   if(is.null(outfile)){
      cat(paste(stgzout, collapse = "\n"), "\n")
    }else{
      cat(paste(stgzout, collapse = "\n"), "\n", file=outfile, append=FALSE)
    }

}
outtxt <- function(tb,outfile) {
   library(stargazer)
   stgzout = capture.output(stargazer(tb,type = "text",header=FALSE, report = "vc*t"))
   # stgzout = gsub("t = (-?[0-9]+[.][0-9][0-9])[0-9]","\\(\\1\\)",stgzout,perl=TRUE)
   cat(paste(stgzout, collapse = "\n"), "\n", file=outfile, append=FALSE)
}
outsbs <- function(tb,outfile=NULL,addicpt=NULL,omitfe=NULL) {
   library(stargazer)
   library(stringr)
   stgzout = capture.output(stargazer(tb,type = "html",header=FALSE, report = "vc*t", add.lines=addicpt, omit=omitfe))
   stgzout = gsub('"','',stgzout,perl=TRUE) # remove quotations
   stgzout = gsub("<tr><td.*?></td></tr><tr>","",stgzout,perl=TRUE)
   rmidx=c(1,2)
   for(i in 1:length(stgzout)){
     # vec=str_extract_all(stgzout[i],"<td.*?>.*?</td>")[[1]]
     if(length(grep('>\\s*[0-9a-zA-Z\\()]',stgzout[i]))==0){# skip empy line
        rmidx=c(rmidx,i)
      }
    }
   stgzout=stgzout[-rmidx]
   if(length(stgzout)==0) stop("empty regression output")
   output = c()
   line = 1
   while(line < (length(stgzout)-1)){
      # print(stgzout[line])
      row1=str_extract_all(stgzout[line],"<td.*?>.*?</td>")[[1]]
      # print(line)
      # print(length(row1))
      # if(length(row1)==0)break
      if(grepl("t =",stgzout[line+1])){
        row2=str_extract_all(stgzout[line+1],"<td.*?>.*?</td>")[[1]]
        row=paste(c(rbind(row1,row2)), collapse=",")
        output=c(output,row)
        line=line+2
        }
        else{
            row=paste(c(rbind(row1,vector(mode="character", length=length(row1)))), collapse=",")
            output=c(output,row)
            line=line+1
        }
      }
   output = gsub("t =\\s*(-?[0-9]+[.][0-9][0-9])([0-9])?","\\1",output,perl=TRUE)
   output = gsub("<td.*?>(.*?)</td>",'<td>="\\1"</td>',output,perl=TRUE)
   # output = gsub("</tr><tr>",'\n',output,perl=TRUE)
   output = gsub("<td.*?>|</td>|<(/?)sup>|<(/?)em>",'',output,perl=TRUE)
   # output = gsub("</td>",',',output,perl=TRUE)
   # output = gsub(',=""','',output,perl=TRUE) # remove extra column
   # index=c(1,2)
   # for(i in 1:length(output)){
   #  if(!grepl('[0-9a-zA-Z]',output[i]))
   #    index=c(index,i)
   # }
   # output=output[-index]
   if(is.null(outfile)){
      cat(paste(output, collapse = "\n"), "\n")
    }else{
      cat(paste(output, collapse = "\n"), "\n", file=outfile, append=FALSE)
    }
   
}