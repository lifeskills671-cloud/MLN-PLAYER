package com.jpplayer.app;

import android.Manifest;
import android.content.ContentUris;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

@CapacitorPlugin(
    name = "MediaScanner",
    permissions = {
        @Permission(
            alias = "media",
            strings = {
                Manifest.permission.READ_MEDIA_AUDIO,
                Manifest.permission.READ_MEDIA_VIDEO
            }
        )
    }
)
public class MediaScannerPlugin extends Plugin {

    @PluginMethod
    public void scanMedia(PluginCall call) {
        if (getPermissionState("media") != PermissionState.GRANTED) {
            requestPermissionForAlias("media", call, "scanMediaCallback");
            return;
        }
        performScan(call);
    }

    @PermissionCallback
    private void scanMediaCallback(PluginCall call) {
        if (getPermissionState("media") == PermissionState.GRANTED) {
            performScan(call);
        } else {
            call.reject("Ruhusa ya kusoma sauti/video haijatolewa na mtumiaji.");
        }
    }

    private void performScan(PluginCall call) {
        JSArray audio = new JSArray();
        JSArray video = new JSArray();
        queryMedia(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, audio);
        queryMedia(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, video);

        JSObject result = new JSObject();
        result.put("audio", audio);
        result.put("video", video);
        call.resolve(result);
    }

    private void queryMedia(Uri collectionUri, JSArray out) {
        String[] projection = new String[] {
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.RELATIVE_PATH
        };

        Cursor cursor = getContext().getContentResolver().query(
            collectionUri, projection, null, null,
            MediaStore.MediaColumns.DISPLAY_NAME + " ASC"
        );

        if (cursor != null) {
            try {
                int idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID);
                int nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME);
                int sizeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE);
                int pathCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH);

                while (cursor.moveToNext()) {
                    long id = cursor.getLong(idCol);
                    Uri contentUri = ContentUris.withAppendedId(collectionUri, id);
                    JSObject item = new JSObject();
                    item.put("uri", contentUri.toString());
                    String name = cursor.getString(nameCol);
                    item.put("name", name != null ? name : "");
                    item.put("size", cursor.getLong(sizeCol));
                    String folder = cursor.getString(pathCol);
                    item.put("folder", folder != null ? folder : "");
                    out.put(item);
                }
            } finally {
                cursor.close();
            }
        }
    }
}
