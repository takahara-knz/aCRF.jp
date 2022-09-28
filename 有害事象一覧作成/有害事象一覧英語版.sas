/****************************************************
 * SDTMデータから英語版の有害事象一覧表を作成する   *
 * 有害事象名はMedDRA LLT-Jで表示する               *
 * 			S.Takahara Kanazawa University Hospital	*
 ****************************************************/

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力Excelファイルをoutfに割り当てる
 ****************/

%let	sdtm	=	T:\Projects\XXXX\41.Data\sdtm\csv ;
%let	outf	=	C:\Output\aeliste.xls ;

options	mprint ;
options	missing	=	' ' ;
title ;

/*
 * Macro Codes
 */
* SDTMデータ読み込み・・・domain名+0は読み込みそのまま、domain名+1は選択後 ;		
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
%readds		( ae , AETERM ne '' ) ;
%readds		( dm , usubjid ne '' ) ; 

proc sort	data	=	ae1 ;	* usubjidと発現日でソート ;
	by	usubjid	aestdtc ;
run ;

proc sort	data	=	dm1 ;
	by	usubjid ;
run ;

data	ae2 ;
	merge	dm1
			ae1(in=a) ;
		by	usubjid ;
*	if	a ;				* 有害事象発現のみをリストにする場合。有害事象のない症例を「N/A」と表示させるのであれば、ここはコメントアウト ;

	keep	usubjid	age	sex	arm	
			aellt	/* aehlt	aesoc */
			aeser
			aetoxgr
			aerel
			aeout
			;

	label	usubjid		=	'Subject ID'
			age			=	'Age'
			sex			=	'Sex'
			arm			=	'Arm'
			aellt		=	'Adverse event name (LLT)'
			aeser		=	'Serious'
			aetoxgr		=	'Toxicity Grade'
			aerel		=	'Causality'
			aeout		=	'Outcome'
			;
run ;
proc sort	data	=	ae2 ;
	by	usubjid ;
run ;
/*
 * 出力用データセット
 */
data	output ;
	format	usubjid
			age	
			sex	
			arm	
			aellt
			aeser
			aetoxgr
			aerel
			aeout
			;
	set		ae2 ;
		by	usubjid ;
	if	not	first.usubjid	then	do ;
		usubjid	=	' ' ;
		age		=	' ' ;
		sex		=	' ' ;
		arm		=	' ' ;
	end ;
	if	aellt eq ' '	then	aellt	=	'N/A' ;
run ;
/*
 * Excel表示
 */
filename	outf	"&outf" ;
ods html 	file	= 	outf
			rs		=	none
			style	=	minimal ;
proc print	data	=	output	label	noobs ;
run ;
ods	html	close ;
