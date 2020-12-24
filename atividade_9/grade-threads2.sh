#!/bin/bash
# Usage: grade dir_or_archive [output]

# Ensure realpath 
realpath . &>/dev/null
HAD_REALPATH=$(test "$?" -eq 127 && echo no || echo yes)
if [ "$HAD_REALPATH" = "no" ]; then
  cat > /tmp/realpath-grade.c <<EOF
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char** argv) {
  char* path = argv[1];
  char result[8192];
  memset(result, 0, 8192);

  if (argc == 1) {
      printf("Usage: %s path\n", argv[0]);
      return 2;
  }
  
  if (realpath(path, result)) {
    printf("%s\n", result);
    return 0;
  } else {
    printf("%s\n", argv[1]);
    return 1;
  }
}
EOF
  cc -o /tmp/realpath-grade /tmp/realpath-grade.c
  function realpath () {
    /tmp/realpath-grade $@
  }
fi

INFILE=$1
if [ -z "$INFILE" ]; then
  CWD_KBS=$(du -d 0 . | cut -f 1)
  if [ -n "$CWD_KBS" -a "$CWD_KBS" -gt 20000 ]; then
    echo "Chamado sem argumentos."\
         "Supus que \".\" deve ser avaliado, mas esse diretÃ³rio Ã© muito grande!"\
         "Se realmente deseja avaliar \".\", execute $0 ."
    exit 1
  fi
fi
test -z "$INFILE" && INFILE="."
INFILE=$(realpath "$INFILE")
# grades.csv is optional
OUTPUT=""
test -z "$2" || OUTPUT=$(realpath "$2")
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Absolute path to this script
THEPACK="${DIR}/$(basename "${BASH_SOURCE[0]}")"
STARTDIR=$(pwd)

# Split basename and extension
BASE=$(basename "$INFILE")
EXT=""
if [ ! -d "$INFILE" ]; then
  BASE=$(echo $(basename "$INFILE") | sed -E 's/^(.*)(\.(c|zip|(tar\.)?(gz|bz2|xz)))$/\1/g')
  EXT=$(echo  $(basename "$INFILE") | sed -E 's/^(.*)(\.(c|zip|(tar\.)?(gz|bz2|xz)))$/\2/g')
fi

# Setup working dir
rm -fr "/tmp/$BASE-test" || true
mkdir "/tmp/$BASE-test" || ( echo "Could not mkdir /tmp/$BASE-test"; exit 1 )
UNPACK_ROOT="/tmp/$BASE-test"
cd "$UNPACK_ROOT"

function cleanup () {
  test -n "$1" && echo "$1"
  cd "$STARTDIR"
  rm -fr "/tmp/$BASE-test"
  test "$HAD_REALPATH" = "yes" || rm /tmp/realpath-grade* &>/dev/null
  return 1 # helps with precedence
}

# Avoid messing up with the running user's home directory
# Not entirely safe, running as another user is recommended
export HOME=.

# Check if file is a tar archive
ISTAR=no
if [ ! -d "$INFILE" ]; then
  ISTAR=$( (tar tf "$INFILE" &> /dev/null && echo yes) || echo no )
fi

# Unpack the submission (or copy the dir)
if [ -d "$INFILE" ]; then
  cp -r "$INFILE" . || cleanup || exit 1
elif [ "$EXT" = ".c" ]; then
  echo "Corrigindo um Ãºnico arquivo .c. O recomendado Ã© corrigir uma pasta ou  arquivo .tar.{gz,bz2,xz}, zip, como enviado ao moodle"
  mkdir c-files || cleanup || exit 1
  cp "$INFILE" c-files/ ||  cleanup || exit 1
elif [ "$EXT" = ".zip" ]; then
  unzip "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.gz" ]; then
  tar zxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.bz2" ]; then
  tar jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.xz" ]; then
  tar Jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".gz" -a "$ISTAR" = "yes" ]; then
  tar zxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".gz" -a "$ISTAR" = "no" ]; then
  gzip -cdk "$INFILE" > "$BASE" || cleanup || exit 1
elif [ "$EXT" = ".bz2" -a "$ISTAR" = "yes"  ]; then
  tar jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".bz2" -a "$ISTAR" = "no" ]; then
  bzip2 -cdk "$INFILE" > "$BASE" || cleanup || exit 1
elif [ "$EXT" = ".xz" -a "$ISTAR" = "yes"  ]; then
  tar Jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".xz" -a "$ISTAR" = "no" ]; then
  xz -cdk "$INFILE" > "$BASE" || cleanup || exit 1
else
  echo "Unknown extension $EXT"; cleanup; exit 1
fi

# There must be exactly one top-level dir inside the submission
# As a fallback, if there is no directory, will work directly on
# tmp/$BASE-test, but in this case there must be files!
function get-legit-dirs  {
  find . -mindepth 1 -maxdepth 1 -type d | grep -vE '^\./__MACOS' | grep -vE '^\./\.'
}
NDIRS=$(get-legit-dirs | wc -l)
test "$NDIRS" -lt 2 || \
  cleanup "Malformed archive! Expected exactly one directory, found $NDIRS" || exit 1
test  "$NDIRS" -eq  1 -o  "$(find . -mindepth 1 -maxdepth 1 -type f | wc -l)" -gt 0  || \
  cleanup "Empty archive!" || exit 1
if [ "$NDIRS" -eq 1 ]; then #only cd if there is a dir
  cd "$(get-legit-dirs)"
fi

# Unpack the testbench
tail -n +$(($(grep -ahn  '^__TESTBENCH_MARKER__' "$THEPACK" | cut -f1 -d:) +1)) "$THEPACK" | tar zx
cd testbench || cleanup || exit 1

# Deploy additional binaries so that validate.sh can use them
test "$HAD_REALPATH" = "yes" || cp /tmp/realpath-grade "tools/realpath"
cc -std=c11 tools/wrap-function.c -o tools/wrap-function \
  || echo "Compilation of wrap-function.c failed. If you are on a Mac, brace for impact"
export PATH="$PATH:$(realpath "tools")"

# Run validate
(./validate.sh 2>&1 | tee validate.log) || cleanup || exit 1

# Write output file
if [ -n "$OUTPUT" ]; then
  #write grade
  echo "@@@###grade:" > result
  cat grade >> result || cleanup || exit 1
  #write feedback, falling back to validate.log
  echo "@@@###feedback:" >> result
  (test -f feedback && cat feedback >> result) || \
    (test -f validate.log && cat validate.log >> result) || \
    cleanup "No feedback file!" || exit 1
  #Copy result to output
  test ! -d "$OUTPUT" || cleanup "$OUTPUT is a directory!" || exit 1
  rm -f "$OUTPUT"
  cp result "$OUTPUT"
fi

if ( ! grep -E -- '-[0-9]+' grade &> /dev/null ); then
   echo -e "Grade for $BASE$EXT: $(cat grade)"
fi

cleanup || true

exit 0

__TESTBENCH_MARKER__
‹      í<]wÛF®yÖ¯@5¦d‰’ü·väÆµ•Ô­cçÚNÛs-W¦Å‘Ì†"U~ØNÿ˜=û°ç>ìÓý	ùc˜’CŠ²7Iw÷jNŽ%À ˜(!Âsæö/>[kb[[]¥ÏÖÚjSýŒÛƒÖòêêê“µµæRëA³µ´Ò\y «Ÿ¥´EAhú L‡]ÛÁt¸YïÿM[˜è?ô<'ø,Vðñú_^]™ëÿ‹´¼þ¯|s\Dn?´=÷Mw–þWž´rú²²ºô šŸføÛÛÿsý?zØ8·ÝÆ¹\”~>ÜzµwtÜ{¾»×i—[¥ç»‡GÇíViàù0°¶åg`y% { 'Pæ Pg¿CN7 ¼`.¾“oB} e•j€õ/<Ðžé,˜ë…0ð"×z¨Å ×v-þ0°Åq…†êš#Á™Þ7CÐ2„´Šä–ZÆ´¡œàješœÈò\†_˜0þ,DÐ,ñQùË¿ZaŸ¸Ýºþþ'ƒÖøtèÅëƒýêr~ý¯¶Zóõÿ%Ú#Ûí;‘ÅàiZ¶g\l–Ô.ßv‡ù>Ë±Ï³}>²kê*Ùnþu¯ïÆ¸¦tþ¢VÁ
Âô1¢„Ð¿0ý*U6Jò+3­-A]›á‚p‚lì˜}…šÏjª
‚Åm?bn()\ùvÈŠÇÈ¢†ìšp8ÒÈ´]¾˜þ°Ÿˆ—x{9^ÂÃ6,ÇÔÆÈT8Ðµ×9dëðU ‰ß!&º®Vã„Nš§8ZŒå³0ò]h‰ž›’`¾mhŠ~âªù}ÖÞ½·Wƒ*Š¥èôˆ}¥/¢áÓNŸƒ“ bp›ôX)qôk¯Gl°Pœ¼†f
ûæ
beU* œ@­”Ã6°'XÎèÌ[(

gÅPZÝn«×#¯ÕÓ6
—¸Û]Ú œòÐe
ï´xþ’
|¡s¸Jßt¯¯·jdzsuÎPãg®×Öi%Që”¶¨Xú³–‰@«’ªmy4F¶¦?~«'3©Ažañ,038ø Í¹™äoF~>âùÓÒ_®ä§ŸÚNjÉ¼'1˜	KQ­Cv¥¸÷ÐxJåšò¥”‘
Gzæ ^ÒŠˆH¿žtC8­ê'fý­ú7ëßôª§UÑYÔ×íVÅ·ÅJ^¨z·«Ÿüúî´Zév“õ¤ø©ð´2MÀê0_NÄÜ[cDÐ…»VÂàcÕ&œU*éz¡}‡™n4.V7šœ¶P¾B'½Ó	ñÇŠD-ÔºÝJ	ŸWé8ÿ*J¡'ÃÛl5P‚ÀÕ…‡ûw)*{p¸õ’ƒÈ¾¶’Épv—N†b 6PxU“Áikc
Ôs“²ÂS°ØÀvmžPèHÝtßV’‘ât)µºÇbðZÏ*ðšÓæ‹‹*¸})Ød ÔÅÝe¤À¼d´\§”ŠDÉÚ¤<kRÖÜ¡I*ëb7è3–Y÷Rôq¿¢oõE"¥Sá=É‚ø‹X ÝG%’ðI=œgw4µo¡ë”ÏÝ|\Æ§"%œ4v6$2:Gõ¯kpØyÑëürÜÙßéì¼§‡ýÎÏ{»û4yÅþˆeb‚’ò|"X,ˆô°©¤©‚„èGD	×A$[™tv‚˜D™ŸçË‚—nÓz‘RþÌ3f‰]Q×D*U.Í™;
9o:¨Â€¼ÈÀsD[Í×b%Œ½Ñcž§u:?öPŠò1I1º¥axABæ8€ÀSq:Ç™Ôg1`~‘÷D9’v%ðãÇdY¦%Ÿk@×p"ò,MU­Ü¬"édä4É‚ô/`é$¤`|b©·‘š!ì+M™%½žôi¸ëäV¤m{‘cñó!¢[†Ü,¦–—ÝH)‹&ÝGÑ |BºˆQiðãÜs±¦ž+ã¦'
.•ç¤GÄ¡2}"ûXfhÂ•p©†8t“ÊYøŸÝ+>Dé¹à·7ô½hp—PßôYÏ
¢óÄíÌ°Aã&PºÒ[sº»“oP¢1áÄÀéOßõušH5žB
\“#‘#â†¾‹‹*ûªÍ4-ð"šáï‘í3Îß†Â¼>Æó¶¤¬D¹®¤vl’#žë¤VÆYÏˆyÌå•pµÛì1çt¬òÛGÕç&¿Ðí.ä_ÇzÚÖ5Ò¬	¨ÃBsac.aw±-¥tBh§†?ê1±ò—%rÃ;8 Ú9„Òä7Œâcßë³ P%—pÆ­"ÿ8oH\!®ØÎ
ŠµÈi6åIY¹®O«º‡ÓUWÕ‘ÛÅÅ
©ÎßQÚwÕ7Á¡QÂ=µM-+K|JÄ˜
M!ÀãÉ?f[Âíd›’ÓZ~mÕs Š(¹hLïÊÆÈA6äÅSü)Ñ°•	|„$Ïz\Õ¿ëý«j?KËŸÿ}Óbõ+Ó?Ý3îÿ––&îWW[Íùùÿ—hêýß«ÝºöÛéìoµËK¥íƒ×ûÇíò²øÒÛ;ØÑ.¯”žw:;ßmmÿØ.¯–È| î‚VŽ{5xÿ†Å.nä8¥’caÏbAŸ¹–‰Kª‡Ñ%èÂ¢÷7ôÅ¶cùÌm—uÌ*êŒm«
õú?qˆ–Fùùnz¦+¿!¹åË‚XKw{òfO0üöÇ¸œaq™öárŸ ³Z8ânÖ<‚ûÍ!àîIº(a¤±lqA°ß¡Ì•ß‹cc(s•ã#q‹h°™¨ŽÈžãÎã¸ ¥ø7°’Üî
y¾ò‚àÃ?/™¡=b< °`Ì|Óµ<º^	 ÁØ‹úžaš”Ë¯ÜðÒ‹ÜË3™N$v'ÆcÖÃ/
üƒÒE™3¨›ª±+?}ø'ÎÒÖ‘ù	Û!
ýÆÆëßL…Êaïx$Gy‰{’^€™Ö‡¿{ZŠ7Â4IA-6¾J!ÜÇ]xX˜p…^ MÐo6!(â%æ?¹¿Ø¥
PâÍÿÌ úoÔŠã?Z~}Äü!ó?Å³âÿòZ>þ?y²2¯ÿù"Mÿ¥‡[;ÞÁëc^ý#}œx^*•xM8	œ¦ôH—`åÚÜŽh£1Æ½¯¯ÙÀu¯ÐPÉO'3`Ì:7ûon£¤pƒ^êÄå­|¹)¸ìÑv(¨'Ž
‚È	ù1íjÇžÏOÚOà¤øÍ)†/8%÷.ÝòWJnü‡,¬ã^3¤ý°Ì!¾ë¼ØÝïía~0Ä]Ô;ó´gÏž=zô¨ÜZ×p
KpúÈL} -¨[ëøxÁL‹²­V%I (õ’Ôxü¾ ³¿Ã‡MÛ!ÀÅ²®Ç°‹­J%d’…“_×O«ë³ øHZ¦¸kÖ 1%zÍÑë1?rK
°n¥£D_M„Ìwüqœ³ÒÏßoQ)[ç—W‡ífšiågZ¦ àè˜/3Ž¼ÄÙÊ@-MB-«Ìg€—sÅoœ”~àö-A1±z´²­Uâ8õu²*`ssbº\01Ù±ª€Hbç+
é¸!¥\>~,f²Bæ”Ì).>­Ê¼Âá¹Bà8Û„®ö•±4èj5à#Ý`ªË% •¿Å¥é²L PQ Š™E‡Ÿtð…	q]ßYŠ”–›Ya2g×å' Ó
X½A£k4›Æp¡¢ÁfÆQ”æy‡liü?öíóÈ5cì1~3/ÍO6ÆŒú¿•æÊj~ÿÿdmyÿ¿D£Áhˆ{%#}ÃíKÛBïó
UÁ(Àç
/˜+tä¹á˜îpÙ ]qzãŸé€C…ÿ-ríÐ¨ô±kÜÚtªf:†¹.ó£ãò« ^€‡‘û³^¤\‘‰Qh;Æ–ï›o÷p3µ1ùnÛs&ŠÙÞNA:8ÿ
qŠÐ÷#wÖêÜ
_›¡7²ûÆÿØE¿=¤k´.´ûR7^‰StÏ8¶Çž2ˆÄàc‘ôQî¼8CÙÈÁò0‚·¸Ð}Ïµÿ`–˜zé™”«kÀè;fTJãèÜABü	Tß ®å{9ž ;2Qao³u—&:ôBùEWP{¶5™Ÿ¢º—î<Cfú;Þ•‹YSˆ|_Ð¹î³1Ïª²è›¨Ÿã†™îÉ)ÝªáÄ0ž½˜o²ÇÖ1Ý9E¡çAt>²CÝeW€x®yî0½èdÿÙÁ%ó}ÛboT¾Ñd±ÅØo§¼¡v|AW¼?ãÐ—›êµ»Ún O+t2,ßÆ!³RÑØC×£+xwSˆ-„sÒ<Eù„~Ä&ÇÈâÝT¦ˆO\zæÞnóÑþùÇ1’×µã¸þî‰£ /‚à"
-Ô2¦a+UïP§¾V›*«Üdf²1©u;8’cë•{¡.Qú7ŠuÓ’Ñåñ¥Œñ*SŒ=;îï‹˜uÈð3ƒÔðcyç>ë›èc†¦åM[1¯8 ™ôK¯ÿ&&@—l­lAÇŒùþ9CÓçk#vNúZ
¾?x¹»½»³{P¹UvÏiýÝNlµ{[Ç‡Û»û9j7%EœEçyä8ÿE"ƒ¯#!7’¡‡áf'òM.­6ìa§ñrë—ÞO[{¯;ÓpÉK>%ØMÜYQPˆIÐ¥wÞòY%ÁèéfÆ&r„Eùõv0~ˆ¬a|/ÃÅ]ùûN¸½M¹o
¤Ö3œ ÃMmò;†Qƒm“ó¦(ér‹Xøz¬ú^²{œ{bu5(ò?5‡§Ó¬³#P` ›GÄ&ü^üB¯¨yÛtrÈOB¦6ïç–	è–yv(‰›)êÒ¹uY-Õ`WVsªÏŽ'wÄüK»ÏÐÕ!™Œ(¶)Å²„(^¡Nóž5n\§Ï#Üè³D÷›0àS”_D&IÜèp…ùGWˆšô}ä"dG˜sïVL‚ß£“)Û¼~?žÂ×øAwßÓƒœ,G£ Žµß‚]]ƒuh-êöWk•êrñœ€˜ªaZ–Î®m%–ËÔ8·é¦£6iF’jlI·S¦–Ê8¸‡xÕv{Þ 6yt«Ëµ­<}x|÷ÝE-É6f!v‘3¾”+2¸2†,$×1ŒgÌ”®pî0‹[!¦¿½™ÆM1
_¹Å)
[Zn%vÕ|æ¢“f?uæùð%Wl*±b´©&1ŽbÁ‹’¤gx¹5ý‹ÛŸÌ¿>ŽL.+¤t«±ä^.€¯«äÎa‘'m"ª½¦éËÝ½½Ý£ÎöÁþÎÑ”¬ïifXe“Ëßî˜­ˆye×•Eûy­Ü'ÕÄ…™NÍ§¸SSZbÏÑMšcÛò&¦jyˆÀÀ¼õ9Ù¹º9Ât ·3QŸéÍ½—ÅúzŠ Õ ]¬LRÃDí»•ç¶câæ$Ä-4`@¶ñ!®móÀb#6-£È=úÕ‰i’,Îp@Z"vÆ¤‹6
’w€6fÙfh’~X
õ€Ã.q@mýE.ÂEÐF1mÓDOamµyEþ@a„Øò‚ÎèNÜaÎ¤:ÖkÆ–1?ˆWÕ7©ÒldýëÆRåcL1ü§¸»ùz@E3µdq¢²Ñ¦bÛxý$†<°Ôº.O˜Ö×í`RÅè{‘æ“ÿø´OÑ•“Lˆq;†z2Ü-BèüáL©ÔàÉm"“Ð1ÝZNHŠ¨rû±Ë$ËôûL×Jw®4^QnÚáË`#/q‘#fNÏ¦;1žðª z³`çUD²ÿôò,fÒ^5ýC„š	j|^¸„É‘Ô”Iæ-&ˆÆH:Á’ùÃ–;0>ý$&'-Õp'YtZ¡0Çó8o½`ý7/"´Á·zœ&¾-Ï^lÛÅÄ•¾n¹Ö6a°ÅIjæPKŠ"_{Ÿó,’ì¥éDôË•"f-–cv±5¹¾ë¥yÍÇr[*¤â]]Ðý¯.ÆÞŒIq`Š¢£ty;Â$š˜P¥"Š—&•û°›•šÌƒb­Â.¦Mð¬‰Òú‰óW_RÌÛgkéýžm¡Ÿ4‚‹O<ÆŒúŸÕæÄÿÿ³²ºüd~ÿ÷%šZÿÓ·À0Jý1¤FQå7Áøýu6è©qî7èÖª‘ÞZ5”rºŽ¯'
”&Éügie:@¸~æåOûíÑ¥+K{€ß¯ºŽ|áw¥x€ ½/ÑïCFž‹×þý{~§A	K–W'|™²•›¸y¼I†¨,ÂþÃÎq»ümI–mhe|ž,[ ŠTY<ÈMY‹…
eiJây‰0ª<‚moÄ>üÃ¤ºøƒùž(ihbHIÄKAÄ‹º›yÈ+³Ò¶‡Ï²/"½ø=i¶"Wá£?R™â*F@{Q³Áº®m€¬ÐŒ+-–&Ù‚G	fI–cz/	%H Fi%.ÚòÞ<uæ%×þâ@Tš6%h­6ÿMÎU-1ìÉ*—ãÎÑñQ{¿uÅ—ç[»{Güÿn:úq÷Õ«ÎÿN€¿¼ÜkãªÇÈ×"Ÿ
lŸÕ}F÷§AƒÞ×îe3å×#'¶þŸ\¡Î%ÝlTNèÇB(ú%îýâ+˜mŽ(1â–j&ø(Aß€ï?ü
LgèÉ&fE¸ëà%fôó!N]Ì™J¥©”ŠW¼üjTIhA[ÓOšõoN+šQ-7º­ÆîxAaRl¹¤òèü'»wÃÎ «§3®;‘ˆ5“'¼±ÇcfÝ_YùH31“”9Ÿ|5€Æ	e9*ÈQHª¢Bjiñëª®súGuN¥.°ë1N¥!Þòº¬µPËÃL-TâX
ª¡>¦*[L©*ðTŠ(ÇÕ“ò½‰…œ©š
ª²hª
Z«©Z4ù¾§O:ÏŠÙÀ¨×
ñwÊé¶®ø[ðQ9¾1¢Ñ‹ÿLyg]ñ‡Ïêõ)ì¼ï6{
à°Õë5ÎW¯DükÔ8	ßiÓÏ ‚¶QRÞui¨úB‚w+_Kø€ÿMk³üû©€F¯×3ê D¡00t%¤:´)œÒÊ íRÄ™AâËr!ÄŽÄÎ“PkÈ‰»Á)ê9ÆÏ¤®Î$	ùºv–â üY=Ià÷Ý”îûn†ÐÀX8«oàç‚ ®€ÔÉÉXˆ¡‘ÛÂ¨ãËúÆÙY°± ßêp¦¡:q|]Ì	(F>ª>ÓÎÉ”Ââ™‘y·p–3Æ³…2šä ~„P:à<þ‡ÿ¡¢ˆ±9ö cµÏúÍF´=£‹
0¹¡CCÊ‚cŠçDþ½„+4ŽŒÂ±lÙ®%‚=…ä0¸Œ™ %ÏÅåiÚèv0ö|øßk{Dõá‡¿
mï[ç "ÜÎ'çmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞæmÞþõÚÿ(gåŽ x  J����r��@�'��|����A��9�7�x�]N.۲-۲-۲-۲-۲-۲-۲-۲-۲-۲-۲-۲-۲-۲-۲����O x  