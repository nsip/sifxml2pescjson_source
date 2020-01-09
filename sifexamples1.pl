$i = 0;
open IN, "<$ARGV[0]";

while(<IN>) {
  if(m#</xhtml:Example>#) {
    $example = 0;
    $out =~ s/ xml:lang="en"//;
    $out =~ s/<!--.*?-->//g;
    ($object) = $out =~ m/<(\S+)/;
    $out =~ s/<([^ >]+) >/<\1>/g;
    print F $out;
    close F;
    $i++;
    $name = "";
  }
  $out .= $_ if $example;
  if(/<xhtml:Example/){
    $prefix = $ARGV[0];
    $prefix =~ s#^.+/([^/]+)$#\1#;
    ($name) = /name="([^"]+)"/;
    $name = sprintf("example%04d", $i) unless $name;
    $name =~ s/[^A-Za-z0-9]//g;
    $name = $prefix . $name;
    open F, ">$ARGV[1]/$name.xml";
    $example = 1;
    $out = "";
  }
}
close IN;
