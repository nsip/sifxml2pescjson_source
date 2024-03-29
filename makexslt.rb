require 'optparse'

options = {}
optparse = OptionParser.new do |opts|
  opts.on('-p', '--path_truncate',
          'truncate path information to just immediate parent (used for specgen generation)') do |_o|
    options[:path_truncate] = true
  end
end
optparse.parse!

def truncate_paths(arr)
  arr.inject([]) do |memo, elem|
    memo << elem.sub(%r{^.+?/([^/]+/[^/]+)$}, '\\1')
  end.uniq
end

complexattr = []
simpleattr = []
list = []
numeric = []
boolean = []
numericattr = []
booleanattr = []
object = []
objectlist = []

while line = gets
  if /^COMPLEX ATTRIBUTE/.match line
    /COMPLEX ATTRIBUTE: (?<path>\S+)/ =~ line
    complexattr << path
  elsif /^SIMPLE ATTRIBUTE/.match line
    /SIMPLE ATTRIBUTE: (?<path>\S+)/ =~ line
    simpleattr << path
  elsif /^LIST/.match line
    /LIST: (?<path>\S+)/ =~ line
    list << path
  elsif /^OBJECT/.match line
    /OBJECT: (?<path>\S+)/ =~ line
    object << path
    objectlist << "#{path}s"
    list << "#{path}s/#{path}"
  elsif /^NUMERIC.*@/.match line
    /NUMERIC: (?<path>\S+)/ =~ line
    numericattr << path
  elsif /^NUMERIC/.match line
    /NUMERIC: (?<path>\S+)/ =~ line
    numeric << path
  elsif /^BOOLEAN.*@/.match line
    /BOOLEAN: (?<path>\S+)/ =~ line
    booleanattr << path
  elsif /^BOOLEAN/.match line
    /BOOLEAN: (?<path>\S+)/ =~ line
    boolean << path
  end
end

if options[:path_truncate]
  complexattr = truncate_paths(complexattr)
  simpleattr = truncate_paths(simpleattr)
  list = truncate_paths(list)
  numeric = truncate_paths(numeric)
  numericattr = truncate_paths(numericattr)
  booleanattr = truncate_paths(booleanattr)
  boolean = truncate_paths(boolean)
end

complexattr = ['NEVERMATCH'] if complexattr.empty?
simpleattr = ['NEVERMATCH'] if simpleattr.empty?
list = ['NEVERMATCH'] if list.empty?
boolean = ['NEVERMATCH'] if boolean.empty?
numeric = ['NEVERMATCH'] if numeric.empty?
numericattr = ['NEVERMATCH'] if numericattr.empty?
booleanattr = ['NEVERMATCH'] if booleanattr.empty?

print <<~"END"
  <?xml version="1.0" encoding="UTF-8" ?>
  <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:json="http://json.org/">
    <!-- from https://gist.github.com/inancgumus/3ce56ddde6d5c93f3550b3b4cdc6bcb8 -->
    <!-- https://github.com/bramstein/xsltjson/blob/master/conf/xml-to-jsonml.xsl -->
    <xsl:output method="text" omit-xml-declaration="yes" encoding="utf-8"/>

    <xsl:template match="/*[node()]">
      <xsl:apply-templates select="." mode="#{options[:path_truncate] ? 'obj-detect' : 'obj-list'}" />
    </xsl:template>

    <xsl:template match="*" mode="detect">
      <xsl:choose>
        <xsl:when test="count(./child::*) > 0 or count(@*) > 0">
          <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="obj-content" />
        </xsl:when>
        <xsl:when test="count(./child::*) = 0">
          <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="value"/>
        </xsl:when>
      </xsl:choose>
      <xsl:if test="count(following-sibling::*) &gt; 0">, </xsl:if>
    </xsl:template>

    <xsl:template match="*" mode="value">
      <xsl:text>"</xsl:text><xsl:apply-templates select="node/@TEXT | text()"/><xsl:text>"</xsl:text>
    </xsl:template>

    <xsl:template match="*" mode="obj-detect">
      {
      <xsl:choose>
        <xsl:when test="count(./child::*) > 0 or count(@*) > 0">
          <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="obj-content" />
        </xsl:when>
        <xsl:when test="count(./child::*) = 0">
          <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="value"/>
        </xsl:when>
      </xsl:choose>
      }
    </xsl:template>

    <!-- objects -->
    <xsl:template match="#{objectlist.join(' | ')}" mode="obj-list">
    {
     <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : {
      <xsl:choose>
        <xsl:when test="count(./child::*) > 0 or count(@*) > 0">
          <xsl:apply-templates select="./*" mode="detect" />
        </xsl:when>
      </xsl:choose>
      }
    }
    </xsl:template>

    <xsl:template match="#{object.join(' | ')}" mode="obj-list">
      <xsl:if test="count(preceding-sibling::*) = 0">
        <xsl:text>[</xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="count(./child::*) > 0 or count(@*) > 0">
          <xsl:apply-templates select="." mode="obj-detect" />
        </xsl:when>
      </xsl:choose>
      <xsl:if test="count(following-sibling::*) &gt; 0">, </xsl:if>
      <xsl:if test="count(following-sibling::*) = 0"><xsl:text>]</xsl:text></xsl:if>
    </xsl:template>

    <!-- numeric or boolean -->
    <xsl:template match="#{numeric.concat(boolean).join(' | ')}" mode="value">
      <xsl:call-template name="encode-numeric-value">
        <xsl:with-param name="value" select="." />
      </xsl:call-template>
    </xsl:template>

    <xsl:template match="* | @*" mode="attrvalue">
      <xsl:text>"</xsl:text><xsl:apply-templates select="."/><xsl:text>"</xsl:text>
    </xsl:template>

    <!-- numeric or boolean attribute -->
    <xsl:template match="#{numericattr.concat(booleanattr).join(' | ')}" mode="attrvalue">
      <xsl:call-template name="encode-numeric-value">
        <xsl:with-param name="value" select="." />
      </xsl:call-template>
    </xsl:template>

    <!-- simple content with attribute -->
    <xsl:template match="#{simpleattr.join(' | ')}" mode="detect" priority="1">
      <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="obj-content"/>
      <xsl:if test="count(following-sibling::*) &gt; 0">, </xsl:if>
    </xsl:template>

    <!-- list  - takes precedence when list of elements which are simple content with attributes -->
    <xsl:template match="#{list.join(' | ')}" mode="detect" priority="2">
    <!-- repeating item may not be wrapped up in a List element (so check names of preceding-siblings) -->
    <xsl:if test="count(preceding-sibling::*) = 0 or not(name(preceding-sibling::*[1]) = name(.))">
        <xsl:text>"</xsl:text><xsl:value-of select="name()"/><xsl:text>" : [</xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="count(./child::*) > 0 or count(@*) > 0">
          <xsl:apply-templates select="." mode="obj-content" />
        </xsl:when>
        <xsl:when test="count(./child::*) = 0">
          <xsl:apply-templates select="." mode="value"/>
        </xsl:when>
      </xsl:choose>
      <!-- repeating item may not be wrapped up in a List element (so check names of following-siblings) -->
      <xsl:if test="count(following-sibling::*) &gt; 0 and name(following-sibling::*[1]) = name(.)">, </xsl:if>
      <xsl:if test="count(following-sibling::*) = 0 or not(name(following-sibling::*[1]) = name(.))"><xsl:text>]</xsl:text><xsl:if test="count(following-sibling::*) &gt; 0"><xsl:text>,</xsl:text></xsl:if></xsl:if>
    </xsl:template>

    <xsl:template match="*" mode="obj-content">
      <xsl:text>{</xsl:text>
      <xsl:apply-templates select="@*" mode="attr" />
      <xsl:if test="count(@*) &gt; 0">, </xsl:if>
      <xsl:apply-templates select="./*" mode="detect" />
      <xsl:if test="count(child::*) = 0 and text() and not(@*)">
        <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="value"/>
      </xsl:if>
      <xsl:if test="count(child::*) = 0 and text() and @*">
        <xsl:text>"value" : </xsl:text><xsl:apply-templates select="." mode="value"/>
      </xsl:if>
      <xsl:if test="count(child::*) = 0 and not(text()) and @*">
        <xsl:text>"value" : ""</xsl:text>
      </xsl:if>
      <xsl:text>}</xsl:text>
      <xsl:if test="position() &lt; last()">, </xsl:if>
    </xsl:template>

    <!-- simple content with attribute -->
    <xsl:template match="#{simpleattr.join(' | ')}" mode="obj-content">
      <xsl:text>{</xsl:text>
      <xsl:apply-templates select="@*" mode="attr" />
      <xsl:if test="count(@*) &gt; 0">, </xsl:if>
      <xsl:apply-templates select="./*" mode="detect" />
      <xsl:if test="count(child::*) = 0 and text()">
        <xsl:text>"value" : </xsl:text><xsl:apply-templates select="." mode="value"/>
      </xsl:if>
      <xsl:if test="count(child::*) = 0 and not(text())">
        <xsl:text>"value" : ""</xsl:text>
      </xsl:if>
      <xsl:text>}</xsl:text>
      <xsl:if test="position() &lt; last()">, </xsl:if>
    </xsl:template>

    <xsl:template match="@*" mode="attr">
      <xsl:text>"</xsl:text><xsl:value-of select="name()"/>" : <xsl:apply-templates select="." mode="attrvalue"/>
      <xsl:if test="position() &lt; last()">, </xsl:if>
    </xsl:template>

    <!-- https://github.com/bramstein/xsltjson/blob/master/conf/xml-to-jsonml.xsl -->
    <json:search name="string">
  		<json:replace src="\\" dst="\\\\"/>
  		<json:replace src="&quot;" dst="\\&quot;"/>
  		<json:replace src="&#xA;" dst="\\n"/>
  		<json:replace src="&#xD;" dst="\\r"/>
  		<json:replace src="&#x9;" dst="\\t"/>
  		<json:replace src="\\n" dst="\\n"/>
  		<json:replace src="\\r" dst="\\r"/>
  		<json:replace src="\\t" dst="\\t"/>
    </json:search>

    <xsl:template name="replace-string">
  		<xsl:param name="input"/>
  		<xsl:param name="src"/>
  		<xsl:param name="dst"/>
  		<xsl:choose>
  			<xsl:when test="contains($input, $src)">
  				<xsl:value-of select="concat(substring-before($input, $src), $dst)"/>
  				<xsl:call-template name="replace-string">
  					<xsl:with-param name="input" select="substring-after($input, $src)"/>
  					<xsl:with-param name="src" select="$src"/>
  					<xsl:with-param name="dst" select="$dst"/>
  				</xsl:call-template>
  			</xsl:when>
  			<xsl:otherwise>
  				<xsl:value-of select="$input"/>
  			</xsl:otherwise>
  		</xsl:choose>
    </xsl:template>

    <xsl:template name="encode">
  		<xsl:param name="input"/>
  		<xsl:param name="index">1</xsl:param>

  		<xsl:variable name="text">
  			<xsl:call-template name="replace-string">
  				<xsl:with-param name="input" select="$input"/>
  				<xsl:with-param name="src" select="document('')//json:search/json:replace[$index]/@src"/>
  				<xsl:with-param name="dst" select="document('')//json:search/json:replace[$index]/@dst"/>
  			</xsl:call-template>
  		</xsl:variable>

  		<xsl:choose>
  			<xsl:when test="$index &lt; count(document('')//json:search/json:replace)">
  				<xsl:call-template name="encode">
  					<xsl:with-param name="input" select="$text"/>
  					<xsl:with-param name="index" select="$index + 1"/>
  				</xsl:call-template>
  			</xsl:when>
  			<xsl:otherwise>
  				<xsl:value-of select="$text"/>
  			</xsl:otherwise>
  		</xsl:choose>
    </xsl:template>

    <xsl:template name="encode-value">
                  <xsl:param name="value"/>
                  <!--
                  <xsl:choose>
                          <xsl:when test="normalize-space($value) != $value">
                  -->
                  <!-- no, we always call encode, because we escape \ as well -->
                                  <xsl:call-template name="encode">
                                          <xsl:with-param name="input" select="$value"/>
                                  </xsl:call-template>
                  <!--
                          </xsl:when>
                          <xsl:otherwise>
                                  <xsl:value-of select="$value"/>
                          </xsl:otherwise>
                  </xsl:choose>
                  -->
    </xsl:template>

    <xsl:template match="node/@TEXT | text()" name="removeBreaks" priority="10">
      <xsl:call-template name="encode-value">
        <xsl:with-param name="value" select="." />
      </xsl:call-template>
    </xsl:template>

    <xsl:template name="encode-numeric-value">
                  <xsl:param name="value"/>
                  <xsl:choose>
                          <xsl:when test="substring(normalize-space($value), 1, 1) = '.'">
                                  <xsl:text>0</xsl:text><xsl:value-of select="$value"/>
                          </xsl:when>
                          <xsl:otherwise>
                                  <xsl:value-of select="$value"/>
                          </xsl:otherwise>
                  </xsl:choose>
    </xsl:template>

  </xsl:stylesheet>
END
