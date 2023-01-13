/******************************************************
 * LBドメインから臨検値のボックスプロットを作成する   *
 * 出力したい順の番号が LBGLPIDに入力されている前提   *
 * LBGLPIDがブランクの場合、LBCAT+LBSPEC+LBTEST順     *
 * SDTMフォルダに、VisitList.csvを作成しておく        *
 * 			  S.Takahara Kanazawa University Hospital *
 ******************************************************/

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力PDFファイルのフォルダをoutfに割り当てる
 ****************/

%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop ;

ods	pdf	file	=	"&outf\boxplot.pdf"  ;

options	orientation	=	landscape ;
options	mprint ;
/*
 * Visit関連のFormatを作成する
 */
proc import	out			=	visit_list0
				datafile	=	"&sdtm\visitlist.csv"
				dbms		=	csv
				replace
				;
	getnames		=	yes ;
	datarow			=	2 ;
	guessingrows	=	max ;
run ;
* Format ;
data	visitf ;
	set		visit_list0 ;
	start	=	visitnum ;
	end		=	visitnum ;
	fmtname	=	'visitf' ;
	type	=	'n' ;
	keep	start	end	label	fmtname	type ;
run ;
proc format	cntlin	=	visitf ;
run ;
/*
 * SDTMデータ読み込みMacro
 */
%macro	readds	( domain , select ) ;
	proc import	out			=	&domain.0
				datafile	=	"&sdtm\&domain..csv"
				dbms		=	csv
				replace
				;
			getnames		=	yes ;
			datarow			=	2 ;
			guessingrows	=	max ;
	run ;
	data	&domain.1 ;
		set		&domain.0 ;
			where	&select ;
	run ;
%mend ;

/*
 * SDTMデータ読み込み ;
 */
%readds		( lb , lbstresn ne . ) ;	* ボックスプロットなので数値データのみ ;

proc sort	data	=	lb1 ;
	by	lbgrpid	lbcat	lbspec	lbtest	lbstresu	visitnum ;
	format	visitnum	visitf. ;
run ;

proc sgplot data	=	lb1 ;
	by		lbgrpid	lbcat	lbspec	lbtest	lbstresu ;
	vbox	lbstresn	
			/	category	=	visitnum ;
	label	lbgrpid	=	'No.'
			lbcat	=	'Cat.'
			lbspec	=	'Spec.'
			lbtest	=	'Test'
			lbstresu	=	'Unit'
			lbstresn	=	'Result'
			visitnum	=	'Visit'
			;
	format	visitnum	visitf. ;
run ;
ods	pdf	close ;
