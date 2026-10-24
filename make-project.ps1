$ErrorActionPreference = 'Stop'
trap { Write-Host "ERROR: $_" -ForegroundColor Red; Read-Host 'Press Enter to close'; exit 1 }

$desktop = [Environment]::GetFolderPath('Desktop')
$root = Join-Path $desktop 'MusicPlayer'
if (Test-Path $root) { Remove-Item $root -Recurse -Force }

function Write-ProjectFile([string]$relativePath, [string]$content) {
    $full = Join-Path $root $relativePath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($full, $content)
    Write-Host "Created $relativePath"
}

# ---------------------------------------------------------------- settings.gradle.kts
$c = @'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "MusicPlayer"
include(":app")
'@
Write-ProjectFile 'settings.gradle.kts' $c

# ---------------------------------------------------------------- build.gradle.kts
$c = @'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
'@
Write-ProjectFile 'build.gradle.kts' $c

# ---------------------------------------------------------------- gradle.properties
$c = @'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
'@
Write-ProjectFile 'gradle.properties' $c

# ---------------------------------------------------------------- gradle-wrapper.properties
$c = @'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.10.2-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
'@
Write-ProjectFile 'gradle/wrapper/gradle-wrapper.properties' $c

# ---------------------------------------------------------------- GitHub workflow
$c = @'
name: Build APK

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: "8.10.2"

      - name: Build
        run: gradle assembleRelease

      - uses: actions/upload-artifact@v4
        with:
          name: music-player-apk
          path: app/build/outputs/apk/release/app-release.apk
'@
Write-ProjectFile '.github/workflows/build.yml' $c

# ---------------------------------------------------------------- app/build.gradle.kts
$c = @'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.example.musicplayer"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.musicplayer"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-session:1.5.1")
}
'@
Write-ProjectFile 'app/build.gradle.kts' $c

# ---------------------------------------------------------------- AndroidManifest.xml
$c = @'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:icon="@mipmap/ic_launcher"
        android:label="Music"
        android:theme="@style/AppTheme">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".PlaybackService"
            android:exported="true"
            android:foregroundServiceType="mediaPlayback">
            <intent-filter>
                <action android:name="androidx.media3.session.MediaSessionService" />
            </intent-filter>
        </service>
    </application>
</manifest>
'@
Write-ProjectFile 'app/src/main/AndroidManifest.xml' $c

# ---------------------------------------------------------------- resources
$c = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="accent">#E8453C</color>
    <style name="AppTheme" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@android:color/black</item>
    </style>
</resources>
'@
Write-ProjectFile 'app/src/main/res/values/resources.xml' $c

$c = @'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="2.2"
        android:scaleY="2.2"
        android:translateX="27.6"
        android:translateY="27.6">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z" />
    </group>
</vector>
'@
Write-ProjectFile 'app/src/main/res/drawable/ic_launcher_foreground.xml' $c

$c = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/accent" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'@
Write-ProjectFile 'app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml' $c

# ---------------------------------------------------------------- MainActivity.kt
$c = @'
package com.example.musicplayer

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {
    private val library: LibraryViewModel by viewModels()
    private lateinit var player: PlayerConnection
    private var hasPermission by mutableStateOf(false)

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            updatePermission()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        player = PlayerConnection(this)
        hasPermission = isPermissionGranted()
        if (!hasPermission) requestAccess()

        setContent {
            AppTheme {
                Surface(Modifier.fillMaxSize(), color = Color.Black, contentColor = Color.White) {
                    if (hasPermission) MusicApp(library, player)
                    else PermissionScreen(onAllow = ::requestAccess, onOpenSettings = ::openAppSettings)
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        player.connect()
        updatePermission() // also refreshes the song list (picks up new downloads)
    }

    override fun onStop() {
        // Only disconnects the UI. The service keeps playing in the background.
        player.release()
        super.onStop()
    }

    private val audioPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun isPermissionGranted() =
        ContextCompat.checkSelfPermission(this, audioPermission) == PackageManager.PERMISSION_GRANTED

    private fun updatePermission() {
        hasPermission = isPermissionGranted()
        if (hasPermission) library.refreshSongs()
    }

    private fun requestAccess() {
        val perms = mutableListOf(audioPermission)
        if (Build.VERSION.SDK_INT >= 33) perms += Manifest.permission.POST_NOTIFICATIONS
        permissionLauncher.launch(perms.toTypedArray())
    }

    private fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
        )
    }
}
'@
Write-ProjectFile 'app/src/main/java/com/example/musicplayer/MainActivity.kt' $c

# ---------------------------------------------------------------- Library.kt
$c = @'
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
'@
Write-ProjectFile 'app/src/main/java/com/example/musicplayer/Library.kt' $c

# ---------------------------------------------------------------- Player.kt
$c = @'
package com.example.musicplayer

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.annotation.OptIn
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaController
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/** Background service that owns the player. Keeps music going after the app is closed. */
@OptIn(UnstableApi::class)
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                true // pause when a call comes in or another app plays audio
            )
            .setHandleAudioBecomingNoisy(true) // pause when headphones are unplugged
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .build()
        player.repeatMode = Player.REPEAT_MODE_ALL

        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        session = MediaSession.Builder(this, player)
            .setSessionActivity(openApp)
            .setCallback(SessionCallback())
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    // Swiped from recents: keep playing if music is playing, otherwise shut down.
    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = session?.player
        if (player == null || !player.playWhenReady || player.mediaItemCount == 0) {
            stopSelf()
        }
    }

    override fun onDestroy() {
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    private class SessionCallback : MediaSession.Callback {
        // Make sure every queued item has a playable file URI.
        override fun onAddMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: MutableList<MediaItem>,
        ): ListenableFuture<MutableList<MediaItem>> {
            val playable = mediaItems.map { item ->
                val id = item.mediaId.toLongOrNull()
                if (item.localConfiguration == null && id != null) {
                    item.buildUpon().setUri(songUri(id)).build()
                } else item
            }.toMutableList()
            return Futures.immediateFuture(playable)
        }
    }
}

fun Song.toMediaItem(): MediaItem = MediaItem.Builder()
    .setMediaId(id.toString())
    .setUri(uri)
    .setMediaMetadata(
        MediaMetadata.Builder()
            .setTitle(title)
            .setArtist(artist)
            .setAlbumTitle(album)
            .build()
    )
    .build()

/** Connects the UI to the background service. */
class PlayerConnection(private val context: Context) {
    private var future: ListenableFuture<MediaController>? = null
    private var controller: MediaController? = null

    var currentId by mutableStateOf<Long?>(null)
        private set
    var title by mutableStateOf("")
        private set
    var artist by mutableStateOf("")
        private set
    var isPlaying by mutableStateOf(false)
        private set
    var connected by mutableStateOf(false)
        private set

    private val listener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) = sync(player)
    }

    fun connect() {
        if (future != null) return
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val f = MediaController.Builder(context, token).buildAsync()
        future = f
        f.addListener({
            if (future !== f) return@addListener
            val c = runCatching { f.get() }.getOrNull() ?: return@addListener
            controller = c
            c.addListener(listener)
            sync(c)
            connected = true
        }, ContextCompat.getMainExecutor(context))
    }

    fun release() {
        controller?.removeListener(listener)
        controller = null
        connected = false
        future?.let { MediaController.releaseFuture(it) }
        future = null
    }

    private fun sync(p: Player) {
        val item = p.currentMediaItem
        currentId = item?.mediaId?.toLongOrNull()
        title = item?.mediaMetadata?.title?.toString().orEmpty()
        artist = item?.mediaMetadata?.artist?.toString().orEmpty()
        isPlaying = p.isPlaying
    }

    fun progress(): Float {
        val c = controller ?: return 0f
        val d = c.duration
        return if (d > 0) (c.currentPosition.toFloat() / d).coerceIn(0f, 1f) else 0f
    }

    fun play(songs: List<Song>, startIndex: Int) {
        val c = controller ?: return
        if (songs.isEmpty()) return
        c.shuffleModeEnabled = false
        c.setMediaItems(songs.map { it.toMediaItem() }, startIndex, 0L)
        c.prepare()
        c.play()
    }

    fun shuffle(songs: List<Song>) {
        if (songs.isNotEmpty()) play(songs.shuffled(), 0)
    }

    fun playNext(song: Song) {
        val c = controller ?: return
        if (c.mediaItemCount == 0) play(listOf(song), 0)
        else c.addMediaItem(c.currentMediaItemIndex + 1, song.toMediaItem())
    }

    fun addToQueue(song: Song) {
        val c = controller ?: return
        if (c.mediaItemCount == 0) play(listOf(song), 0)
        else c.addMediaItem(song.toMediaItem())
    }

    fun togglePlayPause() {
        val c = controller ?: return
        if (c.isPlaying) c.pause()
        else {
            if (c.playbackState == Player.STATE_IDLE) c.prepare()
            c.play()
        }
    }

    fun skipNext() {
        controller?.seekToNextMediaItem()
    }
}
'@
Write-ProjectFile 'app/src/main/java/com/example/musicplayer/Player.kt' $c

# ---------------------------------------------------------------- Ui.kt
$c = @'
package com.example.musicplayer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Build
import android.util.LruCache
import android.util.Size
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.automirrored.filled.QueueMusic
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Collections

val Accent = Color(0xFFE8453C)
private val SubText = Color(0xFF9A9A9A)
private val LineColor = Color(0xFF262626)
private val SheetColor = Color(0xFF1F1F1F)
private val Placeholder = Color(0xFF2A2A2A)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Accent,
            onPrimary = Color.White,
            background = Color.Black,
            onBackground = Color.White,
            surface = Color.Black,
            onSurface = Color.White,
            onSurfaceVariant = SubText,
            surfaceContainerLow = SheetColor,
            surfaceContainer = Color(0xFF2C2C2C),
            surfaceContainerHigh = Color(0xFF2C2C2C),
        ),
        content = content,
    )
}

/* ---------------- Album art (embedded cover of each song) ---------------- */

private object ArtLoader {
    private val cache = object : LruCache<Long, ImageBitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: Long, value: ImageBitmap) = value.width * value.height * 4
    }
    private val missing = Collections.synchronizedSet(HashSet<Long>())

    fun cached(id: Long): ImageBitmap? = cache.get(id)

    suspend fun load(context: Context, id: Long): ImageBitmap? = withContext(Dispatchers.IO) {
        cache.get(id)?.let { return@withContext it }
        if (id in missing) return@withContext null
        val bitmap = runCatching { decode(context, id) }.getOrNull()
        if (bitmap == null) {
            missing += id
            null
        } else {
            bitmap.asImageBitmap().also { cache.put(id, it) }
        }
    }

    private fun decode(context: Context, id: Long): Bitmap? {
        val uri = songUri(id)
        if (Build.VERSION.SDK_INT >= 29) {
            return context.contentResolver.loadThumbnail(uri, Size(200, 200), null)
        }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            val bytes = retriever.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= 200) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        } finally {
            retriever.release()
        }
    }
}

@Composable
fun SongArt(songId: Long?, modifier: Modifier = Modifier, corner: Dp = 8.dp) {
    val context = LocalContext.current
    var art by remember(songId) { mutableStateOf(songId?.let { ArtLoader.cached(it) }) }
    LaunchedEffect(songId) {
        if (art == null && songId != null) art = ArtLoader.load(context.applicationContext, songId)
    }
    Box(
        modifier.clip(RoundedCornerShape(corner)).background(Placeholder),
        contentAlignment = Alignment.Center,
    ) {
        val bitmap = art
        if (bitmap != null) {
            Image(bitmap, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Icon(Icons.Default.MusicNote, contentDescription = null, tint = Color(0xFF6E6E6E), modifier = Modifier.fillMaxSize(0.45f))
        }
    }
}

/* ---------------- App root ---------------- */

private data class NewPlaylistRequest(val song: Song?)

@Composable
fun MusicApp(library: LibraryViewModel, player: PlayerConnection) {
    val context = LocalContext.current
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var openPlaylistId by rememberSaveable { mutableStateOf<Long?>(null) }
    var addSongsTo by rememberSaveable { mutableStateOf<Long?>(null) }

    var menuFor by remember { mutableStateOf<Pair<Song, Long?>?>(null) }
    var pickPlaylistFor by remember { mutableStateOf<Song?>(null) }
    var newPlaylistFor by remember { mutableStateOf<NewPlaylistRequest?>(null) }
    var renameTarget by remember { mutableStateOf<Playlist?>(null) }
    var deleteTarget by remember { mutableStateOf<Playlist?>(null) }

    fun toast(msg: String) = Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()

    Column(Modifier.fillMaxSize().systemBarsPadding()) {
        Box(Modifier.weight(1f)) {
            val openPlaylist = openPlaylistId?.let { id -> library.playlists.find { it.id == id } }
            val addTarget = addSongsTo?.let { id -> library.playlists.find { it.id == id } }
            when {
                addTarget != null -> {
                    BackHandler { addSongsTo = null }
                    AddSongsScreen(
                        allSongs = library.songs,
                        existing = addTarget.songIds.toSet(),
                        onClose = { addSongsTo = null },
                        onAdd = { ids ->
                            library.addToPlaylist(addTarget.id, ids)
                            addSongsTo = null
                            toast("Added ${ids.size} song(s)")
                        },
                    )
                }
                openPlaylist != null -> {
                    BackHandler { openPlaylistId = null }
                    PlaylistScreen(
                        playlist = openPlaylist,
                        songs = library.songsOf(openPlaylist),
                        player = player,
                        onBack = { openPlaylistId = null },
                        onAddSongs = { addSongsTo = openPlaylist.id },
                        onRename = { renameTarget = openPlaylist },
                        onDelete = { deleteTarget = openPlaylist },
                        onSongMenu = { menuFor = it to openPlaylist.id },
                    )
                }
                else -> LibraryScreen(
                    library = library,
                    player = player,
                    tab = tab,
                    onTabChange = { tab = it },
                    onOpenPlaylist = { openPlaylistId = it },
                    onNewPlaylist = { newPlaylistFor = NewPlaylistRequest(null) },
                    onSongMenu = { menuFor = it to null },
                )
            }
        }
        if (player.currentId != null) MiniPlayer(player)
    }

    menuFor?.let { (song, playlistId) ->
        SongMenuSheet(
            song = song,
            showRemove = playlistId != null,
            onDismiss = { menuFor = null },
            onPlayNext = { player.playNext(song); menuFor = null; toast("Playing next") },
            onAddToQueue = { player.addToQueue(song); menuFor = null; toast("Added to queue") },
            onAddToPlaylist = { menuFor = null; pickPlaylistFor = song },
            onRemove = {
                playlistId?.let { library.removeFromPlaylist(it, song.id) }
                menuFor = null
            },
        )
    }

    pickPlaylistFor?.let { song ->
        AddToPlaylistDialog(
            playlists = library.playlists,
            onDismiss = { pickPlaylistFor = null },
            onPick = { p ->
                library.addToPlaylist(p.id, listOf(song.id))
                pickPlaylistFor = null
                toast("Added to ${p.name}")
            },
            onNew = { pickPlaylistFor = null; newPlaylistFor = NewPlaylistRequest(song) },
        )
    }

    newPlaylistFor?.let { req ->
        NameDialog(
            title = "New playlist",
            confirmLabel = "Create",
            onDismiss = { newPlaylistFor = null },
            onConfirm = { name ->
                library.createPlaylist(name, listOfNotNull(req.song?.id))
                newPlaylistFor = null
                toast(if (req.song != null) "Added to $name" else "Playlist created")
            },
        )
    }

    renameTarget?.let { p ->
        NameDialog(
            title = "Rename playlist",
            initial = p.name,
            confirmLabel = "Save",
            onDismiss = { renameTarget = null },
            onConfirm = { library.renamePlaylist(p.id, it); renameTarget = null },
        )
    }

    deleteTarget?.let { p ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("Delete playlist?") },
            text = { Text("\"${p.name}\" will be deleted. The songs stay on your phone.") },
            confirmButton = {
                TextButton(onClick = {
                    library.deletePlaylist(p.id)
                    deleteTarget = null
                    openPlaylistId = null
                }) { Text("Delete", color = Accent) }
            },
            dismissButton = {
                TextButton(onClick = { deleteTarget = null }) { Text("Cancel", color = Color.White) }
            },
        )
    }
}

/* ---------------- Library (Tracks / Playlists tabs) ---------------- */

@Composable
private fun LibraryScreen(
    library: LibraryViewModel,
    player: PlayerConnection,
    tab: Int,
    onTabChange: (Int) -> Unit,
    onOpenPlaylist: (Long) -> Unit,
    onNewPlaylist: () -> Unit,
    onSongMenu: (Song) -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        Text(
            "Library",
            fontSize = 34.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 16.dp, top = 20.dp, bottom = 12.dp),
        )
        Row(Modifier.padding(horizontal = 6.dp)) {
            listOf("Tracks", "Playlists").forEachIndexed { i, label ->
                TabLabel(label, selected = tab == i) { onTabChange(i) }
            }
        }
        if (tab == 0) TracksTab(library, player, onSongMenu)
        else PlaylistsTab(library, onOpenPlaylist, onNewPlaylist)
    }
}

@Composable
private fun TabLabel(text: String, selected: Boolean, onClick: () -> Unit) {
    Column(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp)
            .width(IntrinsicSize.Max),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text,
            fontSize = 19.sp,
            color = if (selected) Color.White else SubText,
            fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
        )
        Spacer(Modifier.height(6.dp))
        Box(
            Modifier.fillMaxWidth().height(3.dp).clip(CircleShape)
                .background(if (selected) Color.White else Color.Transparent)
        )
    }
}

@Composable
private fun TracksTab(library: LibraryViewModel, player: PlayerConnection, onSongMenu: (Song) -> Unit) {
    val songs = library.songs
    LazyColumn(Modifier.fillMaxSize()) {
        item { PlayAllRow(Icons.Default.Shuffle, "Shuffle", songs.size) { player.shuffle(songs) } }
        if (library.loaded && songs.isEmpty()) item { EmptyText("No songs found on this phone.") }
        itemsIndexed(songs, key = { _, s -> s.id }) { index, song ->
            SongRow(
                song = song,
                isCurrent = song.id == player.currentId,
                onClick = { player.play(songs, index) },
                onMore = { onSongMenu(song) },
            )
        }
    }
}

@Composable
private fun PlaylistsTab(library: LibraryViewModel, onOpen: (Long) -> Unit, onNew: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize()) {
        item {
            Row(
                Modifier.fillMaxWidth().clickable(onClick = onNew).padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)).background(Accent),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Add, contentDescription = null, tint = Color.White) }
                Spacer(Modifier.width(14.dp))
                Text("New Playlist", fontSize = 18.sp)
            }
            HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = LineColor)
        }
        if (library.playlists.isEmpty()) item { EmptyText("No playlists yet. Tap \"New Playlist\" to make one.") }
        items(library.playlists, key = { it.id }) { p ->
            val songs = library.songsOf(p)
            Row(
                Modifier.fillMaxWidth().clickable { onOpen(p.id) }.padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                PlaylistCover(songs.take(4).map { it.id }, Modifier.size(56.dp))
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(p.name, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${songs.size} track(s)", fontSize = 14.sp, color = SubText)
                }
            }
        }
    }
}

@Composable
private fun PlaylistCover(ids: List<Long>, modifier: Modifier) {
    if (ids.size < 4) {
        SongArt(ids.firstOrNull(), modifier)
    } else {
        Column(modifier.clip(RoundedCornerShape(8.dp))) {
            for (row in 0..1) {
                Row(Modifier.weight(1f).fillMaxWidth()) {
                    for (col in 0..1) {
                        SongArt(ids[row * 2 + col], Modifier.weight(1f).fillMaxHeight(), corner = 0.dp)
                    }
                }
            }
        }
    }
}

/* ---------------- Playlist detail ---------------- */

@Composable
private fun PlaylistScreen(
    playlist: Playlist,
    songs: List<Song>,
    player: PlayerConnection,
    onBack: () -> Unit,
    onAddSongs: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    onSongMenu: (Song) -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
            Text(
                playlist.name,
                fontSize = 22.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Box {
                IconButton(onClick = { menuOpen = true }) { Icon(Icons.Default.Menu, contentDescription = "Menu") }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    DropdownMenuItem(text = { Text("Add Songs") }, onClick = { menuOpen = false; onAddSongs() })
                    DropdownMenuItem(text = { Text("Rename playlist") }, onClick = { menuOpen = false; onRename() })
                    DropdownMenuItem(text = { Text("Delete playlist") }, onClick = { menuOpen = false; onDelete() })
                }
            }
        }
        LazyColumn(Modifier.fillMaxSize()) {
            item {
                PlayAllRow(Icons.Default.PlayArrow, "Play All", songs.size, onShuffle = { player.shuffle(songs) }) {
                    player.play(songs, 0)
                }
            }
            if (songs.isEmpty()) item { EmptyText("This playlist is empty. Tap the menu (top right) and choose Add Songs.") }
            itemsIndexed(songs, key = { _, s -> s.id }) { index, song ->
                SongRow(
                    song = song,
                    isCurrent = song.id == player.currentId,
                    onClick = { player.play(songs, index) },
                    onMore = { onSongMenu(song) },
                )
            }
        }
    }
}

/* ---------------- Add songs picker ---------------- */

@Composable
private fun AddSongsScreen(
    allSongs: List<Song>,
    existing: Set<Long>,
    onClose: () -> Unit,
    onAdd: (List<Long>) -> Unit,
) {
    val selected = remember { mutableStateListOf<Long>() }
    var query by rememberSaveable { mutableStateOf("") }
    val candidates = remember(allSongs, existing, query) {
        allSongs.filter {
            it.id !in existing && (query.isBlank() ||
                it.title.contains(query, ignoreCase = true) ||
                it.artist.contains(query, ignoreCase = true))
        }
    }
    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onClose) { Icon(Icons.Default.Close, contentDescription = "Close") }
            Text("Add songs", fontSize = 22.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
            TextButton(
                enabled = selected.isNotEmpty(),
                onClick = {
                    val sel = selected.toSet()
                    onAdd(allSongs.map { it.id }.filter { it in sel })
                },
            ) {
                Text(
                    "Add (${selected.size})",
                    fontSize = 16.sp,
                    color = if (selected.isNotEmpty()) Accent else SubText,
                )
            }
        }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search songs") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        )
        LazyColumn(Modifier.fillMaxSize()) {
            if (candidates.isEmpty()) item { EmptyText(if (allSongs.isEmpty()) "No songs found." else "Nothing to add.") }
            items(candidates, key = { it.id }) { song ->
                val checked = song.id in selected
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { if (checked) selected.remove(song.id) else selected.add(song.id) }
                        .padding(start = 4.dp, end = 16.dp, top = 6.dp, bottom = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Checkbox(
                        checked = checked,
                        onCheckedChange = null,
                        colors = CheckboxDefaults.colors(checkedColor = Accent),
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
                    SongArt(song.id, Modifier.size(48.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(song.title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(song.subtitle, color = SubText, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}

/* ---------------- Shared pieces ---------------- */

@Composable
private fun PlayAllRow(
    icon: ImageVector,
    label: String,
    count: Int,
    onShuffle: (() -> Unit)? = null,
    onClick: () -> Unit,
) {
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .clickable(enabled = count > 0, onClick = onClick)
                .padding(start = 16.dp, end = 8.dp, top = 10.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(width = 52.dp, height = 40.dp).clip(CircleShape).background(Accent),
                contentAlignment = Alignment.Center,
            ) { Icon(icon, contentDescription = null, tint = Color.White) }
            Spacer(Modifier.width(12.dp))
            Text(label, fontSize = 18.sp)
            Spacer(Modifier.width(8.dp))
            Text("$count track(s)", fontSize = 16.sp, color = SubText, modifier = Modifier.weight(1f))
            if (onShuffle != null && count > 0) {
                IconButton(onClick = onShuffle) { Icon(Icons.Default.Shuffle, contentDescription = "Shuffle", tint = SubText) }
            }
        }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = LineColor)
    }
}

@Composable
private fun SongRow(song: Song, isCurrent: Boolean, onClick: () -> Unit, onMore: () -> Unit) {
    val titleColor = if (isCurrent) Accent else Color.White
    val subColor = if (isCurrent) Accent else SubText
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(start = 16.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SongArt(song.id, Modifier.size(56.dp))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(song.title, color = titleColor, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(2.dp))
            Text(song.subtitle, color = subColor, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (isCurrent) {
            Icon(
                Icons.Default.GraphicEq,
                contentDescription = "Now playing",
                tint = Accent,
                modifier = Modifier.padding(start = 8.dp).size(20.dp),
            )
        }
        IconButton(onClick = onMore) { Icon(Icons.Default.MoreVert, contentDescription = "More", tint = SubText) }
    }
}

@Composable
private fun EmptyText(text: String) {
    Text(text, color = SubText, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(32.dp))
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MiniPlayer(player: PlayerConnection) {
    var progress by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(player.currentId, player.isPlaying, player.connected) {
        while (true) {
            progress = player.progress()
            if (!player.isPlaying) break
            delay(500)
        }
    }
    Row(
        Modifier
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .fillMaxWidth()
            .height(64.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFF333333)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SongArt(player.currentId, Modifier.size(64.dp), corner = 0.dp)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(player.title, fontSize = 15.sp, maxLines = 1, modifier = Modifier.basicMarquee())
            if (player.artist.isNotBlank()) {
                Text(player.artist, fontSize = 12.sp, color = SubText, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Box(
            Modifier.size(48.dp).clip(CircleShape).clickable { player.togglePlayPause() },
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(
                progress = { progress },
                modifier = Modifier.size(40.dp),
                color = Color.White,
                trackColor = Color(0xFF5A5A5A),
                strokeWidth = 2.dp,
            )
            Icon(
                if (player.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = "Play/Pause",
                modifier = Modifier.size(22.dp),
            )
        }
        IconButton(onClick = { player.skipNext() }) { Icon(Icons.Default.SkipNext, contentDescription = "Next") }
        Spacer(Modifier.width(4.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SongMenuSheet(
    song: Song,
    showRemove: Boolean,
    onDismiss: () -> Unit,
    onPlayNext: () -> Unit,
    onAddToQueue: () -> Unit,
    onAddToPlaylist: () -> Unit,
    onRemove: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SheetColor,
        contentColor = Color.White,
        dragHandle = null,
    ) {
        Column(Modifier.padding(bottom = 12.dp)) {
            Text(
                "Cancel",
                color = Accent,
                fontSize = 17.sp,
                modifier = Modifier.clickable(onClick = onDismiss).padding(horizontal = 24.dp, vertical = 20.dp),
            )
            Text(
                song.title,
                color = SubText,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 24.dp).padding(bottom = 8.dp),
            )
            SheetItem(Icons.Default.SkipNext, "Play next", onPlayNext)
            SheetItem(Icons.AutoMirrored.Filled.QueueMusic, "Add to play queue", onAddToQueue)
            SheetItem(Icons.AutoMirrored.Filled.PlaylistAdd, "Add to Playlist", onAddToPlaylist)
            if (showRemove) SheetItem(Icons.Default.Delete, "Remove from playlist", onRemove)
        }
    }
}

@Composable
private fun SheetItem(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 24.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null)
        Spacer(Modifier.width(20.dp))
        Text(label, fontSize = 17.sp)
    }
}

@Composable
private fun AddToPlaylistDialog(
    playlists: List<Playlist>,
    onDismiss: () -> Unit,
    onPick: (Playlist) -> Unit,
    onNew: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add to playlist") },
        text = {
            Column(Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) {
                DialogRow(Icons.Default.Add, "New playlist", onNew)
                playlists.forEach { p -> DialogRow(Icons.AutoMirrored.Filled.QueueMusic, p.name) { onPick(p) } }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Color.White) } },
    )
}

@Composable
private fun DialogRow(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = Accent)
        Spacer(Modifier.width(16.dp))
        Text(label, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun NameDialog(
    title: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
    initial: String = "",
) {
    var text by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                singleLine = true,
                placeholder = { Text("Playlist name") },
            )
        },
        confirmButton = {
            TextButton(enabled = text.isNotBlank(), onClick = { onConfirm(text.trim()) }) { Text(confirmLabel) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Color.White) } },
    )
}

@Composable
fun PermissionScreen(onAllow: () -> Unit, onOpenSettings: () -> Unit) {
    Column(
        Modifier.fillMaxSize().systemBarsPadding().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Default.MusicNote, contentDescription = null, tint = Accent, modifier = Modifier.size(72.dp))
        Spacer(Modifier.height(16.dp))
        Text("Allow access to your music", fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(
            "The app needs permission to read the audio files on your phone so it can list and play them.",
            color = SubText,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onAllow,
            colors = ButtonDefaults.buttonColors(containerColor = Accent, contentColor = Color.White),
        ) { Text("Allow") }
        TextButton(onClick = onOpenSettings) { Text("Open app settings", color = SubText) }
    }
}
'@
Write-ProjectFile 'app/src/main/java/com/example/musicplayer/Ui.kt' $c

# ---------------------------------------------------------------- zip it
$zip = Join-Path $desktop 'MusicPlayer.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $root '*') -DestinationPath $zip

Write-Host ''
Write-Host "Done! Project folder: $root" -ForegroundColor Green
Write-Host "Zip file: $zip" -ForegroundColor Green
Read-Host 'Press Enter to close'