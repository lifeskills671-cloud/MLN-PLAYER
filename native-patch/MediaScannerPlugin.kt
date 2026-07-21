package com.jpplayer.app

import android.content.ContentUris
import android.database.Cursor
import android.net.Uri
import android.provider.MediaStore
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.PermissionState
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.Permission
import com.getcapacitor.annotation.PermissionCallback
import android.Manifest

@CapacitorPlugin(
    name = "MediaScanner",
    permissions = [
        Permission(
            alias = "media",
            strings = [
                Manifest.permission.READ_MEDIA_AUDIO,
                Manifest.permission.READ_MEDIA_VIDEO
            ]
        )
    ]
)
class MediaScannerPlugin : Plugin() {

    @PluginMethod
    fun scanMedia(call: PluginCall) {
        if (getPermissionState("media") != PermissionState.GRANTED) {
            requestPermissionForAlias("media", call, "scanMediaCallback")
            return
        }
        performScan(call)
    }

    @PermissionCallback
    private fun scanMediaCallback(call: PluginCall) {
        if (getPermissionState("media") == PermissionState.GRANTED) {
            performScan(call)
        } else {
            call.reject("Ruhusa ya kusoma sauti/video haijatolewa na mtumiaji.")
        }
    }

    private fun performScan(call: PluginCall) {
        val audio = JSArray()
        val video = JSArray()
        queryMedia(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, audio)
        queryMedia(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, video)

        val result = JSObject()
        result.put("audio", audio)
        result.put("video", video)
        call.resolve(result)
    }

    private fun queryMedia(collectionUri: Uri, out: JSArray) {
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.RELATIVE_PATH
        )
        val cursor: Cursor? = context.contentResolver.query(
            collectionUri, projection, null, null,
            MediaStore.MediaColumns.DISPLAY_NAME + " ASC"
        )
        cursor?.use {
            val idCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val pathCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
            while (it.moveToNext()) {
                val id = it.getLong(idCol)
                val contentUri = ContentUris.withAppendedId(collectionUri, id)
                val item = JSObject()
                item.put("uri", contentUri.toString())
                item.put("name", it.getString(nameCol) ?: "")
                item.put("size", it.getLong(sizeCol))
                item.put("folder", it.getString(pathCol) ?: "")
                out.put(item)
            }
        }
    }
}
