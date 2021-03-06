#!/bin/bash

# Script to extract specgen information from raw Infrastructure specgen input files

# Setup - we need case insensitive string matching - or we'll lose (xQuery.xml)
shopt -s nocasematch   


# 1. Download specgen
#rm -fr DraftSIFInfrastructureSpec
#git clone https://github.com/nsip/DraftSIFInfrastructureSpec.git


# 2. Extract all necessary information from specgen into flat files
#    Start off with empty files...
echo "" > objectgraph.txt
echo "" > typegraph.txt

# process all objects in the specification
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

rm -f objs.txt
xsltproc included_objects.xslt DraftSIFInfrastructureSpec/06_DataModel/Custom/DataModel-Infrastructure.xml | perl -ne 'next unless $_ =~ /\S/; next if $_ =~ /<\?/; s/^\s+//; s/\s+$//; print "./DraftSIFInfrastructureSpec/06_DataModel/Custom/" . $_ . "\n"' > objs.txt
IFS=$'\n' read -d '' -r -a objectarray < objs.txt

for filename in ./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure/*.xml; do
  if containsElement "$filename" "${objectarray[@]}" ; then
    :
  else
    echo "Excluded:" $filename;
    continue;
  fi
  xsltproc sifobject.xslt "$filename" >> objectgraph.txt

  # Infrastructure re-uses some object complexTypes in other objects
  xsltproc --stringparam objSuffix Type sifobject.xslt "$filename" >>typegraph.txt
done

# process all common types in the specification
echo '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xi="http://www.w3.org/2001/XInclude" xmlns="http://sifassociation.org/SpecGen" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xhtml="http://www.w3.org/1999/xhtml" >' > data.xml
cat DraftSIFInfrastructureSpec/80_BackMatter/Generic-CommonTypes.xml >> data.xml
cat DraftSIFInfrastructureSpec/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> data.xml
echo '</root>' >> data.xml
xsltproc sifobject.xslt data.xml >> typegraph.txt

# 4. Extract example XML from specgen
mkdir -p test
rm -rf exp
mkdir -p exp
rm -f exp/*.xml
echo "<sif>" > test/siftest.xml
echo "<sif>" > test/siftest_specgen.xml

if [ -d ./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure ]; then
  for filename in ./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure/*.xml; do

    # exclude the two gCore dataobjects (for now)
    # job.xml has xsi:type= definition which isn't handled when re-generating XML From JSON - so don't include in roundtrip tests
    if [[ "$filename" == "./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure/gCoreStaff.xml" ]] ||
       [[ "$filename" == "./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure/gCoreStudent.xml" ]] ||
       [[ "$filename" == "./DraftSIFInfrastructureSpec/06_DataModel/Custom/Infrastructure/job.xml" ]]; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi

perl sifexamples.pl ./DraftSIFInfrastructureSpec/80_BackMatter/Generic-CommonTypes.xml >> test/siftest_specgen.xml
perl sifexamples.pl ./DraftSIFInfrastructureSpec/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> test/siftest_specgen.xml
#perl sifexamples1.pl ./DraftSIFInfrastructureSpec/80_BackMatter/Generic-CommonTypes.xml exp
#perl sifexamples1.pl ./DraftSIFInfrastructureSpec/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml exp

#cat attribute_test.xml >> test/siftest.xml

echo "</sif>" >> test/siftest.xml
echo "</sif>" >> test/siftest_specgen.xml
xmllint --c14n test/siftest.xml | xmllint --format - >test/siftest.pretty.xml
