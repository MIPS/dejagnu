<?xml version="1.0"?>

<!--

    Copyright (C) 2020 Free Software Foundation, Inc.

    This file is part of DejaGnu.

    DejaGnu is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This file was written by Jacob Bachmeyer.

    This is an XSLT stylesheet that translates the new XML format to the
    legacy XML format in case anyone has an existing pipeline that depends
    on the old format being available.  Efforts have been made to recreate
    the original text layout, on the assumption that some readers might not
    be using actual XML parsers.

    Current limitations:

      - The output has no !DOCTYPE and thus no embedded DTD.

      - There are numerous spurious blank lines in the output, but only in
	locations where they should be insignificant.  All of the tags
	declared as containing #PCDATA in the legacy DTD are exact.
	The blank lines contain varying amounts of whitespace.

      These appear to be limitations of XSLT.

-->

<xsl:stylesheet
   xmlns:dg="http://www.gnu.org/software/dejagnu/xmlns/runtest-log-1"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   version="1.0">
<xsl:output method="xml"/>
<xsl:namespace-alias stylesheet-prefix="dg" result-prefix="#default"/>

<xsl:template match="dg:platform"></xsl:template>

<xsl:template match="dg:run">
<testsuite>
  <xsl:apply-templates/>
</testsuite>
</xsl:template>

<xsl:template match="dg:test">
  <test><xsl:text>
    </xsl:text><input><xsl:value-of select="./dg:input"/></input><xsl:text>
    </xsl:text><output><xsl:value-of select="./dg:output"/></output><xsl:text>
    </xsl:text><result><xsl:value-of select="@dg:result"/></result><xsl:text>
    </xsl:text><name><xsl:value-of select="./dg:name"/></name><xsl:text>
    </xsl:text><prms_id><xsl:choose>
	<xsl:when test="string-length(@dg:prms_id) > 0">
	  <xsl:value-of select="@dg:prms_id"/>
	</xsl:when>
	<xsl:otherwise><xsl:text>0</xsl:text></xsl:otherwise>
    </xsl:choose></prms_id><xsl:text>
  </xsl:text></test>
</xsl:template>

<xsl:template match="dg:total">
<xsl:text>
  </xsl:text><summary><xsl:text>
    </xsl:text><result><xsl:value-of select="@dg:result"/></result><xsl:text>
    </xsl:text><description><xsl:choose>
	<xsl:when test="@dg:result = 'PASS'">
	  <xsl:text># of expected passes</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'FAIL'">
	  <xsl:text># of unexpected failures</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'XFAIL'">
	  <xsl:text># of expected failures</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'XPASS'">
	  <xsl:text># of unexpected successes</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'KFAIL'">
	  <xsl:text># of known failures</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'KPASS'">
	  <xsl:text># of unknown successes</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'UNRESOLVED'">
	  <xsl:text># of unresolved testcases</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'UNSUPPORTED'">
	  <xsl:text># of unsupported tests</xsl:text></xsl:when>
	<xsl:when test="@dg:result = 'UNTESTED'">
	  <xsl:text># of untested testcases</xsl:text></xsl:when>
    </xsl:choose></description><xsl:text>
    </xsl:text><total><xsl:value-of select="@dg:count"/></total><xsl:text>
  </xsl:text></summary>
</xsl:template>

</xsl:stylesheet>
