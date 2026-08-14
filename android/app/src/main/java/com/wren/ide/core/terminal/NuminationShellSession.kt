package com.wren.ide.core.terminal

import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

sealed class ShellResult {
    data object Clear : ShellResult()
    data class Lines(val lines: List<ShellLine>) : ShellResult()
}

data class ShellLine(
    val text: String,
    val isError: Boolean = false,
    val isSystem: Boolean = false
)

/**
 * Shell real sobre `/system/bin/sh` en el directorio del proyecto en disco.
 * Ejecuta comandos reales del entorno Android con el directorio actual dentro
 * del workspace. No emula respuestas ni incluye paquetes de Termux: solo los
 * binarios que realmente existan en el dispositivo para esta aplicación.
 */
class NuminationShellSession(
    initialDir: File
) {
    private var workingDir: File = initialDir.apply { mkdirs() }
    private val environment = linkedMapOf(
        "HOME" to workingDir.absolutePath,
        "TERM" to "xterm-256color",
        "LANG" to "en_US.UTF-8",
        "PATH" to defaultPath()
    )

    val cwd: File get() = workingDir

    fun reset(initialDir: File) {
        workingDir = initialDir.apply { mkdirs() }
        environment["HOME"] = workingDir.absolutePath
    }

    fun execute(rawInput: String): ShellResult {
        val input = rawInput.trim()
        if (input.isEmpty()) return ShellResult.Lines(emptyList())

        val lines = when {
            input == "clear" -> return ShellResult.Clear
            input == "pwd" -> listOf(ShellLine(workingDir.absolutePath))
            input == "help" || input == "numination help" -> listOf(ShellLine(HELP_TEXT, isSystem = true))
            input == "cd" || input.startsWith("cd ") -> handleCd(input)
            input.startsWith("export ") -> handleExport(input)
            input.startsWith("numination ") -> handleNuminationBuiltin(input)
            else -> runExternal(input)
        }
        return ShellResult.Lines(lines)
    }

    private fun handleCd(input: String): List<ShellLine> {
        val target = input.removePrefix("cd").trim().ifEmpty { "~" }
        val next = resolvePath(target)
        return if (next.exists() && next.isDirectory) {
            workingDir = next
            environment["HOME"] = workingDir.absolutePath
            emptyList()
        } else {
            listOf(ShellLine("cd: no such directory: $target", isError = true))
        }
    }

    private fun handleExport(input: String): List<ShellLine> {
        val body = input.removePrefix("export ").trim()
        val eq = body.indexOf('=')
        if (eq <= 0) {
            return listOf(ShellLine("export: invalid syntax", isError = true))
        }
        val key = body.substring(0, eq).trim()
        var value = body.substring(eq + 1).trim()
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith('\'') && value.endsWith('\''))
        ) {
            value = value.substring(1, value.length - 1)
        }
        environment[key] = value
        return emptyList()
    }

    private fun handleNuminationBuiltin(input: String): List<ShellLine> {
        val parts = input.split(' ').filter { it.isNotBlank() }
        return when (parts.getOrNull(1)) {
            "pwd" -> listOf(ShellLine(workingDir.absolutePath, isSystem = true))
            "ls" -> runExternal("ls -la")
            "help" -> listOf(ShellLine(HELP_TEXT, isSystem = true))
            else -> listOf(
                ShellLine(
                    "numination: unknown subcommand '${parts.getOrNull(1)}'. Try 'numination help'.",
                    isError = true
                )
            )
        }
    }

    private fun runExternal(command: String): List<ShellLine> {
        return try {
            val builder = ProcessBuilder("/system/bin/sh", "-c", command)
                .directory(workingDir)
                .redirectErrorStream(true)
            builder.environment().putAll(environment)
            val process = builder.start()

            val outputReader = shellExecutor.submit<String> {
                process.inputStream.bufferedReader().use { it.readText() }
            }

            val completed = process.waitFor(120, TimeUnit.SECONDS)
            if (!completed) {
                process.destroyForcibly()
                return listOf(ShellLine("Command timed out after 120s", isError = true))
            }

            val output = outputReader.get(5, TimeUnit.SECONDS).trimEnd()
            val exitCode = process.exitValue()
            val result = mutableListOf<ShellLine>()
            if (output.isNotEmpty()) {
                result += ShellLine(output, isError = exitCode != 0)
            }
            if (exitCode != 0 && output.isEmpty()) {
                result += ShellLine("Exit code $exitCode", isError = true)
            }
            result
        } catch (e: Exception) {
            listOf(ShellLine("shell error: ${e.message ?: "unknown"}", isError = true))
        }
    }

    private fun resolvePath(target: String): File {
        val normalized = when {
            target == "~" || target.isEmpty() -> workingDir
            target.startsWith("/") -> File(target)
            target == ".." -> workingDir.parentFile ?: workingDir
            target == "." -> workingDir
            else -> File(workingDir, target)
        }
        return normalized.canonicalFile
    }

    private fun defaultPath(): String {
        val extras = listOf(
            "/system/bin",
            "/system/xbin",
            "/vendor/bin",
            "/data/data/com.termux/files/usr/bin"
        ).filter { File(it).exists() }
        return (extras + System.getenv("PATH").orEmpty().split(':'))
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(":")
    }

    companion object {
        private val shellExecutor = Executors.newCachedThreadPool { runnable ->
            Thread(runnable, "numination-shell-output").apply { isDaemon = true }
        }

        private val HELP_TEXT = """
            Numination Shell — real Android sh in your project workspace.

            Built-ins:
              cd [dir]          change directory
              pwd               print working directory
              clear             clear screen
              export KEY=VAL    set session variable
              help              this message

            Numination:
              numination pwd    workspace path
              numination ls     list project files

            Runs real binaries available to Numination: ls, cat, mkdir, rm,
            cp, mv and sh scripts. This shell does not emulate or install
            Termux packages.
        """.trimIndent()
    }
}
