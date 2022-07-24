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
import pkg/[chronicles, zippy/ziparchives]

type HttpStatusError* = object of CatchableError

proc raiseForStatus(resp: Response | AsyncResponse) =
  ## Raises HttpStatusError if the response was a 4xx or 5xx status code.
  if resp.code.is4xx or resp.code.is5xx:
    raise newException(
      HttpStatusError,
      "Response failed with status code " & $resp.code
    )

proc cleanFilename(filename: string): string =
  ## Removes all illegal characters from a filename.
  ## See https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
  const winBadChars = {'<', '>', ':', '"', '/', '\\', '|', '?', '*'}

  result = newStringOfCap(filename.len)
  for character in filename:
    if character in winBadChars: continue
    if ord(character) < 31: continue
    # Don't allow consecutive periods
    if result.len > 0 and result[^1] == '.' and character == '.': continue

    result.add(character)

  # Remove all periods and whitespace at end of filename
  result = result.strip(leading = false, chars = Whitespace + {'.'})

proc getFilenameImpl(url: Uri, resp: Response): Option[string] =
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

proc getFilename(url: Uri, resp: Response): string=
  ## Extracts filename from a url/response headers.
  ## Either uses last element in url, or Content-Disposition header.
  ## Does not raise on failure, instead logs and returns UNKNOWN.rdzip.
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
  ## Creates a unique dir name for a given path by adding (#) to the dir name.
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
  defer: removeFile(tempFile)

  let file = openFileStream(tempFile, fmWrite)
  try:
    file.write(resp.bodyStream)
  finally:
    file.close()

  let filePath = ensureDirname(folder / getFilename(url, resp).removeExtension)
  extractAll(tempFile, filePath)

  filePath.extractFilename
