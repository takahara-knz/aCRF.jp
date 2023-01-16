/****************************************************
 * SDTMデータから日本語の有害事象一覧表を作成する   *
 * 有害事象名はMedDRA LLT-Jで表示する               *
 * 			S.Takahara Kanazawa University Hospital	*
 ****************************************************/

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② MedDRA-Jのllt-j.ascが格納されているフォルダをMedDRAfに割り当てる
 ③ 出力Excelファイルをoutfに割り当てる
 ****************/

%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ ;
%let	MedDRAf	=	R:\02.General\51.システム関連\21.辞書\MedDRA 22.0\ASCII\MDRA_J220 ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop\aelist_j.xls ;

options	mprint ;
options	missing	=	' ' ;
title ;
/*
 * Formats・・・プロトコールや選択肢に合わせて適宜修正
 */
Proc format ;
	value	$aerelf
		'NOT RELATED'	=	'関連なし'
		'RELATED'		=	'関連あり'
		;
	value	$aeoutf
		'RECOVERED/RESOLVED'	=	'回復'
		'RECOVERING/RESOLVING'	=	'軽快'
		'NOT RECOVERED/NOT RESOLVED'	=	'未回復'
		'RECOVERED/RESOLVED WITH SEQUELAE'	=	'後遺症あり'
		'FATAL'					=	'死亡'
		'UNKNOWN'				=	'不明'
		;
	value	$sexf
		'M'		=	'男'
		'F'		=	'女'
		'UNKNOWN'	=	'不明'
		;
run ;

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
*	if	a ;				* 有害事象発現のみをリストにする場合。有害事象のない症例を「発現なし」と表示させるのであれば、ここはコメントアウト ;
run ;

/*
 * MedDRA-JのLLTを読み込み・・・英語版なら不要 ;
 */
PROC IMPORT OUT= WORK.LLT_J 
            DATAFILE= "&MedDRAf\llt_j.asc" 
            DBMS=DLM REPLACE;
     DELIMITER='24'x; 
     GETNAMES=NO;
     DATAROW=1; 
     GUESSINGROWS=max; 
RUN;

/*
 * MedDRA-Jとマージ
 */		
proc sort	data	=	ae2 ;
	by	aelltcd ;
run ;

data	ae3 ;
	merge	ae2(in=a)
			llt_j(rename=(var1=aelltcd)) ;
		by	aelltcd ;
	length	aesertxt	$ 100 ;
	if	a ;
* 重篤テキスト ;
	if		aeser eq 'N'	then	do ;
		aesertxt	=	'非重篤' ;
	end ;
	else if	aeser eq 'Y'	then	do ;
		if aesdth eq 'Y'	then	%aesertxt ( '死亡' ) ;
		if aesdisab eq 'Y'	then	%aesertxt ( '障害' ) ;
		if aeshosp eq 'Y'	then	%aesertxt ( '入院/入院延長' ) ;
		if aeslife eq 'Y'	then	%aesertxt ( '生命を脅かす' ) ;
		if aescong eq 'Y'	then	%aesertxt ( '子の奇形/障害' ) ;
		if aesmie eq 'Y'	then	%aesertxt ( 'その他障害' ) ;
	end ;

	keep	usubjid	age	sex	arm	
			aellt	/* aehlt	aesoc */
			var2
			aesertxt
			aetoxgr
			aerel
			aeout
			;
	rename	var2	=	AELLT_J
			;
	format	aerel	$aerelf.
			aeout	$aeoutf.
			sex		$sexf.
			;
	label	usubjid		=	'登録番号'
			age			=	'年齢'
			sex			=	'性別'
			arm			=	'割付群'
			var2		=	'有害事象名(LLT)'
			aesertxt	=	'重篤'
			aetoxgr		=	'最悪時グレード'
			aerel		=	'因果関係'
			aeout		=	'転帰'
			;
run ;
proc sort	data	=	ae3 ;
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
			aellt_j
			aeser
			aetoxgr
			aerel
			aeout
			;
	set		ae3 ;
		by	usubjid ;
	if	not	first.usubjid	then	do ;
		usubjid	=	' ' ;
		age		=	' ' ;
		sex		=	' ' ;
		arm		=	' ' ;
	end ;
	if	aellt_j eq ' '	then	aellt_j	=	'発現なし' ;
	drop	aellt ;
run ;
/*
 * Excel表示
 */
filename	outf	"&outf" ;
ods listing close ;
ods html 	file	= 	outf
			rs		=	none
			style	=	minimal ;
proc print	data	=	output	label	noobs ;
run ;
ods	html	close ;
