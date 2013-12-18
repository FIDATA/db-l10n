#!/usr/bin/env python
# -*- coding, utf-8 -*-

# Import of predefined data (IANA Language Subtag Registry) into DB-l10n database
# Copyright © 2013  Basil Peace

# This file is part of DB-l10n.
#
# DB-l10n is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# DB-l10n is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with DB-l10n.  If not, see <http://www.gnu.org/licenses/>.

from argparse import ArgumentParser, RawDescriptionHelpFormatter

argParser = ArgumentParser(
	description = '''
DB-l10n Import of predefined data
Copyright (C) 2013  Basil Peace
  
  This program comes with ABSOLUTELY NO WARRANTY.
  This is free software, and you are welcome to redistribute it
  under certain conditions; read 'LICENSE' for details.
	''', formatter_class = RawDescriptionHelpFormatter, add_help = True
)

argParser.add_argument('--host',
	dest = 'host', action = 'store', required = False,
	help = "Name of host to connect to"
)
argParser.add_argument('--hostaddr',
	dest = 'hostaddr', action = 'store', required = False,
	help = "Numeric IP address of host to connect to"
)
argParser.add_argument('--port',
	dest = 'port', action = 'store', required = False,
	help = "Port number to connect to at the server host, or socket file name extension for Unix-domain connections"
)
argParser.add_argument('--user',
	dest = 'user', action = 'store', required = False,
	help = "PostgreSQL user name to connect as"
)
argParser.add_argument('--password',
	dest = 'password', action = 'store', required = False,
	help = "Password to be used if the server demands password authentication"
)
argParser.add_argument('--database',
	dest = 'database', action = 'store', required = False,
	help = "The database name where DB-l10n should be installed"
)
argParser.add_argument('--sslmode',
	dest = 'sslmode', action = 'store', required = False,
	help = "Method of negotiation of secure SSL TCP/IP connection"
)
argParser.add_argument('--sslcompression',
	dest = 'sslcompression', action = 'store', required = False,
	help = "Compress data sent over SSL connections"
)
argParser.add_argument('--sslcert',
	dest = 'sslcert', action = 'store', required = False,
	help = "The file name of the client SSL certificate"
)
argParser.add_argument('--sslkey',
	dest = 'sslkey', action = 'store', required = False,
	help = "The location for the secret key used for the client certificate"
)
argParser.add_argument('--sslrootcert',
	dest = 'sslrootcert', action = 'store', required = False,
	help = "The name of a file containing SSL certificate authority (CA) certificate(s)"
)
argParser.add_argument('--sslcrl',
	dest = 'sslcrl', action = 'store', required = False,
	help = "The file name of the SSL certificate revocation list (CRL)"
)
argParser.add_argument('--requirepeer',
	dest = 'requirepeer', action = 'store', required = False,
	help = "The operating-system user name of the server"
)
argParser.add_argument('--krbsrvname',
	dest = 'krbsrvname', action = 'store', required = False,
	help = "Kerberos service name to use when authenticating with Kerberos 5 or GSSAPI"
)
argParser.add_argument('--gsslib',
	dest = 'gsslib', action = 'store', required = False,
	help = "GSS library to use for GSSAPI authentication"
)

argParser.add_argument('--schema',
	dest = 'schema', action = 'store', required = False, default = 'l10n',
	help = "The schema name where DB-l10n should be installed"
)
argParser.add_argument('--log-filename',
	dest = 'logFilename', action = 'store', required = False, default = 'import.log',
	help = "filename of log"
)
argParser.add_argument('--registry',
	dest = 'registry', action = 'store', required = False,
	help = "name of file containing registry [download the latest version from internet]"
)

args = argParser.parse_args()

import psycopg2, psycopg2.extensions
conn = psycopg2.connect(
	host = args.host,
	hostaddr = args.hostaddr,
	port = args.port,
	user = args.user,
	password = args.password,
	dbname = args.database,
	sslmode = args.sslmode,
	sslcompression = args.sslcompression,
	sslcert = args.sslcert,
	sslkey = args.sslkey,
	sslrootcert = args.sslrootcert,
	sslcrl = args.sslcrl,
	requirepeer = args.requirepeer,
	krbsrvname = args.krbsrvname,
	gsslib = args.gsslib,
#	application_name = 
#   service
);
cur = conn.cursor()

# Import

conn.commit()
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
cur.execute("VACUUM ANALYZE "+tableName)
del cur, conn

metavar
FileType('r')