<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:cpe="http://cpe.mitre.org/dictionary/2.0"
                xmlns:cpe-23="http://scap.nist.gov/schema/cpe-extension/2.3">

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- Define a key for vendor+product combinations -->
  <xsl:key name="vendor-product" match="cpe:cpe-item" use="concat(tokenize(cpe-23:cpe23-item/@name, ':')[4], '|', tokenize(cpe-23:cpe23-item/@name, ':')[5])"/>

  <!-- Add header row for CSV -->
  <xsl:template match="/">
    <xsl:message>Debug: Processing root element</xsl:message>
    <!--<xsl:text>title☭vendor☭product☭cpe&#xa;</xsl:text> -->
    <!-- Apply templates to unique vendor+product combinations -->
    <xsl:for-each-group select="//cpe:cpe-item" group-by="concat(tokenize(cpe-23:cpe23-item/@name, ':')[4], '|', tokenize(cpe-23:cpe23-item/@name, ':')[5])">
      <xsl:apply-templates select="."/>
    </xsl:for-each-group>
    <xsl:message>Debug: Finished processing all items</xsl:message>
  </xsl:template>

  <xsl:template match="cpe:cpe-item">
    <xsl:message>Debug: Processing cpe-item: <xsl:value-of select="@name"/></xsl:message>

    <!-- Extract information from CPE 2.3 format -->
    <xsl:variable name="cpe23" select="cpe-23:cpe23-item/@name"/>
    <xsl:variable name="raw_title" select="cpe:title"/>

    <xsl:message>Debug: Title: <xsl:value-of select="$raw_title[1]"/></xsl:message>
    <xsl:message>Debug: CPE 2.3 format: <xsl:value-of select="$cpe23"/></xsl:message>

    <!-- Tokenize the CPE string -->
    <xsl:variable name="tokens" select="tokenize($cpe23, ':')" />
    <xsl:variable name="cpe" select="$tokens[1]" />
    <xsl:variable name="cpe_version" select="$tokens[2]" />
    <xsl:variable name="part" select="$tokens[3]" />
    <xsl:variable name="vendor" select="$tokens[4]" />
    <xsl:variable name="product" select="$tokens[5]" />
    <xsl:variable name="version" select="$tokens[6]" />
    <xsl:variable name="update" select="$tokens[7]" />
    <xsl:variable name="edition" select="$tokens[8]" />
    <xsl:variable name="language" select="$tokens[9]" />
    <xsl:variable name="sw_edition" select="$tokens[10]" />
    <xsl:variable name="target_sw" select="$tokens[11]" />
    <xsl:variable name="target_hw" select="$tokens[12]" />
    <xsl:variable name="other" select="$tokens[13]" />

    <!-- Remove version from title if it's present at the end -->
    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="ends-with($raw_title[1], concat(' ', $version))">
          <xsl:value-of select="substring-before($raw_title[1], concat(' ', $version))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$raw_title[1]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:message>Debug: Vendor: <xsl:value-of select="$vendor"/></xsl:message>
    <xsl:message>Debug: Product: <xsl:value-of select="$product"/></xsl:message>

    <!-- generate cpe filter * -->
    <xsl:variable name="modifiedCpe" select="concat($cpe,':', $cpe_version,':', $part,':', $vendor,':', $product,':', '*')"/>

    <!-- Output the CSV line -->
    <xsl:value-of select="$title"/>
    <xsl:text>☭</xsl:text>
    <xsl:value-of select="$vendor"/>
    <xsl:text>☭</xsl:text>
    <xsl:value-of select="$product"/>
    <xsl:text>☭</xsl:text>
    <xsl:value-of select="$modifiedCpe"/>
    <xsl:text>&#xa;</xsl:text>

    <xsl:message>Debug: Finished processing item</xsl:message>
  </xsl:template>

</xsl:stylesheet>
