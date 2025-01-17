#! /usr/bin/python3
# -*- coding: utf-8 -*-
"""
Automate and simplify maintenance of additional indexes on the wiki replicas
that are not present on the production databases.
"""

import argparse
import logging
import sys

import psutil
import pymysql
import requests
import yaml


def dbs_with_table(cursor, table_name, database="all"):
    """Return the names of the databases that include the table in question"""
    db_pattern = "%wik%"
    if database != "all":
        db_pattern = database

    query = """
    SELECT table_schema FROM information_schema.tables
    WHERE table_name='{table}' and table_schema
    like '{db_pat}' and table_type='BASE TABLE'
    """.format(
        table=table_name, db_pat=db_pattern
    )
    logging.debug(cursor.mogrify(query))
    cursor.execute(query)
    return [db[0] for db in cursor.fetchall()]


def dbs_on_section(section):
    """Return the names of the databases on a given section"""
    dblist = requests.get('https://noc.wikimedia.org/conf/dblists/{}.dblist'.format(section)).text
    return [i.strip() for i in dblist.split('\n') if i and i.strip()[0] != '#']


def drop_index(cursor, db_name, index, dryrun=False):
    """Drop an index"""
    query = "DROP INDEX {} on {}.{}".format(
        index["name"], db_name, index["table"]
    )
    logging.debug(cursor.mogrify(query))

    if not dryrun:
        cursor.execute(query)


def db_upgrade_check():
    """
    If mysql_upgrade is currently being run, this will lock the tables against
    DDL. This will end up queueing up and will lock other things potentially.
    Don't run if mysql_upgrade is running.
    """
    for proc in psutil.process_iter():
        try:
            pinfo = proc.as_dict(attrs=["pid", "name"])
        except psutil.NoSuchProcess:
            pass
        else:
            if "mysql_upgrade" in pinfo:
                return True

    return False


def current_index_columns(cursor, db_name, index):
    """Return currently configured columns for specified index name"""
    query = "SHOW INDEX from {}.{}".format(db_name, index["table"])
    logging.debug(cursor.mogrify(query))
    cursor.execute(query)
    index_rows = [idx for idx in cursor.fetchall() if idx[2] == index["name"]]
    if not index_rows:
        return []

    column_values = []
    for row in index_rows:
        if row[7] is not None:
            column_values.append("{}({})".format(row[4], row[7]))
        else:
            column_values.append(row[4])

    return column_values


def write_index(cursor, db_name, index, dryrun=False, debug=False):
    """Run the index statements after checking things"""
    query = """
    ALTER TABLE {}.{} ADD KEY {} ({})
    """.format(
        db_name, index["table"], index["name"], ", ".join(index["columns"])
    )
    if dryrun or debug:
        logging.info(cursor.mogrify(query))

    if not dryrun:
        cursor.execute(query)


def main():
    """Run the program"""
    # Parse the CLI
    parser = argparse.ArgumentParser(
        description="Creates and maintains indexes on a set of databases"
    )
    parser.add_argument(
        "-c",
        dest="config",
        metavar="<configuration_file>",
        type=str,
        help="location of the configuration file (YAML)",
        default="/etc/index-conf.yaml",
    )
    parser.add_argument(
        "--mysql-socket",
        help="Path to MySQL socket file",
        default="/run/mysqld/mysqld.sock",
    )
    parser.add_argument(
        "--database",
        dest="database",
        default="all",
        help="database to operate on (defaults to all %wik%)",
    )
    parser.add_argument(
        "--dry-run",
        dest="dryrun",
        action="store_true",
        default=False,
        help="Print out SQL only",
    )
    parser.add_argument(
        "--debug", dest="debug", action="store_true", default=False
    )
    args = parser.parse_args()

    logging.basicConfig(
        format="%(asctime)s %(levelname)s %(message)s",
        level=logging.DEBUG if args.debug else logging.INFO,
    )

    if db_upgrade_check():
        print("mysql_upgrade is in progress--please try again later.  Exiting.")
        sys.exit()

    with open(args.config, "r") as stream:
        try:
            config = yaml.safe_load(stream)
        except yaml.YAMLError:
            logging.exception(
                "YAML file at %s could not be opened", args.config
            )
            sys.exit(1)

    db_connections = {}
    try:
        for instance in config["mysql_instances"]:
            socket = (
                "/run/mysqld/mysqld.sock"
                if instance == "all"
                else "/run/mysqld/mysqld.{}.sock".format(instance)
            )
            db_connections[instance] = pymysql.connect(
                user=config["mysql_user"],
                passwd=config["mysql_password"],
                unix_socket=socket,
                charset="utf8",
            )

        for instance in config["mysql_instances"]:
            for index in config["indexes"]:
                with db_connections[instance].cursor() as cursor:
                    cursor.execute("SET NAMES 'utf8';")
                    cursor.execute("SET SESSION innodb_lock_wait_timeout=1;")
                    cursor.execute("SET SESSION lock_wait_timeout=60;")
                    dbs = dbs_with_table(
                        cursor, index["table"], database=args.database
                    )
                    dbs_in_section = dbs_on_section(instance)
                    dbs = sorted(list(set(dbs).intersection(set(dbs_in_section))))
                    for db_name in dbs:
                        with db_connections[instance].cursor() as change_cursor:
                            existing_index = current_index_columns(
                                change_cursor, db_name, index
                            )
                            if not existing_index:
                                write_index(
                                    change_cursor,
                                    db_name,
                                    index,
                                    args.dryrun,
                                    args.debug,
                                )
                            elif existing_index == index["columns"]:
                                logging.debug(
                                    "Skipping %s -- already exists", index["name"]
                                )
                            else:
                                drop_index(
                                    change_cursor, db_name, index, args.dryrun
                                )
                                write_index(
                                    change_cursor,
                                    db_name,
                                    index,
                                    args.dryrun,
                                    args.debug,
                                )
    finally:
        for _, conn in db_connections.items():
            conn.close()


if __name__ == "__main__":
    main()
