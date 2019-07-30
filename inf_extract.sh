#!/bin/bash

# Script to extract specgen information from raw Infrastructure specgen input files

# Setup - we need case insensitive string matching - or we'll lose (xQuery.xml)
shopt -s nocasematch   


# 1. Download specgen
#rm -fr specgen_input
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

xsltproc included_objects.xslt specgen_input/06_DataModel/Custom/DataModel-Infrastructure.xml | perl -ne 'next unless $_ =~ /\S/; next if $_ =~ /<\?/; s/^\s+//; s/\s+$//; print "./specgen_input/06_DataModel/Custom/" . $_ . "\n"' > objs.txt
IFS=$'\n' read -d '' -r -a objectarray < objs.txt

for filename in ./specgen_input/06_DataModel/Custom/Infrastructure/*.xml; do
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
cat specgen_input/80_BackMatter/Generic-CommonTypes.xml >> data.xml
cat specgen_input/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> data.xml
echo '</root>' >> data.xml
xsltproc sifobject.xslt data.xml >> typegraph.txt

