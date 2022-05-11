import std/[
  cookies,
  httpclient,
  options,
  os,
  streams,
  strformat,
  strtabs,
  strutils,
  tempfiles,
  uri,
]
import chronicles, zippy/ziparchives

type HttpStatusError = object of CatchableError

proc raiseForStatus(resp: Response | AsyncResponse) =
  if resp.code.is4xx or resp.code.is5xx:
    raise newException(
      HttpStatusError,
      "Response failed with status code" & $resp.code
    )

proc cleanFilename(filename: string): string =
  ## Removes all illegal characters from a filename.
  result = newStringOfCap(filename.len)
  for character in filename:
    if character notin {'<', '>', ':', '"', '/', '\\', '|', '?', '*'}:
      result.add(character)

proc getFilenameImpl(url: Uri, resp: Response): Option[string] =
  ## Extracts filename from a url/response headers.
  ## Either uses last element in url, or Content-Disposition header.
  # Check if filename is already in URL
  let (_, name, ext) = url.path.splitFile
  if ext == ".rdzip" or ext == ".zip":
    return some(name & ext)

  # Otherwise extract from Content-Disposition header
  const prefix = "attachment;"
  let cd = resp.headers.getOrDefault("Content-Disposition")

  if cd.startsWith(prefix):
    let cdData = cd[prefix.len..^1].parseCookies()
    if "filename" in cdData:
      return some(cdData["filename"])

proc getFilename(url: Uri, resp: Response): string =
  let rawFilename = getFilenameImpl(url, resp)
  if rawFilename.isSome:
    rawFilename.get().cleanFilename()
  else:
    error "Failed to get url filename, returning UNKNOWN.rdzip", url = url
    "UNKNOWN.rdzip"

proc removeExtension(path: string): string =
  let (head, name, _) = path.splitFile
  head / name

proc ensureDirname(path: string): string =
  ## Creates a unique filename for a given path by adding (#) to the filename.
  if not path.dirExists:
    return path

  let (directory, name, ext) = path.splitFile

  var index = 2
  while dirExists(directory / fmt"{name} ({index}){ext}"):
    index += 1

  directory / fmt"{name} ({index}){ext}"

proc write(a, b: Stream) =
  ## Helper funtion to write contents of one stream into another.
  while not b.atEnd:
    a.write(b.readChar())

proc downloadLevel*(client: HttpClient, url: Uri, folder: string): string =
  ## Downloads a file into the given folder, automatically gets filename
  ## from the url, and ensures it is unique. Returns the filename of the
  ## downloaded level on disk.
  let resp = client.get(url)
  resp.raiseForStatus()

  let (cfile, tempFile) = createTempFile("levelsync_", ".rdzip.temp")
  cfile.close()

  let file = openFileStream(tempFile, fmWrite)
  try:
    file.write(resp.bodyStream)
  finally:
    file.close()

  let filePath = ensureDirname(folder / getFilename(url, resp).removeExtension)
  extractAll(tempFile, filePath)

  removeFile(tempFile)

  filePath.extractFilename
