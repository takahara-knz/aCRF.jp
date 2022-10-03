/******************************************************
 * LBドメインから臨検値のボックスプロットを作成する   *
 * 出力したい順の番号が LBGLPIDに入力されている前提   *
 * LBGLPIDがブランクの場合、LBCAT+LBSPEC+LBTEST順     *
 * 			  S.Takahara Kanazawa University Hospital *
 ******************************************************/

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力PDFファイルのフォルダをoutfに割り当てる
 ****************/

%let	sdtm	=	T:\Projects\XXXX\41.Data\sdtm\csv ;
%let	outf	=	C:\Output ;

ods	pdf	file	=	"&outf\boxplot.pdf"  ;

options	orientation	=	landscape ;
options	mprint ;

proc	format ;
* VISIT が入力されていない場合、Visit名を定義する ;
	value visitf
		-1			=	'Scr'
		0			=	'Pre'
		120			=	'120min'
		7000		=	'Day7'
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
%readds		( lb , lbstresn ne . ) ;	* ボックスプロットなので数値データのみ ;

proc sort	data	=	lb1 ;
	by	lbgrpid	lbcat	lbspec	lbtest	lbstresu	visitnum ;
run ;
proc sgplot data	=	lb1 ;
	by		lbgrpid	lbcat	lbspec	lbtest	lbstresu ;
	vbox	lbstresn	/category	=	visitnum ;
	label	lbcat	=	'Category'
			lbspec	=	'Specimen'
			lbtest	=	'Test'
			lbstresu	=	'Unit'
			;
	format	visitnum	visitf. ;
run ;
ods	pdf	close ;
