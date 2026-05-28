import std/[os, httpclient]
import db_connector/db_sqlite
import configs

const orchardDbName = "orchard.db"

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

  const orchardUrl = "https://datasette.rhythm.cafe/rdlevels.db"
  client.downloadFile(orchardUrl, lconfig.levelsPath / orchardDbName)

proc setupDbConnection*(): DbConn =
  ## Loads both orchard and local levels, creats a view of orchard levels that
  ## only reveals levels allowed by the user config.
  ## Returned connection must be closed
  result = open(lconfig.levelsPath / orchardDbName, "", "", "")

  result.exec(
    sql"ATTACH DATABASE ? as localLevels",
    lconfig.localLevelsDbPath
  )

  let viewQuery =
    if lconfig.checkedOnly: sql"""
      CREATE TEMP VIEW orchardLevels AS
        SELECT
          id
        FROM
          rdlevels
        WHERE (source = 'yeoldesheet' OR source = 'rdl' OR source = 'prescriptions')
          AND approval > 0
    """
    else: sql"""
      CREATE TEMP VIEW orchardLevels AS
        SELECT
          id
        FROM
          rdlevels
        WHERE source = 'yeoldesheet' OR source = 'rdl' OR source = 'prescriptions'
    """
  result.exec(viewQuery)
