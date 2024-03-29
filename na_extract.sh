#!/bin/bash

# Script to extract specgen information from raw NA specgen input files


# 1. Download specgen
#rm -fr specgen_input_na
#git clone https://github.com/Access4LearningNA/specgen_input_na.git

# specgen is in parameter $1

# 2. Extract all necessary information from specgen into flat files

# process all objects in the specification

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

xsltproc included_objects.xslt $1/06_DataModel/Custom/DataModel-Custom-US.xml | perl -ne 's/\\/\//g; next unless $_ =~ /\S/; next if $_ =~ /<\?/; s/^\s+//; s/\s+$//; print  @a = split("/", $_); print $a[-1] . "\n"' > objs.txt
IFS=$'\n' read -d '' -r -a objectarray < objs.txt

for filename in ./$1/06_DataModel/Custom/US/*.xml; do
  if containsElement  $(basename "$filename") "${objectarray[@]}" ; then
    :
  else
    echo "Excluded:" $filename;
    continue;
  fi
  #if [[  $(basename "$filename") == "StudentScoreSet.xml" ]]; then
    #continue
  #fi
  xsltproc sifobject.xslt "$filename" >> objectgraph.txt
done
for filename in ./$1/06_DataModel/Custom/US/*.xml; do
  if containsElement  $(basename "$filename") "${objectarray[@]}" ; then
    :
  else
    echo "Excluded:" $filename;
    continue
  fi
  xsltproc sifobject.xslt "$filename" >> objectgraph.txt
done
# process all common types in the specification
echo '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xi="http://www.w3.org/2001/XInclude" xmlns="http://sifassociation.org/SpecGen" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xhtml="http://www.w3.org/1999/xhtml" >' > data.xml
cat $1/80_BackMatter/DataModel-CommonTypes.xml >> data.xml
echo '</root>' >> data.xml
xsltproc sifobject.xslt data.xml >> typegraph.txt

# 4. Extract example XML from specgen
mkdir -p test
rm -rf exp
mkdir -p exp
rm -f exp/*.xml
echo "<sif>" > test/siftest.xml
echo "<sif>" > test/siftest_specgen.xml

if [ -d ./$1/06_DataModel/Custom/Common ]; then
  for filename in ./$1/06_DataModel/Custom/Global/*.xml; do
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi
if [ -d ./$1/06_DataModel/Custom/US ]; then
  for filename in ./$1/06_DataModel/Custom/US/*.xml; do
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi

if [ -d ./$1/06_DataModel/Custom/Infrastructure ]; then
  for filename in ./$1/06_DataModel/Custom/Infrastructure/*.xml; do

    # exclude the two gCore dataobjects (for now)
    # job.xml has xsi:type= definition which isn't handled when re-generating XML From JSON - so don't include in roundtrip tests
    if [[ $(basename "$filename") == "gCoreStaff.xml" ]] ||
       [[ $(basename "$filename") == "gCoreStudent.xml" ]] ||
       [[ $(basename "$filename") == "job.xml" ]]; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi

perl sifexamples.pl ./$1/80_BackMatter/DataModel-CommonTypes.xml >> test/siftest_specgen.xml

cat attribute_test.xml >> test/siftest.xml

echo "</sif>" >> test/siftest.xml
echo "</sif>" >> test/siftest_specgen.xml
xmllint --c14n test/siftest.xml | xmllint --format - >test/siftest.pretty.xml

grep "schemaVersion" $1/SIF.Config_DataModel_US.xml | perl -pe 's/\s*<schemaVersion>/VERSION: /; s#</schemaVersion>##; $$_;' > scripts/out.txt

