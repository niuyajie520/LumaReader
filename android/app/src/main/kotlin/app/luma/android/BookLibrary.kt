package app.luma.android

import android.content.Context
import android.net.Uri
import org.w3c.dom.Element
import java.io.File
import java.util.zip.ZipFile
import javax.xml.parsers.DocumentBuilderFactory

/** 一本书的章节（已从 EPUB 里取出来，正文是 HTML 片段）。 */
data class Chapter(val title: String, val html: String, val href: String)

data class Book(
    val id: String,
    val title: String,
    val author: String,
    val file: File,
    val chapters: List<Chapter>,
)

/**
 * 极简 EPUB 读取：解 zip → `META-INF/container.xml` 找 OPF → 读 spine 顺序 →
 * 把每章 XHTML 取出、把图片改成 `file://` 绝对路径。
 *
 * 只支持 EPUB 2/3 的常规结构；TXT / Markdown 走 [BookLibrary.importPlainText]。
 */
object BookLibrary {

    private val supported = setOf("epub", "txt", "md", "markdown", "html", "htm")

    fun booksDir(context: Context): File = File(context.filesDir, "Books").apply { mkdirs() }

    fun shelf(context: Context): List<Book> =
        booksDir(context).listFiles { file -> file.extension.lowercase() in supported }
            ?.sortedBy { it.name }
            ?.mapNotNull { file ->
                runCatching { open(context, file) }.onFailure {
                    android.util.Log.e("LumaBooks", "打开 ${file.name} 失败", it)
                }.getOrNull()
            }
            ?: emptyList()

    fun importBook(context: Context, uri: Uri, displayName: String?): Book? {
        val name = displayName?.takeIf { it.isNotBlank() } ?: "book-${System.currentTimeMillis()}.epub"
        val target = File(booksDir(context), sanitize(name))
        context.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        return runCatching { open(context, target) }.getOrNull()
    }

    fun open(context: Context, file: File): Book {
        if (file.extension.lowercase() != "epub") {
            val text = file.readText()
            return Book(
                id = file.name,
                title = file.nameWithoutExtension,
                author = "",
                file = file,
                chapters = listOf(Chapter(file.nameWithoutExtension, "<p>" + escape(text) + "</p>", file.name)),
            )
        }
        ZipFile(file).use { zip ->
            val extractDir = File(booksDirOf(file), file.nameWithoutExtension + ".extract")
            extract(zip, extractDir)
            val opfPath = readContainer(zip) ?: findOpf(zip)
            val opfEntry = zip.getEntry(opfPath) ?: error("EPUB 里找不到 $opfPath")
            val opfXml = zip.getInputStream(opfEntry).use { it.readBytes() }
            val opf = parse(opfXml)
            val baseDir = opfPath.substringBeforeLast('/', "")
            val title = opf.getElementsByTagNameNS("*", "title").item(0)?.textContent?.trim().orEmpty()
            val author = opf.getElementsByTagNameNS("*", "creator").item(0)?.textContent?.trim().orEmpty()
            val manifest = HashMap<String, String>()
            val items = opf.getElementsByTagNameNS("*", "item")
            for (i in 0 until items.length) {
                val element = items.item(i) as? Element ?: continue
                manifest[element.getAttribute("id")] = element.getAttribute("href")
            }
            val chapters = ArrayList<Chapter>()
            val spine = opf.getElementsByTagNameNS("*", "itemref")
            for (i in 0 until spine.length) {
                val element = spine.item(i) as? Element ?: continue
                val href = manifest[element.getAttribute("idref")] ?: continue
                val path = joinPath(baseDir, href)
                val entry = zip.getEntry(path) ?: continue
                val raw = zip.getInputStream(entry).use { it.readBytes().toString(Charsets.UTF_8) }
                val chapterTitle = Regex("<title>(.*?)</title>", RegexOption.DOT_MATCHES_ALL)
                    .find(raw)?.groupValues?.get(1)?.trim()?.takeIf { it.isNotEmpty() }
                    ?: "第 ${chapters.size + 1} 章"
                chapters.add(Chapter(chapterTitle, rewriteImages(raw, extractDir, path), path))
            }
            return Book(
                id = file.name,
                title = title.ifBlank { file.nameWithoutExtension },
                author = author,
                file = file,
                chapters = chapters,
            )
        }
    }

    fun delete(context: Context, book: Book) {
        runCatching { book.file.delete() }
    }

    // MARK: - 内部

    private fun sanitize(name: String): String =
        name.replace(Regex("[/\\\\:]"), "-").takeIf { it.isNotBlank() } ?: "book.epub"

    private fun escape(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    private fun readContainer(zip: ZipFile): String? {
        val entry = zip.getEntry("META-INF/container.xml") ?: return null
        val xml = zip.getInputStream(entry).use { it.readBytes() }
        val doc = parse(xml)
        val rootfiles = doc.getElementsByTagNameNS("*", "rootfile")
        if (rootfiles.length == 0) return null
        val fullPath = (rootfiles.item(0) as Element).getAttribute("full-path")
        return fullPath.takeIf { it.isNotBlank() }
    }

    private fun findOpf(zip: ZipFile): String =
        zip.entries().asSequence().firstOrNull { it.name.endsWith(".opf") }?.name
            ?: error("这不是一个有效的 EPUB（没有 OPF）")

    private fun parse(bytes: ByteArray): org.w3c.dom.Document {
        val factory = DocumentBuilderFactory.newInstance()
        factory.isNamespaceAware = true
        // Android 的 XML 解析器不认这个特性，静默忽略即可（不联网解析 DTD 本就是默认行为）。
        runCatching {
            factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
        }
        return factory.newDocumentBuilder().parse(bytes.inputStream())
    }

    private fun joinPath(base: String, href: String): String {
        if (base.isBlank()) return href
        val parts = (base + "/" + href).split("/")
        val stack = ArrayDeque<String>()
        for (part in parts) {
            when (part) {
                "", "." -> Unit
                ".." -> if (stack.isNotEmpty()) stack.removeLast()
                else -> stack.addLast(part)
            }
        }
        return stack.joinToString("/")
    }

    private fun booksDirOf(file: File): File = file.parentFile ?: file.absoluteFile.parentFile

    /** 整本解压到 `<书>.extract/`，图片和样式直接用 file:// 引用；重复打开时跳过已存在的文件。 */
    private fun extract(zip: ZipFile, dir: File) {
        if (dir.exists() && dir.listFiles()?.isNotEmpty() == true) return
        dir.mkdirs()
        val entries = zip.entries()
        while (entries.hasMoreElements()) {
            val entry = entries.nextElement()
            if (entry.isDirectory) continue
            val target = File(dir, entry.name)
            if (!target.canonicalPath.startsWith(dir.canonicalPath)) continue
            target.parentFile?.mkdirs()
            runCatching {
                zip.getInputStream(entry).use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
    }

    /** 把 `<img src="...">` 改成指向解压目录，WebView 才能显示图片。 */
    private fun rewriteImages(html: String, extractDir: File, chapterPath: String): String {
        val chapterDir = chapterPath.substringBeforeLast('/', "")
        return Regex("(src|href)=\"([^\"]+)\"").replace(html) { match ->
            val attr = match.groupValues[1]
            val ref = match.groupValues[2]
            if (ref.startsWith("http") || ref.startsWith("data:") || ref.startsWith("#")) {
                match.value
            } else {
                val resolved = joinPath(chapterDir, ref)
                "$attr=\"file://${File(extractDir, resolved).path}\""
            }
        }
    }
}
