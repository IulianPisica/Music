# Felis Music: setup

Felis Music takes a list of songs and finds each one in free, legal catalogs. It does **not**
use the Spotify API (that needs Premium), so you need no Spotify keys at all.

## 1. Get your songs in

| Method | Steps |
|---|---|
| **Paste songs** | Tap *Paste songs*, one song per line: `Title - Artist`. |
| **Exportify CSV** | Go to exportify.net, log in with a free Spotify account, export a playlist as CSV, then tap *Import file* in the app. |
| **Spotify data export** | Spotify account > Privacy > "Download your data" (free; the email takes a few days). Unzip it and import `Playlist1.json` (your playlists) or `YourLibrary.json` (liked songs) with *Import file*. If the file holds several playlists, the app lets you pick one. |

## 2. Catalogs and keys

Open the gear icon in the app to turn catalogs on or off. They are searched top to bottom.

| Catalog | What you get | Key? |
|---|---|---|
| Audius | Full songs, indie artists | No |
| Jamendo | Full songs, Creative Commons | **Yes, free** |
| Openverse | Full songs, Creative Commons from many sites | No |
| Internet Archive | Full songs: live recordings, netlabels, old music | No |
| Deezer | 30-second previews, mainstream songs | No |
| iTunes | 30-second previews, mainstream songs | No |

Only **Jamendo** needs a key.

### Getting the Jamendo key
1. Go to https://devportal.jamendo.com and create a free account.
2. Create an application there.
3. Copy the **Client ID**.

### Where to put it (pick one)
- **In the app (easiest, no rebuild):** gear icon > *Jamendo key* > paste the Client ID. It works immediately.
- **Baked into the build:** in GitHub open your repo > *Settings* > *Secrets and variables* > *Actions* > *New repository secret*. Name it `JAMENDO_CLIENT_ID` and paste the Client ID as the value. The next build injects it into `Secrets.swift` automatically.
- **Local Xcode build:** replace `YOUR_JAMENDO_CLIENT_ID` in `FelisMusic/Secrets.swift`. Don't commit that change to a public repo.

If a key is typed in the app, it wins over the baked-in one. With no key, Jamendo is simply skipped.

## 3. Player

The buttons are: shuffle, previous, play/pause, next, **loop**.
Tap loop to cycle: off (grey) > loop playlist (red) > loop one song (red, "1" icon).
With loop off, playback stops after the last song.

## Notes
- Mainstream songs will mostly come back as 30-second previews. No free, legal catalog has full mainstream songs.
- Openverse limits anonymous requests, so on a very big playlist some lookups may be skipped. Re-import to retry.
