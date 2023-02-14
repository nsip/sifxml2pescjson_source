#!/bin/bash

# Script to extract specgen information from raw AU specgen input files


# 1. Download specgen
#rm -fr specgen_input_au
#git clone https://github.com/nsip/specgen_input_au.git

# specgen is in parameter $1

# 2. Extract all necessary information from specgen into flat files

# process all objects in the specification

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

xsltproc included_objects.xslt $1/06_DataModel/Custom/DataModel-Custom-AU.xml | perl -ne 'next unless $_ =~ /\S/; next if $_ =~ /<\?/; s/^\s+//; s/\s+$//; @a = split("/", $_); print $a[-1] . "\n"' > objs.txt
IFS=$'\n' read -d '' -r -a objectarray < objs.txt

for filename in ./$1/06_DataModel/Custom/Common/*.xml; do
  if containsElement $(basename "$filename") "${objectarray[@]}" ; then
    :
  else
    echo "Excluded:" $filename;
    continue;
  fi
  if [[ $(basename "$filename") == "StudentScoreSet.xml" ]]; then
    continue
  fi
  xsltproc sifobject.xslt "$filename" >> objectgraph.txt
done
for filename in ./$1/06_DataModel/Custom/AU/*.xml; do
  if containsElement $(basename "$filename") "${objectarray[@]}" ; then
    :
  else
    echo "Excluded:" $filename;
    continue
  fi
  xsltproc sifobject.xslt "$filename" >> objectgraph.txt
done
# process all common types in the specification
echo '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xi="http://www.w3.org/2001/XInclude" xmlns="http://sifassociation.org/SpecGen" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xhtml="http://www.w3.org/1999/xhtml" >' > data.xml
cat $1/80_BackMatter/Generic-CommonTypes.xml >> data.xml
cat $1/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> data.xml
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
  for filename in ./$1/06_DataModel/Custom/Common/*.xml; do
  
    if [[ $(basename "$filename") == "StudentScoreSet.xml" ]] ||
       [[ $(basename "$filename") == "ResourceUsage.xml" ]] ||
       [[ $(basename "$filename") == "SystemRole.xml" ]] ; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi
if [ -d ./$1/06_DataModel/Custom/AU ]; then
  for filename in ./$1/06_DataModel/Custom/AU/*.xml; do
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

perl sifexamples.pl ./$1/80_BackMatter/Generic-CommonTypes.xml >> test/siftest_specgen.xml
perl sifexamples.pl ./$1/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> test/siftest_specgen.xml

cat attribute_test.xml >> test/siftest.xml

echo "</sif>" >> test/siftest.xml
echo "</sif>" >> test/siftest_specgen.xml
xmllint --c14n test/siftest.xml | xmllint --format - >test/siftest.pretty.xml

grep "schemaVersion" $1/SIF.Config_DataModel_AU.xml | perl -pe 's/\s*<schemaVersion>/VERSION: /; s#</schemaVersion>##; $$_;' > scripts/out.txt

