/******************************************************
 * LBドメインから症例毎の臨検値の推移グラフを作成する *
 * 出力したい順の番号が LBGLPIDに入力されている前提   *
 * LBGLPIDがブランクの場合、LBCAT+LBSPEC+LBTEST順     *
 * 			  S.Takahara Kanazawa University Hospital *
 ******************************************************/

%let	usubjid	=	0001 ;		* 出力したいUSUBJID ;

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力PDFファイルのフォルダをoutfに割り当てる
 ****************/

%let	sdtm	=	T:\Projects\XXXX\41.Data\sdtm\csv ;
%let	outf	=	C:\Output ;

ods	pdf	file	=	"&outf\graph_&usubjid..pdf"  ;

options	orientation	=	landscape ;
options	mprint ;

proc	format ;
* VISITNUM が等間隔でない場合、等間隔にしたければ番号を振りなおす ;
	invalue visiti
		-1		=	1
		0		=	2
		120		=	3
		7000	=	4
	;
* VISIT が入力されていない場合、Visit名を定義する ;
	value visitf
		1			=	'Scr'
		2			=	'Pre'
		3			=	'120min'
		4			=	'Day7'
	;
run ;

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
%readds		( lb , LBTESTCD ne '' and usubjid eq "&usubjid" ) ;

data	lb2 ;
	set		lb1 ;

	itemno		=	input	( lbgrpid ,	best. ) ;

	visitno		=	input	( visitnum ,	visiti. ) ;	

	if	lbstresn ne .	then	output ;				* グラフにするので数値データのみ ;

	keep	usubjid	lbgrpid	lbcat	lbspec	lbtest	lbstresn	lbstresu	lbstnrlo	lbstnrhi	visitno	visitnum ;
	format	visitno	visitf. ;
run ;

proc sort	data	=	lb2 ;
	by	usubjid	lbgrpid	lbcat	lbspec	lbtest	lbstresu	visitno ;
run ;

symbol1	color		=	black
		value		=	dot
		width		=	8
		interpol	=	join ;
symbol2	color		=	black
		value		=	plus
		line		=	4
		interpol	=	join ;
symbol3	color		=	black
		value		=	plus
		line		=	4
		interpol	=	join ;

goptions	hby	=	2 ;	

proc gplot	data	=	lb2 ;
	by		usubjid	lbgrpid	lbcat	lbspec	lbtest	lbstresu ;
	plot	lbstresn * visitno
			lbstnrlo * visitno
			lbstnrhi * visitno
			/ overlay ;
	format	visitno	visitf. ;
	label	lbcat	=	'Category'
			lbspec	=	'Specimen'
			lbtest	=	'Test'
			lbstresu	=	'Unit'
			lbstresn	=	'Result'
			visitno	=	'Visit'
			;
run ;

quit ;

ods	pdf	close ;
