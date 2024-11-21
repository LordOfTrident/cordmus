import std/strutils, std/os, std/osproc, std/streams, std/options, std/times
import discord_rpc, cligen

const appId = 1255178673900884120

type Song = object
    artist, album, title, date: string
    position, duration: int
    paused: bool

let icons = [
    "blue",
    "purple",
    "pink",
    "red",
    "orange",
    "yellow",
    "rainbow",
    "rainbow-image",
    "sunset",
]

proc fetchSong(remotePath: string): Option[Song] =
    let
        p    = startProcess(remotePath, "", ["-Q"])
        strm = p.outputStream()

    var
        line: string
        song: Song
    while strm.readLine(line):
        let parts = line.split(" ", 2)
        case parts[0]:
        of "duration": song.duration = parts[1].parseInt
        of "position": song.position = parts[1].parseInt
        of "status":   song.paused   = parts[1] == "paused"

        of "tag":
            case parts[1]:
            of "artist": song.artist = parts[2]
            of "album":  song.album  = parts[2]
            of "title":  song.title  = parts[2]
            of "date":   song.date   = parts[2]

    p.close()
    if p.peekExitCode() != 1:
        return some song

proc format(str: string, song: Song): string =
    return str
        .replace("{title}",    song.title)
        .replace("{album}",    song.album)
        .replace("{artist}",   song.artist)
        .replace("{date}",     song.date)
        .replace("{duration}", $(song.duration div 60) & ":" & $(song.duration mod 60))
        .replace("{position}", $(song.position div 60) & ":" & $(song.position mod 60))
        .replace("{paused}",   if song.paused: "⏸" else: "▶")

proc sanitizeQuotes(str: string): string =
    var flag = false
    for ch in str:
        if ch == '"':
            result &= (if flag: "“" else: "”")
            flag    = not flag
        else:
            result &= ch

proc update(rpc: DiscordRPC, details, state, icon: string,
            timeLeft: bool, remotePath: string): bool =
    let
        fetched = fetchSong(remotePath)
        time    = epochTime().int
        song    = if fetched.isSome: fetched.get() else: Song()

    if song.title.len == 0:
        rpc.setActivity Activity(details: "Currently not listening to anything")
        return fetched.isSome

    var timestamps: ActivityTimestamps
    if timeLeft and not song.paused:
        timestamps.start  = time - song.position
        timestamps.finish = time - song.position + song.duration + 1

    rpc.setActivity Activity(
        details:    details.format(song).sanitizeQuotes(),
        state:      state.format(song).sanitizeQuotes(),
        timestamps: timestamps,
        assets:     some ActivityAssets(
            largeImage: icon,
            largeText: "Listening to " & song.title.sanitizeQuotes(),
        )
    )
    return true

proc printIcons() =
    echo "Available icons:"
    for icon in icons:
        echo "  " & icon

proc printFormat() =
    echo "Format variables:"
    echo "  {title}"
    echo "  {album}"
    echo "  {artist}"
    echo "  {date}"
    echo "  {duration}"
    echo "  {position}"
    echo "  {paused}"

proc cordmus(helpFormat    = false,
             helpIcons     = false,
             details       = "{title}",
             state         = "{artist} - {album} ({date})",
             icon          = icons[0],
             timeLeft      = false,
             remotePath    = "/usr/bin/cmus-remote",
             closeWithCmus = false,
             updateDelay   = 1000) =
    if helpFormat:
        printFormat()
        return
    if helpIcons:
        printIcons()
        return

    if icon notin icons:
        echo "Unknown icon \"" & icon & "\""

    let
        iconAsset = "icon-" & icon
        rpc       = newDiscordRPC(appId)
    discard rpc.connect()

    var cmusRunning = true
    while cmusRunning or not closeWithCmus:
        cmusRunning = rpc.update(details, state, iconAsset, timeLeft, remotePath)
        sleep(updateDelay)

    quit()

when isMainModule:
    dispatch cordmus, help = {
        "details":       "Set the details format string",
        "state":         "Set the state format string",
        "icon":          "Set the icon",
        "timeLeft":      "Show the song time left",
        "remotePath":    "Set the cmus-remote path",
        "closeWithCmus": "Close when cmus is not running",
        "updateDelay":   "Set the delay between updates (miliseconds)",
        "helpFormat":    "Print the format variables",
        "helpIcons":     "Print the available icons",
    }
