package com.example.monittoring_app.monitor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class DbHelper(context: Context) : SQLiteOpenHelper(context, "monitor.db", null, DB_VERSION) {

    data class SampleRow(val ts: Long, val kind: String, val key: String, val value: Double)

    companion object {
        const val DB_VERSION = 1
        const val CREATE_TABLE =
            "CREATE TABLE IF NOT EXISTS samples(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, kind TEXT NOT NULL, key TEXT NOT NULL, value REAL NOT NULL)"
        const val CREATE_INDEX =
            "CREATE INDEX IF NOT EXISTS idx_samples ON samples(kind, key, ts)"
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(CREATE_TABLE)
        db.execSQL(CREATE_INDEX)
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        db.execSQL(CREATE_TABLE)
        db.execSQL(CREATE_INDEX)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun insertSamples(rows: List<SampleRow>) {
        if (rows.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            for (r in rows) {
                db.execSQL(
                    "INSERT INTO samples(ts, kind, key, value) VALUES(?,?,?,?)",
                    arrayOf(r.ts, r.kind, r.key, r.value)
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun prune(olderThanMs: Long) {
        writableDatabase.execSQL("DELETE FROM samples WHERE ts < ?", arrayOf(olderThanMs))
    }
}
