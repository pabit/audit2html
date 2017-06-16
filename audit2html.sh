#!/bin/bash

#=============================================================

#    audit2html supports customized audit log 
#    parsing and display through plugin check files.
#    Output report and log based on cft2html output
#
#    cfg2html Copyright (C) Ralph Roth
#    audit2html Copyright (C) 2017 Damian Mehsling
#
#    This program is free software: you can redistribute
#    it and/or modify it under the terms of the GNU General #    Public License as published by the Free Software         #    Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be #    useful, but WITHOUT ANY WARRANTY; without even the implied #    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR #    PURPOSE.  See the GNU General Public License for more
#    details.
#
#    You should have received a copy of the GNU General Public #    License along with this program.  If not, see <http://
#    www.gnu.org/licenses/>.
#
#    See Copying for License
#===============================================================
declare -f exec_command
declare -f heading
declare -f increase_heading_level
declare -f decrease_heading_level

RUNDIR="$(dirname $0)"
CONFIGFILE=./audit2html.conf
DATEFULL=`date "+%Y-%m-%d %H:%M:%S"`

if [ -f $CONFIGFILE ]; then
    . $CONFIGFILE
else
  echo "unable to source configuration file: $CONFIGFILE"
  exit 1
fi


DISPLAY_VERSION_=`echo $DISPLAY_VERSION/$HOSTNAME|tr " " "_"`

VER="v1.0"
DISPLAY_VERSION="audit2html version $VER"


usage() {
  echo
  echo "    Usage: `basename $0` [OPTIONS]"
  echo "    creates a HTML and plain ASCII audit report"
  echo
  echo "    -o      set output directory or use the environment"
  echo "            variable OUTDIR=\"/path/to/dir\ in"
  echo "            $CONFIGFILE (directory must exist)"
  echo "    -h      display this help and exit"
  echo ""

}


while getopts ":o:h" Option 
do
  case $Option in
    o     ) OUTDIR=$OPTARG;;
    h     ) echo $DISPLAY_VERSION; usage; exit 0;;
    *     ) echo "Unknown option. Use -h for help!"; exit 1;;  
  esac
done

shift $(($OPTIND - 1))

line () {
echo " "
}


if [ `id -u` = "0" ] && [ "$SUDO_UID" = "" ]; then 
      echo -e "You must run this script with sudo"
      echo -e "Separation of duties requires a non-administrator auditor"
      line
     exit
fi



mkdir -p $OUTDIR/$FILENAME  

HTML_OUTFILE="${OUTDIR}"/"${FILENAME}".html
HTML_OUTFILE_TEMP=./"${FILENAME}".html.$$
TEXT_OUTFILE="${OUTDIR}"/"${FILENAME}".txt
TEXT_OUTFILE_TEMP=./"${FILENAME}".txt.$$
ERROR_LOG="${OUTDIR}"/"${FILENAME}".err

if [ ! -d $OUTDIR ]; then
  echo "can't create $HTML_OUTFILE, "${OUTDIR}"/"${FILENAME}" already created - stop"
  exit 1
fi



touch $HTML_OUTFILE
[ -s "$ERROR_LOG" ] && rm -f $ERROR_LOG 2> /dev/null

exec 2> $ERROR_LOG

if [ ! -f $HTML_OUTFILE ]; then
        echo "ERROR"
  line
  echo -e "You do not have permissions to create the file $HTML_OUTFILE! \n"
  exit 1
fi

logger "Start of $DISPLAY_VERSION - $COMPLIANCE"

typeset -i HEADING=0                     


######################################################################
#  Increases the heading level
######################################################################

increase_heading_level() {
HEADING=HEADING+1
    echo -e "<UL type='square'>\n" >> $HTML_OUTFILE
}

######################################################################
#  Decreases the heading level
######################################################################

decrease_heading_level() {
HEADING=HEADING-1
echo -e "</UL>" >> $HTML_OUTFILE
}


####################################################################
#  Header of HTML file
####################################################################

open_html() {
UNAME=$(uname -a)
echo -e " \
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML> <HEAD>
<style type="text/css">

Pre     {Font-Family: Courier-New, Courier;Font-Size: 10pt}
BODY        {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif; FONT-SIZE: 12pt;}
A       {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif}
A:link      {text-decoration: none}
A:visited   {text-decoration: none}
A:hover     {text-decoration: underline}
A:active    {color: red; text-decoration: none}

H1      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 20pt}
H2      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 14pt}
H3      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 12pt}
DIV, P, OL, UL, SPAN, TD
        {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 11pt}

</style>

<TITLE>${HOSTNAME} - Audit Report - $DISPLAY_VERSION</TITLE>
</HEAD><BODY>
<BODY LINK="#0000ff" VLINK="#800080">
<H1><CENTER><FONT COLOR=blue>
<P><hr><B>$HOSTNAME - Audit Reduction and Report</P></H1>
<hr><FONT COLOR=blue><small>File: "$HTML_OUTFILE"</font></center></B><P>$UNAME<P>$COMPLIANCE
</small>

<HR><H1>Report\n</font></H1>\n\
" >$HTML_OUTFILE


  echo
  echo "                       "$HOSTNAME > $TEXT_OUTFILE
echo -e "\n" >> $TEXT_OUTFILE
echo -e "\n" > $TEXT_OUTFILE_TEMP
}


######################################################################
#  Creates an own heading, $1 = heading
######################################################################

heading() {

if [ "$HEADING" -eq 1 ] ; then
    echo -e "<HR>" >> $HTML_OUTFILE_TEMP
fi

echo "<A NAME=\"$1\">" >> $HTML_OUTFILE_TEMP
echo "<A HREF=\"#Inhalt-$1\"><H${HEADING}> $1 </H${HEADING}></A><P>" >> $HTML_OUTFILE_TEMP

echo "<A NAME=\"Inhalt-$1\"></A><A HREF=\"#$1\">$1</A>" >> $HTML_OUTFILE
echo -e "\nCollecting: " $1 " .\c"
echo "    $1 ---- " >> $TEXT_OUTFILE

increase_heading_level

}

######################################################################
#  Documents the single commands and their output
#  $1  = unix command,  $2 = text for the heading
######################################################################
declare -f exec_command

exec_command() {

echo -e ".\c" 

echo -e "\n---=[ $2 ]=----------------------------------------------------------------" | cut -c1-74 >> $TEXT_OUTFILE_TEMP
echo "       - $2" >> $TEXT_OUTFILE
TMP_EXEC_COMMAND_ERR=/tmp/exec_cmd.tmp.$$
EXECRES=`eval $1 2> $TMP_EXEC_COMMAND_ERR`


if [ -z "$EXECRES" ]
then
        EXECRES="n/a or no events found"
fi
if [ -s $TMP_EXEC_COMMAND_ERR ]
then
   echo "stderr output from \"$1\":" >> $ERROR_LOG
        cat $TMP_EXEC_COMMAND_ERR | sed 's/^/    /' >> $ERROR_LOG
fi
rm -f $TMP_EXEC_COMMAND_ERR


        echo -e "<A NAME=\"$2\"></A> <A HREF=\"#Inhalt-$2\"><H${HEADING}> $2 </H${HEADING}></A>" >>$HTML_OUTFILE_TEMP

        if [ "X$1" = "X$2" ]
            then    : #no need to duplicate, do nothing
        else
                echo "<h6>$1</h6>">>$HTML_OUTFILE_TEMP
        fi


        ###  Put the result out in proportional font
    echo -e "<PRE>$EXECRES</PRE>"  >>$HTML_OUTFILE_TEMP

    echo -e "<LI><A NAME=\"Inhalt-$2\"></A><A HREF=\"#$2\" title=\"$1\">$2</A>" >> $HTML_OUTFILE
    echo "$EXECRES" >> $TEXT_OUTFILE_TEMP

}


AddText() {

echo "<p>$*</p>" >> $HTML_OUTFILE_TEMP
echo -e "$*\n" >> $TEXT_OUTFILE_TEMP

}


BoldText(){

echo -e "\n<br><B>$*</B>"  >> $HTML_OUTFILE_TEMP
echo -e "\n===== $* =====" >> $TEXT_OUTFILE_TEMP

}

######################################################################
#  end of the html document
######################################################################

close_html() {

echo "<hr>" >> $HTML_OUTFILE
echo -e "</P><P>\n<hr><FONT COLOR=blue>Created "$DATEFULL" with " $DISPLAY_VERSION - $COMPLIANCE "</font>" >> $HTML_OUTFILE_TEMP
echo -e "<hr><center> <A HREF=" "</b></A></center></P><hr></BODY></HTML>\n" >> $HTML_OUTFILE_TEMP
cat $HTML_OUTFILE_TEMP >>$HTML_OUTFILE
cat $TEXT_OUTFILE_TEMP >> $TEXT_OUTFILE
rm $HTML_OUTFILE_TEMP $TEXT_OUTFILE_TEMP
echo -e "\n\nCreated "$DATEFULL" with " $DISPLAY_VERSION - $COMPLIANCE " \n" >> $TEXT_OUTFILE
echo -e " " >> $TEXT_OUTFILE
}

#############################  M A I N  ##############################

echo "Starting: $DISPLAY_VERSION - $COMPLIANCE"   

logger "Start of $DISPLAY_VERSION - $COMPLIANCE"
open_html
increase_heading_level

  
    if [ ! -d $AUDIT2HTML_PLUGIN_DIR ]; then
         echo "plugin directory cannot be found"
         exit 1
    else
	   AUDIT2HTML_PLUGINS="$(ls -1 $AUDIT2HTML_PLUGIN_DIR | grep ".check$")"
        for AUDIT2HTML_PLUGIN in $AUDIT2HTML_PLUGINS; do
        if [ -f "$AUDIT2HTML_PLUGIN_DIR/$AUDIT2HTML_PLUGIN" ]; then
             . $AUDIT2HTML_PLUGIN_DIR/$AUDIT2HTML_PLUGIN
             $AUDIT2HTML_PLUGIN_DIR/$AUDIT2HTML_PLUGIN
            decrease_heading_level
         else
            AddText "Configured plugin $AUDIT2HTML_PLUGIN not found in $AUDIT2HTML_PLUGIN_DIR"    
        fi     
        done  
     fi

close_html

########## remove the error.log if it has size zero #######################
[ ! -s "$ERROR_LOG" ] && rm -f $ERROR_LOG 2> /dev/null
####################################################################

logger "End of $DISPLAY_VERSION - $COMPLIANCE"
echo -e "\n"
#line
rm -f core > /dev/null

chown -R root:$AUDITOR_GROUP $OUTDIR
chmod 750 $OUTDIR
chmod 640 $HTML_OUTFILE
line
echo "HTML Output File:  "$HTML_OUTFILE
echo "Text Output File:  "$TEXT_OUTFILE
echo "Errors logged to:  "$ERROR_LOG
line
#echo "run the command - firefox $HTML_OUTFILE - to view report" 
echo "Hit [ENTER] key to exit"
read -p stop

exit 0
