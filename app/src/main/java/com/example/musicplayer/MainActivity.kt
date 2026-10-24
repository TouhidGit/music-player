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