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