package com.example.monittoring_app.bridges

import android.content.SharedPreferences

// The Dart shared_preferences plugin stores ints as Long, so a plain
// getInt() throws ClassCastException once the user has set a value.
fun SharedPreferences.getIntSafe(key: String, def: Int): Int {
    return try {
        getInt(key, def)
    } catch (e: ClassCastException) {
        try {
            getLong(key, def.toLong()).toInt()
        } catch (e2: Exception) {
            def
        }
    } catch (e: Exception) {
        def
    }
}
