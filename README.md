DB-l10n
=======

This software provides you ability to localize content of your database. Under
localization I mean store of localized strings (e.g. names of goods) inside your database.


== Language Tags and Locale Identifiers ==

BEST PRACTICE: Use language as the core of locale identifiers.
BEST PRACTICE: Use [BCP 47] for language identifiers and as the basis for locale identification.

See this W3C Working Draft:
Language Tags and Locale Identifiers for the World Wide Web
[http://www.w3.org/International/core/langtags/]


== Database localization techniques ==
Let us have table named "main" and localizable column (varchar) inside it named "string".

=== Method 1. Use columns inside main table ==
We add columns "string.en", "string.ru", "string.sr-Latn", "string.sr-Cyrl" and so on.
Pros:
1. Comfortable for translators (?)
2. 
Cons:
1. Full set of valid language tags is giganteous.
Method should be used only when there are some fixed number of localizations, and they should be complete as much as possible.

=== Method 2. Use tables according to language tags ===
We create tables "


Cons:
1. The same as you have with method 1.

Something like it is used by GetText.

=== Method 3: Use separate table for each localizable table ===
Pros:

Cons:

=== Method 4: Localize on client side instead of server side ===

=== Resolution ===
DB-l10n implements only the last technique. All others are considered by me as bad style.

Still we can't provide audio records for blind people.



== Requirements ==
1. PostgreSQL is the only supported DBMS at the moment.
I don't work much with other DBMSes, so I don't indend to port code to somewhere else.
Code uses some PostgreSQL-specific features, so it most probably can't be directly ported to any other DBMS.
2. Python 3 is required for installation
I check installation scripts with Python 3.2 and 3.3.
I'm sure i could be easily ported to Python 2, however, I see no need.
Required Python modules: psycopg2