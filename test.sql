-- Tests for DB-l10n
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


CREATE OR REPLACE FUNCTION test.test_str_to_langtag_to_str() RETURNS VOID
	LANGUAGE plpgsql
AS $$
	DECLARE
		langtag_strs character varying[] COLLATE "C" = ARRAY[
			'ch',
 			'gsw',
 			'ab-x-abc-a-a',
 			'ab-x-abc-x-abc',
 			'aed',
 			'apa',
 			'apa-CA',
 			'apa-Latn',
 			'ar-afb',
 			'az-Arab-x-AZE-derbend',
 			'de',
 			'de-015',
 			'de-a-value',
 			'de-AT',
 			'de-Bopo-DE',
 			'de-CH',
 			'de-CH-1901',
 			'de-CH-1996',
 			'de-DE-1901',
			'de-Latg-1996',
 			'en',
			'en-a-bbb-x-a-ccc',
			'en-gb-boont-r-extended-sequence-x-private',
			'en-gb-oed',
			'en-latn-gb-boont-r-extended-sequence-x-private',
			'en-us',
			'en-us-boont',
			'en-us-x-twain',
			'en-x-us',
			'es-419',
			'es-latn-co-x-private',
			'fr',
			'fr-fr',
			'fr-latn',
			'fr-latn-419',
			'fr-latn-ca',
			'fr-latn-fr',
			'fr-y-myext-myext2',
			'hy-latn-it-arevela',
 			'i-default',
 			'i-enochian',
 			'i-klingon',
 			'I-kLINgon',
			'mn-Cyrl-MN',
			'mN-cYrL-Mn',
			'mn-Cyrl-MN',
			'mN-cYrL-Mn',
			'no',
			'no-bok',
			'sgn-aed',
			'sl-IT-nedis',
			'sl-Latn-IT-rozaj',
			'sl-nedis',
			'sr-Cyrl',
			'sr-Cyrl-CS',
			'sr-Cyrl-DE',
			'sr-Latn',
			'sr-Latn-CS',
			'x-fr-CH',
			'zh-cdo',
			'zh-cmn',
			'zh-cmn-Hans',
			'zh-cmn-Hant',
			'zh-cmn-Hant-HK',
			'zh-gan',
			'zh-yue',
 			'zh-yue-Hant-HK'
		];
		langtag_str character varying COLLATE "C";
-- module: DB-l10n
	BEGIN
		FOREACH langtag_str in ARRAY langtag_strs LOOP
			PERFORM test.assert_equal(langtag_to_str(str_to_langtag(langtag_str)), langtag_str);
		END LOOP;
		
		-- ALWAYS RAISE EXCEPTION at the end of test procs to rollback!
		RAISE EXCEPTION '[OK]';
	END
$$;

SELECT * FROM test.run_module('DB-l10n');
