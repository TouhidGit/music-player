package com.example.musicplayer

import android.app.Application
import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class Song(val id: Long, val title: String, val artist: String, val album: String) {
    val uri: Uri get() = songUri(id)
    val subtitle: String get() = if (album.isBlank()) artist else "$artist - $album"
}

data class Playlist(val id: Long, val name: String, val songIds: List<Long>)

fun songUri(id: Long): Uri =
    ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)

class LibraryViewModel(app: Application) : AndroidViewModel(app) {
    private val store = PlaylistStore(app)

    var songs by mutableStateOf<List<Song>>(emptyList())
        private set
    var loaded by mutableStateOf(false)
        private set
    var playlists by mutableStateOf(store.load())
        private set
    private var songMap by mutableStateOf<Map<Long, Song>>(emptyMap())

    fun refreshSongs() {
        viewModelScope.launch {
            val result = withContext(Dispatchers.IO) { querySongs(getApplication<Application>()) }
            songMap = result.associateBy { it.id }
            songs = result
            loaded = true
        }
    }

    fun songsOf(playlist: Playlist): List<Song> = playlist.songIds.mapNotNull { songMap[it] }

    fun createPlaylist(name: String, songIds: List<Long> = emptyList()) =
        save(playlists + Playlist(System.currentTimeMillis(), name.trim(), songIds.distinct()))

    fun renamePlaylist(id: Long, name: String) =
        save(playlists.map { if (it.id == id) it.copy(name = name.trim()) else it })

    fun deletePlaylist(id: Long) = save(playlists.filterNot { it.id == id })

    fun addToPlaylist(id: Long, songIds: List<Long>) =
        save(playlists.map { if (it.id == id) it.copy(songIds = (it.songIds + songIds).distinct()) else it })

    fun removeFromPlaylist(id: Long, songId: Long) =
        save(playlists.map { if (it.id == id) it.copy(songIds = it.songIds - songId) else it })

    private fun save(list: List<Playlist>) {
        playlists = list
        store.save(list)
    }
}

private fun querySongs(context: Context): List<Song> {
    val songs = ArrayList<Song>()
    val projection = arrayOf(
        MediaStore.Audio.Media._ID,
        MediaStore.Audio.Media.TITLE,
        MediaStore.Audio.Media.ARTIST,
        MediaStore.Audio.Media.ALBUM,
    )
    // Only music files, and skip clips shorter than 30 seconds (ringtones, voice notes).
    val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= 30000"
    val sortOrder = "${MediaStore.Audio.Media.DATE_ADDED} DESC"
    try {
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, projection, selection, null, sortOrder
        )?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            while (c.moveToNext()) {
                val artist = c.getString(artistCol)
                songs += Song(
                    id = c.getLong(idCol),
                    title = c.getString(titleCol)?.takeIf { it.isNotBlank() } ?: "Unknown",
                    artist = if (artist.isNullOrBlank() || artist == "<unknown>") "Unknown Artist" else artist,
                    album = c.getString(albumCol).orEmpty(),
                )
            }
        }
    } catch (e: SecurityException) {
        // Permission not granted yet
    }
    return songs
}

private class PlaylistStore(context: Context) {
    private val prefs = context.getSharedPreferences("playlists", Context.MODE_PRIVATE)

    fun load(): List<Playlist> = try {
        val arr = JSONArray(prefs.getString("data", "[]"))
        List(arr.length()) { i ->
            val o = arr.getJSONObject(i)
            val ids = o.getJSONArray("songs")
            Playlist(o.getLong("id"), o.getString("name"), List(ids.length()) { ids.getLong(it) })
        }
    } catch (e: Exception) {
        emptyList()
    }

    fun save(list: List<Playlist>) {
        val arr = JSONArray()
        list.forEach { p ->
            arr.put(JSONObject().put("id", p.id).put("name", p.name).put("songs", JSONArray(p.songIds)))
        }
        prefs.edit().putString("data", arr.toString()).apply()
    }
}