 xmlparse.awk - A simple XML parser for awk

 Author:       Steve Coile <scoile@csc.com>

 Version:      1.0 (20011017)

 Synopsis:

       awk -f xmlparse.awk [FILESPEC]...

 Description:

       This script is a simple XML parser for (modern variants of) awk.
       Input in XML format is saved to two arrays, "type" and "item".

       The term, "item", as used here, refers to a distinct XML element,
       such as a tag, an attribute name, an attribute value, or data.

       The indexes into the arrays are the sequence number that a
       particular item was encountered.  For example, the third item's
       type is described by type[3], and its value is stored in item[3].

       The "type" array contains the type of the item encountered for
       each sequence number.  Types are expressed as a single word:
       "error" (invalid item or other error), "begin" (open tag),
       "attrib" (attribute name), "value" (attribute value), "end"
       (close tag), and "data" (data between tags).

       The "item" array contains the value of the item encountered
       for each sequence number.  For types "begin" and "end", the
       item value is the name of the tag.  For "error", the value is
       the text of the error message.  For "attrib", the value is the
       attribute name.  For "value", the value is the attribute value.
       For "data", the value is the raw data.

       WARNING: XML-quoted values ("entities") in the data and attribute
       values are *NOT* unquoted; they are stored as-is.

