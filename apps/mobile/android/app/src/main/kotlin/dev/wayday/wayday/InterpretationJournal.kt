package dev.wayday.wayday

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/** Bounded private response journal. Contains no key, input text or map data.
 * A completed response is durable before the Flutter callback is delivered.
 * Pending/failed attempts survive process death and never imply a safe retry.
 */
class InterpretationJournal(private val file: File) {
    data class Entry(val key: String, val state: String, val response: String? = null,
                     val failure: String? = null)

    fun find(key: String): Entry? = read().firstOrNull { it.key == key }

    fun put(entry: Entry, recoverCorrupt: Boolean = false) {
        validate(entry)
        val entries = try { read() } catch (error: IOException) {
            if (!recoverCorrupt) throw error
            emptyList()
        }
        val updated = listOf(entry) + entries.filter { it.key != entry.key }.take(7)
        file.parentFile?.mkdirs()
        val pending = File(file.parentFile, file.name + ".pending")
        FileOutputStream(pending).use { output ->
            val data = DataOutputStream(output)
            data.writeUTF("WAYDAY_INTERPRETATION_1")
            data.writeInt(updated.size)
            for (value in updated) {
                data.writeUTF(value.key)
                data.writeUTF(value.state)
                data.writeUTF(value.failure.orEmpty())
                val bytes = value.response?.toByteArray(Charsets.UTF_8)
                data.writeInt(bytes?.size ?: -1)
                if (bytes != null) data.write(bytes)
            }
            data.flush()
            output.fd.sync()
        }
        if (!pending.renameTo(file)) throw IOException("Interpretation storage unavailable")
    }

    private fun read(): List<Entry> {
        if (!file.exists()) return emptyList()
        if (file.length() !in 1..1300000) throw IOException("Invalid interpretation journal")
        try {
            DataInputStream(file.inputStream().buffered()).use { input ->
                if (input.readUTF() != "WAYDAY_INTERPRETATION_1") throw IOException("Unsupported interpretation journal")
                val count = input.readInt()
                if (count !in 0..8) throw IOException("Invalid interpretation count")
                val entries = (0 until count).map {
                    val key = input.readUTF()
                    val state = input.readUTF()
                    val failure = input.readUTF().ifEmpty { null }
                    val length = input.readInt()
                    if (length !in -1..150000) throw IOException("Invalid interpretation size")
                    val response = if (length == -1) null else {
                        val bytes = ByteArray(length)
                        input.readFully(bytes)
                        String(bytes, Charsets.UTF_8)
                    }
                    Entry(key, state, response, failure).also { validate(it) }
                }
                if (entries.map { it.key }.toSet().size != count || input.read() != -1) {
                    throw IOException("Invalid interpretation references")
                }
                return entries
            }
        } catch (error: Exception) {
            throw IOException("Interpretation storage could not be read", error)
        }
    }

    private fun validate(entry: Entry) {
        if (!entry.key.matches(Regex("^[a-f0-9]{64}$")) ||
            entry.state !in setOf("pending", "completed", "failed") ||
            (entry.state == "completed") != (entry.response != null) ||
            (entry.response?.toByteArray(Charsets.UTF_8)?.size ?: 0) > 150000 ||
            (entry.failure?.length ?: 0) > 100) {
            throw IOException("Invalid interpretation record")
        }
    }
}
