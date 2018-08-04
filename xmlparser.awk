# From arnold  Fri Oct 19 11:47:19 2001
# Return-Path: <arnold@skeeve.com>
# Received: (from arnold@localhost)
# 	by skeeve.com (8.11.0/8.11.0) id f9J9lJo25059
# 	for arnold; Fri, 19 Oct 2001 11:47:19 +0200
# Date: Fri, 19 Oct 2001 11:47:19 +0200
# From: Aharon Robbins <arnold@skeeve.com>
# Message-Id: <200110190947.f9J9lJo25059@skeeve.com>
# To: arnold@skeeve.com
# Subject: xml parser
# Status: R
# 
# Path: iad-read.news.verio.net!dfw-artgen.news.verio.net!dfw-peer.news.verio.net!news.verio.net!crtntx1-snh1.gtei.net!cpk-news-hub1.bbnplanet.com!news.gtei.net!nf3.bellglobal.com!sunqbc.risq.qc.ca!torn!qcarhaaa.nortelnetworks.com!bcarh189.ca.nortel.com!bcarh8ac.ca.nortel.com!bcarh8ab.ca.nortel.com!not-for-mail
# From: Steve Coile <scoile@csc.com>
# Newsgroups: comp.lang.awk
# Subject: XML parser for awk (was: awk newbie needs to parse xml file)
# Date: Wed, 17 Oct 2001 13:55:32 -0400
# Organization: Computer Sciences Corporation
# Lines: 547
# Message-ID: <3BCDC614.AC548AB8@csc.com>
# References: <3d68af91.0110151058.54e2d55b@posting.google.com>
# NNTP-Posting-Host: wpgcy0j6.us.nortel.com
# Mime-Version: 1.0
# Content-Type: text/plain; charset=us-ascii
# Content-Transfer-Encoding: 7bit
# X-Mailer: Mozilla 4.77 [en] (X11; U; Linux 2.4.3-12 i686)
# X-Accept-Language: en
# Xref: dfw-artgen.news.verio.net comp.lang.awk:10853
# 
# Reading the article about the individual wanting to process XML files
# with awk, I was inspired to try to write an XML parser in awk.  Below is
# the fruit of my effort.  Comments welcome.
# 
# ----- cut here -----
# $Id: xmlparse.awk,v 1.1 2001/10/17 17:49:33 scoile Exp $
##############################################################################
#
# xmlparse.awk - A simple XML parser for awk
#
# Author:	Steve Coile <scoile@csc.com>
#
# Version:	1.0 (20011017)
#
# Synopsis:
#
#	awk -f xmlparse.awk [FILESPEC]...
#
# Description:
#
#	This script is a simple XML parser for (modern variants of) awk.
#	Input in XML format is saved to two arrays, "type" and "item".
#
#	The term, "item", as used here, refers to a distinct XML element,
#	such as a tag, an attribute name, an attribute value, or data.
#
#	The indexes into the arrays are the sequence number that a
#	particular item was encountered.  For example, the third item's
#	type is described by type[3], and its value is stored in item[3].
#
#	The "type" array contains the type of the item encountered for
#	each sequence number.  Types are expressed as a single word:
#	"error" (invalid item or other error), "begin" (open tag),
#	"attrib" (attribute name), "value" (attribute value), "end"
#	(close tag), and "data" (data between tags).
#
#	The "item" array contains the value of the item encountered
#	for each sequence number.  For types "begin" and "end", the
#	item value is the name of the tag.  For "error", the value is
#	the text of the error message.	For "attrib", the value is the
#	attribute name.  For "value", the value is the attribute value.
#	For "data", the value is the raw data.
#
#	WARNING: XML-quoted values ("entities") in the data and attribute
#	values are *NOT* unquoted; they are stored as-is.
#
###############################################################################

BEGIN {

# In XML, literal "<" and ">" are only valid as tag delimiters;
# to include a "<" or ">" as data, they must be quoted: "&lt;" and
# "&gt;".  So we know that if we encounter a ">", we have reached the
# end of a tag.  This makes a convenient end-of-record marker, as the
# end-of-tag delimiter marks a special event, whereas a new-line is
# simply whitespace in XML.

	RS = ">";

	lineno = 1;
	sptr = 0;

}

# Count input lines.

{
	data = $0;
	lineno += gsub( /\n/, "", data );
	data = "";
}

# Special modes of operation.  These handle special XML sections, such
# as literal character data containing XML meta-characters ("cdata"
# sections), comments, and processing instructions ("pi") for other
# document processors.

# "Cdata" sections are teminated by the sequence, "]]>".

( mode == "cdata" ) {
	if ( $0 ~ /\]\]$/ ) {
		sub( /\]\]$/, "", $0 );
		mode = "";
	};
	item[idx] = item[idx] RS $0;
	next;
}

# Comment sections are terminated by the sequence, "-->".

( mode == "comment" ) {
	if ( $0 ~ /--$/ ) {
		sub( /--$/, "", $0 );
		mode = "";
	};
	item[idx] = item[idx] RS $0;
	next;
}

# Processing instruction sections are terminated by the sequence, "?>".

( mode == "pi" ) {
	if ( $0 ~ /\?$/ ) {
		sub( /\?$/, "", $0 );
		mode = "";
	};
	item[idx] = item[idx] RS $0;
	next;
}

( !mode ) {

	mline = 0;

# Our record separator is the end-of-tag marker, ">".  If we've
# encountered an end-of-tag marker, we should have a beginning-of-tag
# marker ("<") somewhere in the input record.  If not, either there
# is a spurious end-of-tag marker, or the record was terminated by
# the end-of-file.

	p = index( $0, "<" );

# Any data preceeding the beginning-of-tag marker is raw data.  If no
# beginning-of-tag marker is present, everything in the input is data.

	if ( !p || ( p > 1 )) {
		idx += 1;
		type[idx] = "data";
		item[idx] = ( p ? substr( $0, 1, ( p - 1 )) : $0 );
		if ( !p ) next;
		$0 = substr( $0, p );
	};

# Recognize special XML sections.  Sections are not processed as XML,
# but handled specially.  If the section end with the current input
# record, we continue processing XML in the next record; otherwise,
# we enter a special mode and perform special processing.

# Character data ("cdata") sections contain literal character data
# containing XML meta-characters that should not be processed. 
# Character data sections begin with the sequence,
# "<![CDATA[" and end with "]]>".
# This section may span input records.

	if ( $0 ~ /^<!\[[Cc][Dd][Aa][Tt][Aa]\[/ ) {
		idx += 1;
		type[idx] = "cdata";
		$0 = substr( $0, 10 );
		if ( $0 ~ /\]\]$/ ) sub( /\]\]$/, "", $0 );
		else {
			mode = "cdata";
			mline = lineno;
		};
		item[idx] = $0;
		next;
	}

# Comments begin with the sequence, "<!--" and end with "-->".
# This section may span input records.

	else if ( $0 ~ /^<!--/ ) {
		idx += 1;
		type[idx] = "comment";
		$0 = substr( $0, 5 );
		if ( $0 ~ /--$/ ) sub( /--$/, "", $0 );
		else {
			mode = "comment";
			mline = lineno;
		};
		item[idx] = $0;
		next;
	}

# Declarations begin with the sequence, "<!" and end with ">".
# This section may *NOT* span input records.

	else if ( $0 ~ /^<!/ ) {
		idx += 1;
		type[idx] = "decl";
		$0 = substr( $0, 3 );
		item[idx] = $0;
		next;
	}

# Processing instructions ("pi") begin with the sequence, "<?" and end
# with "?>".  This section may span input records.

	else if ( $0 ~ /^<\?/ ) {
		idx += 1;
		type[idx] = "pi";
		$0 = substr( $0, 3 );
		if ( $0 ~ /\?$/ ) sub( /\?$/, "", $0 );
		else {
			mode = "pi";
			mline = lineno;
		};
		item[idx] = $0;
		next;
	};

# Beyond this point, we're dealing strictly with a tag.

	idx += 1;

# A tag that begins with "</" (e.g. as in "</p>") is a close tag:
# it closes a tag-enclosed block.

	if ( substr( $0, 1, 2 ) == "</" ) {
		type[idx] = "end";
		tag = $0 = substr( $0, 3 );
	}

# A tag that begins simply with "<" (e.g. as in "<p>") is an open
# tag: it starts a tag-enclosed block.  Note that a stand-alone tag
# (e.g. "<data/>") will be handled later, and will appear as an open
# tag and close tag, with no data between.

	else {
		type[idx] = "begin";
		tag = $0 = substr( $0, 2 );
	};

# The tag name is saved in "tag" so that we can retreive it later should
# we find that the tag is stand-alone and need to save a close tag item.

	sub( /[ \n\t/].*$/, "", tag );
	tag = toupper( tolower( tag ));
	item[idx] = tag;

# Validate the tag name.  If invalid, indicate so and exit.

	if ( tag !~ /^[A-Za-z][-+_.:0-9A-Za-z]*$/ )
	{
		type[idx] = "error";
		item[idx] = "line " lineno ": " tag ": invalid tag name";
		exit( 1 );
	}

# If an open tag is encountered, its name is recorded on the stack.
# If a close tag is encountered, its name is compared against the name
# on the top of the stack.  If the names differ, an error is generated
# (XML does not allow overlapping tags).

	if ( type[idx] == "begin" ) {
		sptr += 1;
		lstack[sptr] = lineno;
		tstack[sptr] = tag;
	}
	else if ( type[idx] == "end" ) {
		if ( tag != tstack[sptr] ) {
			type[idx] = "error";
			item[idx] = "line " lineno ": " tag \
					": unexpected close tag, expecting " \
					tstack[sptr];
			exit( 1 );
		};
		delete tstack[sptr];
		sptr -= 1;
	};

	sub( /[^ \n\t/]*[ \n\t]*/, "", $0 );

# Beyond this point, we're dealing with the tag attributes, if any,
# and/or the stand-alone end-of-tag marker.

	while ( $0 ) {

# If $0 contains only a slash (/), then the tag we're processing is
# stand-alone (e.g. "<data/>"), so we generate a close tag, but no data
# between the open and close tags.

		if ( $0 == "/" )
		{
			idx += 1;
			type[idx] = "end";
			item[idx] = tag;
			delete lstack[sptr];
			delete tstack[sptr];
			sptr -= 1;
			break;
		};

# The attribute name is determined.  Note that the attribute name is
# also saved to "attrib" so that we can reference it should the attribute
# not include a value.  If the attribute does not include a value,
# it's name is given as its value.

		idx += 1;
		type[idx] = "attrib";
		attrib = $0;
		sub( /=.*$/, "", attrib );
		attrib = tolower( attrib );

		item[idx] = attrib;

# Validate the attribute name.  If invalid, indicate so and exit.

		if ( attrib !~ /^[A-Za-z][-+_0-9A-Za-z]*$/ )
		{
			type[idx] = "error";
			item[idx] = "line " lineno ": " attrib \
					": invalid attribute name";
			exit( 1 );
		}

		sub( /^[^=]*/, "", $0 );

# Each attribute must have a value.  If one isn't explicit in the input,
# we assign it one equal to the name of the attribute itself.  Attribute
# values in the input may be in one of three forms: enclosed in double
# quotes ("), enclosed in single quotes/apostrophes ('), or a single word.

		idx += 1;
		type[idx] = "value";

		if ( substr( $0, 1, 1 ) == "=" ) {
			if ( substr( $0, 2, 1 ) == "\"" ) {
				item[idx] = substr( $0, 3 );
				sub( /".*$/, "", item[idx] );
				sub( /^="[^"]*"/, "", $0 );
			}
			else if ( substr( $0, 2, 1 ) == "'" ) {
				item[idx] = substr( $0, 3 );
				sub( /'.*$/, "", item[idx] );
				sub( /^='[^']*'/, "", $0 );
			}
			else {
				item[idx] = $0;
				sub( /[ \n\t/]*.$/, "", item[idx] );
				sub( /^=[^ \n\t/]*/, "", $0 );
			};
		}
		else item[idx] = attrib;

		sub( /^[ \n\t]*/, "", $0 );

	};

	attrib = "";
	tag = "";
	next;

}

END {

# If mode is defined, the input stream ended without terminating an
# XML section.  Thus, the input contains invalid XML.

	if ( mode ) {
		idx += 1;
		type[idx] = "error";
		if ( mode == "cdata" ) mode = "character data";
		else if ( mode == "pi" ) mode = "processing instruction";
		item[idx] = "line " mline ": unterminated " mode;
	};

# If an open tag occured with no corresponding close tag, we have
# invalid XML.

	for ( n = sptr; n; n -= 1 ) {
		idx += 1;
		type[idx] = "error";
		item[idx] = "line " lstack[n] ": " \
				tstack[n] ": unclosed tag";
	};

}

# The following simple examples demonstrate the use of the accumulated
# data from the XML input stream.

END {

# If errors occured, generate appropriate messages and exit without
# further processing.

	if ( type[idx] == "error" ) {
		for ( n = idx; n && ( type[n] == "error" ); n -= 1 );
		for ( n += 1; n <= idx; n += 1 ) print "ERROR:", item[n];
		exit 1;
	};

## Print simplified XML.  If output completes successfully and the stack
## is not empty, close tags are generated for each tag on the stack.
#
#	in_tag = 0;
#
#	for ( n = 1; n <= idx; n += 1 ) {
#
#		if ( type[n] == "attrib" ) printf( " %s", item[n] );
#
#		else if ( type[n] == "begin" ) {
#			if ( in_tag ) printf( ">" );
#			else in_tag = 1;
#			printf( "<%s", item[n] );
#		}
#
#		else if ( type[n] == "cdata" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			};
#			printf( "<![CDATA[%s]]>", item[n] );
#		}
#
#		else if ( type[n] == "comment" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			};
#			printf( "<!--%s-->", item[n] );
#		}
#
#		else if ( type[n] == "data" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			};
#			printf( "%s", item[n] );
#		}
#
#		else if ( type[n] == "decl" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			}
#			printf( "<!%s>", item[n] );
#		}
#
#		else if ( type[n] == "end" ) {
#			if ( in_tag ) {
#				printf( "/>" );
#				in_tag = 0;
#			}
#			else printf( "</%s>", item[n] );
#		}
#
#		else if ( type[n] == "error" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			};
#			print "";
#			print "<!-- ERROR:", item[n], "-->";
#			break;
#		}
#
#		else if ( type[n] == "pi" ) {
#			if ( in_tag ) {
#				printf( ">" );
#				in_tag = 0;
#			};
#			printf( "<?%s?>", item[n] );
#		}
#
#		else if ( type[n] == "value" ) {
#			if ( item[n] ~ /"/ ) printf( "='%s'", item[n] );
#			else printf( "=\"%s\"", item[n] );
#		};
#	};
#
#	if ( in_tag ) printf( "\>" );
#
#	for ( n = sptr; n; n -= 1 ) printf( "</%s>", tstack[n] );

## Print an object tree, identifying tags and attributes.  Nesting is
## emphasized by indenting.
#
#	indent = "";
#	for ( n = 1; n <= idx; n += 1 ) {
#		if ( type[n] == "attrib" ) print indent "attrib", item[n];
#		else if ( type[n] == "begin" ) {
#			print indent "begin", item[n];
#			indent = indent "  ";
#		}
#		else if ( type[n] == "end" ) {
#			indent = substr( indent, 3 );
#			print indent "end", item[n];
#		}
#		else if ( type[n] == "error" ) print "ERROR:", item[n];
#		else print indent type[n];
#	};

# Print in a linear format suitable for parsing by shell scripts.
# Multi-line values have the new-lines replaced with the character
# sequence, "\n" (backslash, n) to ensure the entire name/value pair
# occurs on a single line.  All occurances of backslashes (\) in the
# original value are themselves backslash quoted.

	for ( n = 1; n <= idx; n += 1 ) {
		value = item[n];
		gsub( /\\/, "\\\\", value );
		gsub( /\n/, "\\n", value );
		print type[n], value;
	};

	for ( n = sptr; n; n -= 1 ) print "end", tstack[n];

## Print attribute values and data in a linear format suitable for
## searching (e.g. with grep).  Attributes are representd as:
##
##	[TAG/]...TAG/ATTRIB=VALUE
##
## Data is represented as:
##
##	[TAG/]...TAG: DATA
##
## Note that all tag names are displayed in upper-case.  All attribute
## names are displayed in lower-case.
##
## Multi-line values have the new-lines replaced with the character
## sequence, "\n" (backslash, n) to ensure the entire name/value pair
## occurs on a single line.  All occurances of backslashes (\) in the
## original value are themselves backslash quoted.
#
#	sptr = 0;
#	for ( n = 1; n <= idx; n += 1 ) {
#		if ( type[n] == "attrib" ) {
#			lead = stack[1];
#			for ( m = 2; m <= sptr; m += 1 ) \
#				lead = lead "/" stack[m];
#			lead = lead "/" item[n] "=";
#		}
#		else if ( type[n] == "begin" ) stack[++sptr] = item[n];
#		else if (( type[n] == "cdata" ) || ( type[n] == "data" )) {
#			lead = stack[1];
#			for ( m = 2; m <= sptr; m += 1 ) \
#				lead = lead "/" stack[m];
#			lead = lead ": ";
#		}
#		else if ( type[n] == "end" ) sptr -= 1;
#		if (( type[n] == "data" ) || ( type[n] == "value" )) {
#			value = item[n];
#			gsub( /\\/, "\\\\", value );
#			gsub( /\n/, "\\n", value );
#			print lead value;
#		};
#	};

}
# ----- cut here -----
# 
# -- 
# Steve Coile
# 
