import std/[os, httpclient]
import db_connector/db_sqlite
import configs

proc createDb*() =
  ## Creates localLevels db
  let db = open(lconfig.localLevelsDbPath, "", "", "")
  defer: db.close()

  db.exec(sql"""
    CREATE TABLE localLevels (
      orchardId TEXT NOT NULL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE
    )
  """)

proc updateOrchardDb*() =
  ## Redownloads the orchard databases so they're up to date.
  let client = newHttpClient()
  defer: client.close()

  const orchardUrl = "https://api2.rhythm.cafe/datasette/orchard.db"
  const statusUrl = "https://api2.rhythm.cafe/datasette/status.db"
  client.downloadFile(orchardUrl, lconfig.levelsPath / "orchard.db")
  client.downloadFile(statusUrl, lconfig.levelsPath / "status.db")

proc setupDbConnection*(): DbConn =
  ## Combines orchard and localLevel dbs and makes a view
  ## Returned connection must be closed
  result = open(lconfig.levelsPath / "orchard.db", "", "", "")

  result.exec(
    sql"ATTACH DATABASE ? as status",
    lconfig.levelsPath / "status.db"
  )
  result.exec(
    sql"ATTACH DATABASE ? as localLevels",
    lconfig.localLevelsDbPath
  )

  let viewQuery =
    if lconfig.checkedOnly: sql"""
      CREATE TEMP VIEW orchardLevels AS
        SELECT
          level.id,
          url2
        FROM
          level
        LEFT JOIN status ON status.id = level.id
        WHERE COALESCE(status.approval, 0) > 0
        AND (source = 'yeoldesheet' OR source = 'rdl' OR source = 'prescriptions')
    """
    else: sql"""
      CREATE TEMP VIEW orchardLevels AS
        SELECT
          level.id,
          url2
        FROM
          level
        LEFT JOIN status ON status.id = level.id
        WHERE source = 'yeoldesheet' OR source = 'rdl' OR source = 'prescriptions'
    """
  result.exec(viewQuery)
