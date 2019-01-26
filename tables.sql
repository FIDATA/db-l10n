-- DB-l10n. Localization of database content
-- Copyright © 2013  Basil Peace

/*
   This file is part of DB-l10n.

   DB-l10n is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   DB-l10n is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with DB-l10n.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
TODOs:
# Force character case on data insert (?)
# Check language_tags in tables
# function for check whether subtag is private use
# Canonicalization — ordering of extensions and something else ?
# http://www.iana.org/assignments/language-tags/language-tags.xhtml#language-tags-1 for tests
# Check for non-circular prefixes (and preferred-value)
# Regions - hierarchy
# No special checks for macrolanguage (scope, ...)

# Full text search support
*/


-- Note on case of characters:
-- Language tags should be treated and compared case-insensitive.
-- Canonicalization of language tags regularizes the case of the  subtags.  All
-- comparisons evolving non-canonical tags are made in lowercase.
-- However, tags and subtags in tables are assumed to  be  in  the  regularized
-- case. It works for  data  imported  from  IANA  registry,  but  user-defined
-- subtags should be added carefully, in proper case,  or  something  could  be
-- broken


-- Note on descriptions:
-- According to [BCP 47]:
-- 1. A particular description can be used more than once for multiple  records
--   of one type, if all of them, excepting at most  one,  are  deprecated.  If
--   there is one non-deprecated, it should be used as preferred-value  for all
--   deprecated records. Check of this rule isn't implemented yet
-- 2. Uniqueness of description should be treated  insensitively to  formatting
--   variations.  This can't  be  reached  by  DBMS  features  and   won't   be
--   implemented

-- [RFC5646] ABNF includes extlang subtag into language subtag. However, we
--   store them separately
CREATE DOMAIN language_subtag character varying(8) COLLATE "C"; -- Primary language subtag
-- See [RFC5646], sect. 2.2.2., rule 4:
-- Although ABNF allows use of three consecutive extlang subtags, subtags can't
--   be Prefixes to another extlang subtags, so only use of one extlang  subtag
--   is valid
CREATE DOMAIN extlang_subtag character varying(3) COLLATE "C";
CREATE DOMAIN script_subtag character varying(4) COLLATE "C";
CREATE DOMAIN region_subtag character varying(3) COLLATE "C";
CREATE DOMAIN variant_subtag character varying(8) COLLATE "C";
CREATE DOMAIN variant_subtags character varying(8)[] COLLATE "C";
CREATE DOMAIN extension_identifier character(1) COLLATE "C"; -- <> 'x'
CREATE DOMAIN extension_subtag character varying(8) COLLATE "C";
CREATE DOMAIN extension_subtags character varying(8)[] COLLATE "C";
CREATE TYPE extension AS (
-- 1. "identifier" is NOT NULL and differs from 'x'
-- 2. "subtags" have length >= 1
-- 3. Each item in "subtags" has length 2 to 8
	identifier extension_identifier, -- subtag ? name ?
	subtags extension_subtags
);
-- [BCP47] isn't clear whether privateuse subtag is one group of from  1  to  8
--   alphanumerical characters or is a sequence of such groups.
-- * ABNF states that privateuse subtag is a sequence starting with 'x-'
-- * Text says that each group in this sequence is separate privateuse subtag
-- We follow the latter definition, defining type for one group
CREATE DOMAIN privateuse_subtag character varying(8) COLLATE "C";
CREATE DOMAIN privateuse_subtags character varying(8)[] COLLATE "C";
CREATE DOMAIN grandfathered_tag character varying(11) COLLATE "C";
CREATE DOMAIN grandfathered_tags character varying(11)[] COLLATE "C";
CREATE TYPE language_tag AS (
-- 1. If "grandfathered" is NOT NULL, all other fields are NULL
-- 2. If "privateuse" contains at least one element, "language" can be NULL
-- 3. If "language" is NULL, all fields, except only one from "privateuse"  and
--   "grandfathered", are NULL
-- 4. If "language" is NOT NULL,  non-array  fields  ("extlang",  "script"  and
--   "region") can be NULL, can't be empty strings. Array  fields  ("variants",
--   "extensions" and "privateuse") are NOT NULL, can be zero-length
-- 5. Items of arrays of  strings  ("variants"  and  "privateuse")  are  always
--   NOT NULL and have length > 0
-- 6. Rules for items of "extensions" are described above
	language language_subtag,
	extlang extlang_subtag,
	script script_subtag,
	region region_subtag,
	variants variant_subtags,
	extensions extension[],
	privateuse privateuse_subtags,
	grandfathered grandfathered_tag
);


/*
   A tag is considered "valid" if it satisfies these conditions:

   o  The tag is well-formed.

   o  Either the tag is in the list of grandfathered tags or all of its
      primary language, extended language, script, region, and variant
      subtags appear in the IANA Language Subtag Registry as of the
      particular registry date.

   o  There are no duplicate variant subtags.

   o  There are no duplicate singleton (extension) subtags.
*/

CREATE VIEW grandfathered_tags_list(tag) AS
	SELECT
		tag::grandfathered_tag
	FROM
		(VALUES
			('en-GB-oed'),
			('i-ami'),
			('i-bnn'),
			('i-default'),
			('i-enochian'),
			('i-hak'),
			('i-klingon'),
			('i-lux'),
			('i-mingo'),
			('i-navajo'),
			('i-pwn'),
			('i-tao'),
			('i-tay'),
			('i-tsu'),
			('sgn-BE-FR'),
			('sgn-BE-NL'),
			('sgn-CH-DE'),
			('art-lojban'),
			('cel-gaulish'),
			('no-bok'),
			('no-nyn'),
			('zh-guoyu'),
			('zh-hakka'),
			('zh-min'),
			('zh-min-nan'),
			('zh-xiang')
		) AS grandfathered_tags_list(tag)
;

-- Validates language_tag
-- Returns:
--  0 = tag is valid
--  1 = tag is well-formed, but some non-custom subtags weren't recognized
--  5 = format of tag is invalid
CREATE FUNCTION validate_language_tag(langtag language_tag, OUT res int)
	LANGUAGE plpgsql STABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		variant variant_subtag;
		extension extension; 
		extension_subtag extension_subtag;
		privateuse privateuse_subtag;
	BEGIN
		-- TODO: maybe use RE (we need check for alpha(num) characters and also check for length)
		-- We can also made functions returning regular expressions for use them here and below
		res := 0;
		IF langtag.grandfathered IS NOT NULL THEN
			IF
				EXISTS(
					SELECT
						*
					FROM
						grandfathered_tags_list
					WHERE
						lower(tag) = lower(langtag.grandfathered)
				)
				AND langtag.language IS NULL
				AND langtag.extlang IS NULL
				AND langtag.script IS NULL
				AND langtag.region IS NULL
				AND langtag.variants IS NULL
				AND langtag.extensions IS NULL
				AND langtag.privateuse IS NULL
			THEN
				RETURN 0;
			ELSE
				RETURN 5;
			END IF;
		END IF;
		IF langtag.privateuse IS NULL THEN
			RETURN 5;
		END IF;
		FOREACH privateuse IN ARRAY langtag.privateuse LOOP
			IF privateuse IS NULL OT char_length(private_use) = 0 THEN
				RETURN 5;
			END IF;
		END LOOP;
		IF
			langtag.language IS NULL
		THEN
			IF 
				langtag.extlang IS NULL
				AND langtag.script IS NULL
				AND langtag.region IS NULL
				AND langtag.variants IS NULL
				AND langtag.extensions IS NULL
				AND array_length(langtag.privateuse, 1) > 0
			THEN
				RETURN 0;
			ELSE
				RETURN 5;
			END IF;
		END IF;
		IF char_length(langtag.language) = 0 THEN
			RETURN 5;
		END IF;
		IF -- TODO: custom subtags
			NOT EXISTS(
				SELECT
						*
					FROM
						languages
					WHERE
						lower(subtag) = lower(langtag.language)
			)
		THEN
			res := 1;
		END IF;
		-- TODO: check length
		IF langtag.extlang IS NOT NULL THEN
			IF char_length(langtag.extlang) = 0 THEN
				RETURN 5;
			END IF;
			IF -- TODO: custom subtags
				NOT EXISTS(
					SELECT
							*
						FROM
							extlangs
						WHERE
							lower(subtag) = lower(langtag.extlang)
				)
			THEN
				res := 1;
			END IF;
		END IF;
		-- TODO: check length
		IF langtag.script IS NOT NULL THEN
			IF char_length(langtag.script) = 0 THEN
				RETURN 5;
			END IF;
			IF -- TODO: custom subtags
				NOT EXISTS(
					SELECT
							*
						FROM
							scripts
						WHERE
							lower(subtag) = lower(langtag.script)
				)
			THEN
				res := 1;
			END IF;
		END IF;
		-- TODO: check length
		IF langtag.region IS NOT NULL THEN
			IF char_length(langtag.region) = 0 THEN
				RETURN 5;
			END IF;
			IF -- TODO: custom subtags
				NOT EXISTS(
					SELECT
							*
						FROM
							regions
						WHERE
							lower(subtag) = lower(langtag.region)
				)
			THEN
				res := 1;
			END IF;
		END IF;
		IF langtag.variants IS NULL THEN
			RETURN 5;
		END IF;
		FOREACH variant IN ARRAY langtag.variants LOOP
			IF variant IS NULL OR NOT (char_length(variant) BETWEEN 5 AND 8) THEN
				RETURN 5;
			END IF;
			IF -- TODO: custom subtags
				NOT EXISTS(
					SELECT
							*
						FROM
							variants
						WHERE
							lower(subtag) = lower(variant)
				)
			THEN
				res := 1;
			END IF;
		END LOOP;
		-- TODO: CHECK extensions
		-- FOREACH extension IN ARRAY langtag.extensions LOOP
			-- IF NOT
			-- IF variant IS NULL OR NOT (char_length(variant) BETWEEN 5 AND 8) THEN
				-- RETURN 5;
			-- END IF;
			-- IF -- TODO: custom subtags
				-- NOT EXISTS(
					-- SELECT
							-- *
						-- FROM
							-- variants
						-- WHERE
							-- lower(subtag) = lower(variant)
				-- )
			-- THEN
				-- res := 1;
			-- END IF;
		-- END LOOP;
	END
$$;

CREATE FUNCTION str_to_extension(str character varying, OUT res extension)
	LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		arr character varying[] COLLATE "C";
	BEGIN
		arr := regexp_matches(str COLLATE "C", '^([0-9a-wy-z])((?:-[0-9A-Za-z]{2,8})+)$', 'ix');
		res.identifier := arr[1];
		res.subtags := string_to_array(arr[2], '-');
		res.subtags := res.subtags[2:array_length(res.subtags, 1)];
	END
$$;

CREATE FUNCTION str_to_extensions(str character varying, OUT res extension[])
	LANGUAGE plpgsql IMMUTABLE -- RETURNS empty array on NULL input
AS $$
	DECLARE
		ext_str character varying COLLATE "C";
	BEGIN
		res := ARRAY[]::extension[];
		LOOP
			ext_str := (regexp_matches(str COLLATE "C", '^(-[0-9a-wy-z](?:-[0-9A-Za-z]{2,8})+)', 'ix'))[1];
			EXIT WHEN ext_str IS NULL;
			res := res || str_to_extension(substr(ext_str, 2)); -- Removing '-' prefix
			str := substr(str, char_length(ext_str) + 1);
		END LOOP;
	END
$$;

CREATE FUNCTION str_to_langtag(str character varying, OUT res language_tag)
	LANGUAGE plpgsql STABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		arr character varying[] COLLATE "C";
	BEGIN
-- Well-formedness doesn't depend on maybe wrong or incomplete content 
--   of tables
		IF EXISTS(
			SELECT
				*
			FROM
				grandfathered_tags_list
			WHERE
				lower(tag) = lower(str COLLATE "C")
		) THEN
			res.grandfathered := str;
		ELSE
			arr := regexp_matches(str COLLATE "C", '^
				(?:                                          # langtag
					(?:
						([a-z]{2,3})(?:-([a-z]{3}))? # language [-extlang]
						|([a-z]{4,8})
					)
					(?:-([a-z]{4}))?                         # [-script]
					(?:-([a-z]{2}|[0-9]{3}))?                # [-region]
					((?:-(?:[a-z]{5,8}|[0-9][0-9a-z]{3}))*)? # *(-variant)
					((?:-[0-9a-wy-z](?:-[0-9a-z]{2,8})+)*)?  # *(-extension)
					(?:-x((?:-[0-9a-z]{1,8})+))?             # *(-x-privateuse)
				|
					(?:x((?:-[0-9a-z]{1,8})+))?              # x-privateuse
				)
			$', 'ix');
			IF arr IS NULL THEN
				RAISE EXCEPTION 'Invalid language tag: "%"', str; -- TODO
			END IF;
			res.language := COALESCE(arr[1], arr[3]);
			res.extlang := arr[2];
			res.script := arr[4];
			res.region := arr[5];
			res.variants := string_to_array(arr[6], '-');
			IF res.variants IS NOT NULL THEN
				res.variants := res.variants[2:array_length(res.variants, 1)];
			END IF;
			res.extensions := str_to_extensions(arr[7]);
			res.privateuse := string_to_array(COALESCE(arr[8], arr[9]), '-');
			IF res.privateuse IS NOT NULL THEN
				res.privateuse := res.privateuse[2:array_length(res.privateuse, 1)];
			END IF;
		END IF;
	END
$$;

CREATE FUNCTION extension_to_str(extension extension) RETURNS character varying
	LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT
AS $$
	BEGIN
		RETURN (extension).identifier || '-' || array_to_string((extension).subtags, '-');
	END
$$;

CREATE FUNCTION extensions_to_str(extensions extension[]) RETURNS character varying
	LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		ext extension;
		res_arr character varying[] COLLATE "C" = ARRAY[]::character varying[] COLLATE "C";
	BEGIN
		FOREACH ext IN ARRAY extensions LOOP
			res_arr := res_arr || extension_to_str(ext);
		END LOOP;
		RETURN array_to_string(res_arr, '-');
	END
$$;

-- Converts language_tag to string
-- TODO: Does is suppose that language_tag is valid (or maybe canonicalized)?
CREATE FUNCTION langtag_to_str(langtag language_tag) RETURNS character varying
	LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT
AS $$
	BEGIN
		IF langtag.grandfathered IS NOT NULL THEN
			RETURN langtag.grandfathered;
		END IF;
		IF langtag.language IS NULL THEN
			RETURN 'x-' || array_to_string(langtag.privateuse, '-');
		END IF;
		RETURN
			langtag.language
			|| COALESCE('-' || langtag.extlang, '')
			|| COALESCE('-' || langtag.script, '')
			|| COALESCE('-' || langtag.region, '')
			|| CASE
				WHEN array_length(langtag.variants, 1) > 0
				THEN '-' || array_to_string(langtag.variants, '-')
				ELSE ''
			END
			|| CASE
				WHEN array_length(langtag.extensions, 1) > 0
				THEN '-' || extensions_to_str(langtag.extensions)
				ELSE ''
			END
			|| CASE
				WHEN array_length(langtag.privateuse, 1) > 0
				THEN '-x-' || array_to_string(langtag.privateuse, '-')
				ELSE ''
			END
		;
	END
$$;


CREATE FUNCTION canonicalize_language_tag_to_canonical_form(langtag language_tag, OUT res language_tag)
	LANGUAGE plpgsql STABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		i int;
		j int;
		primary_langtag language_tag;
	BEGIN
	
-- TODO:
-- Handle 'und', 'ZZ', etc.
		res := langtag;
		res.language := lower(res.language);
		res.extlang  := lower(res.extlang);
		res.script   := initcap(res.script);
		res.region   := upper(res.region);
		FOR i IN 1 .. array_length(res.variants, 1) LOOP
			res.variants[i] := lower(res.variants[i]);
		END LOOP;
		FOR i IN 1 .. array_length(res.extensions, 1) LOOP
			res.extensions[i].identifier := lower(res.extensions[i].identifier);
			FOR j IN 1 .. array_length(res.extensions[i].subtags, 1) LOOP
				res.extensions[i].subtags[j] := lower(res.extensions[i].subtags[j]);
			END LOOP;
		END LOOP;
		FOR i IN 1 .. array_length(res.privateuse, 1) LOOP
			res.privateuse[i] := lower(privateuse[i]);
		END LOOP;
		res.grandfathered := lower(res.grandfathered);
		
		IF res.extensions IS NOT NULL THEN
			res.extensions := array_agg(SELECT * FROM unnest(res.extensions) AS t ORDER BY t.indentifier);
		END IF;
		
		res := COALESCE(SELECT preferred_value FROM redundants WHERE tag = res, res);
		res := COALESCE(SELECT preferred_value FROM grandfathereds WHERE tag = res.grandfathered, res);
		
		primary_langtag := SELECT preferred_value FROM extlangs WHERE subtag = res.extlang;
		IF FOUND THEN
			res.extlang := NULL;
			res.language := primary_langtag.language;
		END IF;
		res.script := COALESCE(SELECT preferred_value FROM scripts WHERE subtag = res.script, res.script);
		res.region := COALESCE(SELECT preferred_value FROM scripts WHERE subtag = res.region, res.region);
		FOR i IN 1 .. array_length(res.variants, 1) LOOP
			res.variants[i] := COALESCE(SELECT preferred_value FROM variants WHERE subtag = res.variants[i], res.variants[i]);
		END LOOP;
		
		-- TODO: Handle Suppress-Script ?
		IF res.region = '001' THEN -- Ignore region-neutral ('World') tag
			res.region := NULL;
		END IF;
		
		-- TODO: res.extlang can still be NOT NULL (see also the next function)
	END
$$;

CREATE FUNCTION canonicalize_language_tag_to_extlang_form(langtag language_tag, OUT res language_tag)
	LANGUAGE plpgsql STABLE RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		language language_subtag;
	BEGIN
		-- 1. Canonicalize language tag
		res := canonicalize_language_tag_to_canonical_form(langtag);
		-- 2. If language subtag is also extlang subtag, then
		--    prepend tag with extlang prefix
		-- res.language is already in lowercase
		SELECT prefix FROM extlangs WHERE extlang = res.language INTO language;
		IF FOUND THEN
			res.extlang := res.language;
			res.language := language;
		END IF;
	END
$$;


CREATE TYPE scope_enum AS ENUM (
-- [BCP 47] Omission of scope field (i.e. NULL) means individual language
	'macrolanguage',
	'collection',
	'special',
	'private-use'
);


CREATE TABLE scripts (
	subtag script_subtag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value script_subtag
		REFERENCES scripts
			ON UPDATE CASCADE ON DELETE RESTRICT,
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL)
);

CREATE TABLE script_descriptions (
	id serial PRIMARY KEY,
	subtag script_subtag NOT NULL
		REFERENCES scripts
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE script_comments (
	id serial PRIMARY KEY,
	subtag script_subtag NOT NULL
		REFERENCES scripts
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE languages (
	subtag language_subtag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value language_subtag
		REFERENCES languages
			ON UPDATE CASCADE ON DELETE RESTRICT,
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL),
	suppress_script script_subtag
		REFERENCES scripts
			ON UPDATE CASCADE ON DELETE RESTRICT,
	macrolanguage language_subtag
		REFERENCES languages
			ON UPDATE CASCADE ON DELETE RESTRICT,
	scope scope_enum
);

CREATE TABLE language_descriptions (
	id serial PRIMARY KEY,
	subtag language_subtag NOT NULL
		REFERENCES languages
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE language_comments (
	id serial PRIMARY KEY,
	subtag language_subtag NOT NULL
		REFERENCES languages
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE extlangs (
	subtag extlang_subtag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value language_tag NOT NULL, -- TO THINK
	prefix language_tag NOT NULL, -- TODO: check
	suppress_script script_subtag
		REFERENCES scripts
			ON UPDATE CASCADE ON DELETE RESTRICT,
	macrolanguage language_subtag
		REFERENCES languages
			ON UPDATE CASCADE ON DELETE RESTRICT,
-- Although Scope field may present in extlang, it's meaning  is  not  entirely
--   clear (since  extlangs  can't  be  prefixes  to  another  extlangs,  scope
--   probably should not be macrolanguage or  collection).  Currently  none  of
--   extlangs in IANA registry have defined Scope  field.  So,  no  CHECKs  are
--   currently provided. Regardless of that, private-use scope has meaning
	scope scope_enum
);

CREATE TABLE extlang_descriptions (
	id serial PRIMARY KEY,
	subtag extlang_subtag NOT NULL
		REFERENCES extlangs
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE extlang_comments (
	id serial PRIMARY KEY,
	subtag extlang_subtag NOT NULL
		REFERENCES extlangs
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE regions (
	subtag region_subtag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value region_subtag
		REFERENCES regions
			ON UPDATE CASCADE ON DELETE RESTRICT,
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL)
);

CREATE TABLE region_descriptions (
	id serial PRIMARY KEY,
	subtag region_subtag NOT NULL
		REFERENCES regions
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE region_comments (
	id serial PRIMARY KEY,
	subtag region_subtag NOT NULL
		REFERENCES regions
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE variants (
	subtag variant_subtag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value variant_subtag
		REFERENCES variants
			ON UPDATE CASCADE ON DELETE RESTRICT,
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL)
);

CREATE TABLE variant_prefixes (
	subtag variant_subtag NOT NULL
		REFERENCES variants (subtag)
			ON UPDATE CASCADE ON DELETE CASCADE,
	prefix language_tag NOT NULL, -- TODO: check
	PRIMARY KEY (subtag, prefix)
);

CREATE TABLE variant_descriptions (
	id serial PRIMARY KEY,
	subtag variant_subtag NOT NULL
		REFERENCES variants
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE variant_comments (
	id serial PRIMARY KEY,
	subtag variant_subtag NOT NULL
		REFERENCES variants
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE grandfathereds (
	tag grandfathered_tag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value language_tag, -- TO THINK
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL)
);

CREATE TABLE grandfathered_descriptions (
	id serial PRIMARY KEY,
	tag grandfathered_tag NOT NULL
		REFERENCES grandfathereds
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE grandfathered_comments (
	id serial PRIMARY KEY,
	tag grandfathered_tag NOT NULL
		REFERENCES grandfathereds
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


CREATE TABLE redundants (
	tag language_tag PRIMARY KEY,
	added date NOT NULL,
	deprecated date,
	preferred_value language_tag, -- TO THINK
	CHECK (preferred_value IS NULL OR deprecated IS NOT NULL)
);

CREATE TABLE redundant_descriptions (
	id serial PRIMARY KEY,
	tag language_tag NOT NULL
		REFERENCES redundants
			ON UPDATE CASCADE ON DELETE CASCADE,
	description text NOT NULL
);

CREATE TABLE redundant_comments (
	id serial PRIMARY KEY,
	tag language_tag NOT NULL
		REFERENCES redundants
			ON UPDATE CASCADE ON DELETE CASCADE,
	comment text NOT NULL
);


-- Records for extensions are stored in the separate registry,
--   with the following differences from records for other subtags:
--   1. There is no Deprecated field
--   2. There is only one Description field
--   3. There could be at most one Comments field

CREATE TABLE extensions (
	identifier extension_identifier PRIMARY KEY, -- <> 'x'
	added date NOT NULL,
	description text NOT NULL,
	comments text,
-- TODO: Add length limits
	rfc character varying NOT NULL,
	authority character varying NOT NULL,
	contacting_email character varying NOT NULL,
	mailing_list character varying NOT NULL,
	url character varying NOT NULL
);




CREATE TYPE langtag_match_type AS ENUM (
-- TO ADD:
--   Macrolanguage/collection match

	'Exact match',
--	'Partial privateuse match',
	'Extension match',
--	'Partial extension match',
	'Variant match',
--	'Partial variant match',
	'Region match',
	'Macro region match', -- Except 001 World
	'Region-neutral match',
	'Orthographic affinity match',
	'Preferred region match',
-- According to [BCP47], extensions are orthogonal  to  language  tag  matching
--   However, some extensions (namely 't' extension  for  Transformed  Content)
--   is not orthogonal, and sometimes it can be desired to have looked  langtag
--   with extension 't' matched compared langtag  without  it  (if  application
--   can't exactly provide asked transformation)
	'Extension neutral match',
	'Any region match',
	'Any language match',
	'Script mismatch',
	'No match'
);

CREATE FUNCTION compare_langtags(langtag1 language_tag, langtag2 language_tag)
	RETURNS langtag_match_type
	LANGUAGE plpgsql STABLE RETURNS NULL ON NULL INPUT
AS $$
	BEGIN
	
	END
$$;

CREATE OPERATOR = (
	LEFTARG = language_tag,
	RIGHTARG = language_tag,
	PROCEDURE = compare_langtags,
	COMMUTATOR = =
);




CREATE TABLE orthographic_affinity(
	langtag language_tag NOT NULL PRIMARY KEY,
	affilangtag language_tag 
);




CREATE FUNCTION localize_table(
	table_name name,
	columns name[],
	table_nsp_name name DEFAULT current_schema()
) RETURNS VOID
	LANGUAGE plpgsql VOLATILE -- TODO: RETURNS NULL ON NULL INPUT
AS $$
	DECLARE
		table_oid oid;
		table_nsp_oid oid;
		i RECORD;
	BEGIN
/*
TODOs:
1. Nonexisting columns in `columns`
2. Check of datatype (character varying, text) (DOMAINS ?) (composite types ?)
3. Indices ?
4. Collation ?
*/

-- 		IF
-- 			array_length(columns) = 0
-- 		THEN
		SELECT
			oid
		FROM
			pg_namespace
		WHERE
			nspname = table_nsp_name
		INTO STRICT
			table_nsp_oid;
		SELECT
			oid
		FROM
			pg_class
		WHERE
			relname = table_name
			AND relnamespace = table_nsp_oid
		INTO STRICT
			table_oid;
		-- We rely on PostgreSQL's handling of types (column pg_attribute.atttypmod and function format_type)
		-- Especially, number of dimensions in arrays don't checked since ...
		EXECUTE '
			CREATE TABLE '||COALESCE(quote_ident(table_nsp_name)||'.', '')||quote_ident(table_name||'_l10n')+' (
				langtag '||l10n||'.language_tag PRIMARY KEY,
				'||(
					SELECT
						string_agg(column_name_type, ', ')
					FROM (
						SELECT
							quote_ident(attname)||' '|| format_type(atttypid, atttypmod) AS column_name_type
						FROM
							pg_attribute
						WHERE
							attrelid = table_oid
							AND attname IN (unnest(columns))
						ORDER BY
							attnum
					) AS columns
				)
			||');'
		;
		FOR i IN SELECT attname, format_type(atttypid, atttypmod) FROM pg_attribute WHERE attrelid = table_oid AND attname IN (unnest(columns)) ORDER BY attnum LOOP

		END LOOP;
	END
$$;
