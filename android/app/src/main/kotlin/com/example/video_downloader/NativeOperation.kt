package com.example.video_downloader

import android.system.Os
import android.system.OsConstants
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class NativeOperation {
    @Volatile private var cancelled = false
    private var process: Process? = null
    private var processGroup: Int? = null
    private var committed = false

    fun checkCancelled() {
        if (cancelled) throw CancellationException("Cancelled")
    }

    @Synchronized
    fun attach(process: Process) {
        this.process = process
        if (cancelled) terminate()
    }

    @Synchronized
    fun attachGroup(pid: Int) {
        processGroup = pid
        if (cancelled) terminate()
    }

    @Synchronized
    fun cancel() {
        if (committed) return
        cancelled = true
        terminate()
    }

    @Synchronized
    fun commit(action: () -> Unit) {
        checkCancelled()
        action()
        committed = true
    }

    private fun terminate() {
        val running = process ?: return
        signalGroup(OsConstants.SIGTERM)
        running.destroy()
        terminator.schedule({
            if (running.isAlive) {
                signalGroup(OsConstants.SIGKILL)
                running.destroyForcibly()
            }
        }, 2, TimeUnit.SECONDS)
    }

    @Synchronized
    private fun signalGroup(signal: Int) {
        val pid = processGroup ?: return
        try {
            Os.kill(-pid, signal)
        } catch (_: Exception) {
        }
    }

    companion object {
        private val terminator = Executors.newSingleThreadScheduledExecutor()
    }
}
