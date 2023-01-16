/****************************************************
 * SDTMデータから英語版の有害事象一覧表を作成する   *
 * 有害事象名はMedDRA LLT-Jで表示する               *
 * 			S.Takahara Kanazawa University Hospital	*
 ****************************************************/

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力Excelファイルをoutfに割り当てる
 ****************/

%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop\aelist_e.xls ;

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
%macro	aesertxt ( plustext ) ;
	if	length ( trim ( aesertxt ) ) le 1	then
		aesertxt	=	&plustext ;
	else
		aesertxt	=	trim ( aesertxt ) || ', ' || &plustext ;
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
	length	aesertxt	$ 200 ;
*	if	a ;				* 有害事象発現のみをリストにする場合。有害事象のない症例を「N/A」と表示させるのであれば、ここはコメントアウト ;

* 重篤テキスト ;
	if		aeser eq 'N'	then	do ;
		aesertxt	=	'No' ;
	end ;
	else if	aeser eq 'Y'	then	do ;
		if aesdth eq 'Y'	then	%aesertxt ( 'DEATH' ) ;
		if aesdisab eq 'Y'	then	%aesertxt ( 'DISABILITY/INCAPACITY' ) ;
		if aeshosp eq 'Y'	then	%aesertxt ( 'HOSPITALIZATION' ) ;
		if aeslife eq 'Y'	then	%aesertxt ( 'LIFE THREATENING' ) ;
		if aescong eq 'Y'	then	%aesertxt ( 'CONGENTIAL ANOMALY/BIRTH DEFEAT' ) ;
		if aesmie eq 'Y'	then	%aesertxt ( 'OTHER SERIOUS EVENT' ) ;
	end ;

	keep	usubjid	age	sex	arm	
			aellt	/* aehlt	aesoc */
			aesertxt
			aetoxgr
			aerel
			aeout
			;

	label	usubjid		=	'Subject ID'
			age			=	'Age'
			sex			=	'Sex'
			arm			=	'Arm'
			aellt		=	'Adverse event name (LLT)'
			aesertxt	=	'Serious'
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
