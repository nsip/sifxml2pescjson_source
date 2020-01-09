#!/bin/bash


#  Run ONE of the following to setup  objectgraph.txt and typegraph.txt
sh au_extract.sh
#sh inf_extract.sh
#sh input_extract.sh

# 3. Generate transformation scripts and stylesheets

ruby treeparse.rb > scripts/out.txt
ruby makexslt.rb < scripts/out.txt > scripts/sif2json.xslt
ruby makexslt.rb -p < scripts/out.txt > scripts/sif2jsonspecgen.xslt
ruby makereorder.rb < scripts/out.txt > scripts/sifreorder.xslt
ruby makejs2xml.rb < scripts/out.txt > scripts/json2sif.js

# 4. Extract example XML from specgen
mkdir -p test
rm -rf exp
mkdir -p exp
rm -f exp/*.xml
echo "<sif>" > test/siftest.xml 
echo "<sif>" > test/siftest_specgen.xml 

if [ -d ./specgen_input/06_DataModel/Custom/Common ]; then
  for filename in ./specgen_input/06_DataModel/Custom/Common/*.xml; do
  #for filename in ./specgen/GenerateSpecTool_5/bin/Debug/dist/Specification/06_DataModel/Custom/Common/*.xml; do
    if [[ "$filename" == "./specgen_input/06_DataModel/Custom/Common/StudentScoreSet.xml" ]] ||
       [[ "$filename" == "./specgen_input/06_DataModel/Custom/Common/PersonPrivacyObligation.xml" ]] ||
       [[ "$filename" == "./specgen_input/06_DataModel/Custom/Common/ReportAuthorityInfo.xml" ]] ; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi
if [ -d ./specgen_input/06_DataModel/Custom/AU ]; then
  for filename in ./specgen_input/06_DataModel/Custom/AU/*.xml; do
    if [[ "$filename" == "./specgen_input/06_DataModel/Custom/AU/AGCensusSubmission.xml" ]] ||
       [[ "$filename" == "./specgen_input/06_DataModel/Custom/Common/ReportAuthorityInfo.xml" ]] ; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi

if [ -d ./specgen_input/06_DataModel/Custom/Infrastructure ]; then
  for filename in ./specgen_input/06_DataModel/Custom/Infrastructure/*.xml; do

    # exclude the two gCore dataobjects (for now)
    # job.xml has xsi:type= definition which isn't handled when re-generating XML From JSON - so don't include in roundtrip tests
    if [[ "$filename" == "./specgen_input/06_DataModel/Custom/Infrastructure/gCoreStaff.xml" ]] || 
       [[ "$filename" == "./specgen_input/06_DataModel/Custom/Infrastructure/gCoreStudent.xml" ]] ||
       [[ "$filename" == "./specgen_input/06_DataModel/Custom/Infrastructure/job.xml" ]]; then
      continue
    fi
    perl sifexamples.pl "$filename" >> test/siftest.xml
    perl sifexamples1.pl "$filename" exp
  done
fi

perl sifexamples.pl ./specgen_input/80_BackMatter/Generic-CommonTypes.xml >> test/siftest_specgen.xml
perl sifexamples.pl ./specgen_input/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml >> test/siftest_specgen.xml
perl sifexamples1.pl ./specgen_input/80_BackMatter/Generic-CommonTypes.xml exp
perl sifexamples1.pl ./specgen_input/80_BackMatter/Custom/DataModel-CommonTypes-Custom.xml exp

echo "</sif>" >> test/siftest.xml 
echo "</sif>" >> test/siftest_specgen.xml 
xmllint --c14n test/siftest.xml | xmllint --format - >test/siftest.pretty.xml

# 5. Test roundtrip XML > JSON (preserving order of keys) > XML

xsltproc scripts/sif2jsonspecgen.xslt test/siftest_specgen.xml > test/siftest_specgen.json
jq . test/siftest_specgen.json > test/siftest_specgen.pretty.json
xsltproc scripts/sif2json.xslt test/siftest.xml > test/siftest.json
jq . test/siftest.json > test/siftest.pretty.json
echo "<sif>" > test/siftest2.xml
bash -c "node scripts/json2sif.js < test/siftest.pretty.json >> test/siftest2.xml"
echo "</sif>" >> test/siftest2.xml
xmllint --c14n test/siftest2.xml | xmllint --format - > test/siftest2.pretty.xml
diff test/siftest.pretty.xml test/siftest2.pretty.xml > test/diff.txt
cat test/diff.txt
echo "Diff lines, roundtrip: "
egrep "^< " test/diff.txt|wc -l

# 6. Test reordering XML > JSON XML (not preserving order of keys) > XML

xsltproc scripts/sif2json.xslt test/siftest.xml > test/siftest.json
jq  -S . test/siftest.json > test/siftest.sorted.json
echo "<sif>" > test/siftest3.xml
node scripts/json2sif.js < test/siftest.sorted.json >> test/siftest3.xml
echo "</sif>" >> test/siftest3.xml
xsltproc scripts/sifreorder.xslt test/siftest3.xml > test/siftest.sorted.xml
xmllint --c14n test/siftest.sorted.xml | xmllint --format - > test/siftest.sorted.pretty.xml
diff test/siftest2.pretty.xml test/siftest.sorted.pretty.xml > test/diff.sorted.txt
cat test/diff.sorted.txt
echo "Diff lines, re-sorting XML: "
egrep "^< " test/diff.sorted.txt|wc -l

# 7. Just run specgen fragments, and confirm they don't blow up
for filename in exp/*.xml; do
  if [ -s $filename ]; then
    xsltproc scripts/sif2jsonspecgen.xslt $filename >> exp/out.json
  fi
done
