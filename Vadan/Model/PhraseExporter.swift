import Foundation
import UIKit

/**
 * Turns Library phrases into a shareable PDF (or plain text) — model/PhraseExporter.kt.
 *
 * The PDF is drawn with UIKit text drawing, so every script (Sinhala, Tamil, Devanagari, CJK,
 * Arabic…) is shaped and rendered by the system fonts. App fonts (Poppins, DM Sans) are used
 * for Latin text and fall back to the system fonts for anything else. Same A4 layout, sizes and
 * colors as Android.
 */
enum PhraseExporter {
    // A4 in PostScript points.
    private static let pageW: CGFloat = 595
    private static let pageH: CGFloat = 842
    private static let margin: CGFloat = 48
    private static let footerH: CGFloat = 16
    private static let entryGap: CGFloat = 10

    private static let ink = UIColor(hex: 0x3B403D)
    private static let body = UIColor(hex: 0x4A4F4C)
    private static let secondary = UIColor(hex: 0x626763)
    private static let tertiary = UIColor(hex: 0x8A8F8B)
    private static let clay = UIColor(hex: 0xA65950)
    private static let divider = UIColor(hex: 0xE8E6E2)

    /** Writes the PDF to Caches/exports and returns it (for the share sheet). */
    static func exportPdf(_ phrases: [Phrase], title: String) throws -> URL {
        let entries = phrases.map(entryBlock)
        let header = headerBlock(title, phrases.count)
        let pages = paginate(entries, headerHeight: header.height)
        let url = exportDir().appendingPathComponent("\(fileStem()).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        try renderer.writePDF(to: url) { context in
            for (index, pageEntries) in pages.enumerated() {
                context.beginPage()
                var y = margin
                if index == 0 { y = header.draw(top: y) }
                for entry in pageEntries {
                    // Hairline above every entry.
                    let line = UIBezierPath()
                    line.move(to: CGPoint(x: margin, y: y))
                    line.addLine(to: CGPoint(x: pageW - margin, y: y))
                    line.lineWidth = 0.5
                    divider.setStroke()
                    line.stroke()
                    y = entry.draw(top: y + entryGap)
                    y += entryGap
                }
                drawFooter(page: index + 1, total: pages.count)
            }
        }
        return url
    }

    /** Plain text for messaging apps, or a .txt file when it's too long to send as text. */
    static func exportText(_ phrases: [Phrase], title: String) -> String {
        var out = "\(title) (\(phraseCount(phrases.count)))\n"
        for phrase in phrases {
            out += "\n"
            out += "\(Languages.displayName(phrase.sourceLang)) → \(Languages.displayName(phrase.targetLang))\n"
            out += "\(phrase.original)\n"
            out += "\(phrase.translated)\n"
            if phrase.romanized.isNotBlank { out += "(\(phrase.romanized))\n" }
        }
        // Kotlin's trimEnd(): drop trailing whitespace only.
        while let last = out.last, last.isWhitespace { out.removeLast() }
        return out
    }

    static func exportTextFile(_ text: String) throws -> URL {
        let url = exportDir().appendingPathComponent("\(fileStem()).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Layout

    private struct Block {
        /** Each laid-out text with the gap after it. */
        let parts: [(text: NSAttributedString, height: CGFloat, gap: CGFloat)]

        var height: CGFloat { parts.reduce(0) { $0 + $1.height + $1.gap } }

        func draw(top: CGFloat) -> CGFloat {
            var y = top
            for part in parts {
                part.text.draw(with: CGRect(x: margin, y: y, width: pageW - margin * 2, height: part.height),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += part.height + part.gap
            }
            return y
        }
    }

    private static func entryBlock(_ phrase: Phrase) -> Block {
        let pair = "\(Languages.displayName(phrase.sourceLang)) → \(Languages.displayName(phrase.targetLang))"
        var parts = [
            layout(pair.uppercased(), labelStyle, gap: 4),
            layout(phrase.original, bodyStyle, gap: 3),
            layout(phrase.translated, phraseStyle, gap: 2),
        ]
        if phrase.romanized.isNotBlank { parts.append(layout(phrase.romanized, romanStyle, gap: 0)) }
        return Block(parts: parts)
    }

    private static func headerBlock(_ title: String, _ count: Int) -> Block {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMMM d, yyyy"
        let date = formatter.string(from: Date())
        return Block(parts: [
            layout("VADAN", brandStyle, gap: 6),
            layout(title, titleStyle, gap: 4),
            layout("\(phraseCount(count)) · Exported \(date)", metaStyle, gap: 20),
        ])
    }

    /** Splits entries over pages; an entry never breaks across two pages. */
    private static func paginate(_ entries: [Block], headerHeight: CGFloat) -> [[Block]] {
        var pages: [[Block]] = [[]]
        let bottom = pageH - margin - footerH
        var y = margin + headerHeight
        for entry in entries {
            let needed = entry.height + entryGap * 2
            if y + needed > bottom && !pages[pages.count - 1].isEmpty {
                pages.append([])
                y = margin
            }
            pages[pages.count - 1].append(entry)
            y += needed
        }
        return pages
    }

    private static func drawFooter(page: Int, total: Int) {
        let text = NSAttributedString(string: "Page \(page) of \(total)", attributes: footerStyle)
        // Right-aligned, with its baseline where Android draws it.
        let baseline = pageH - margin / 2
        text.draw(at: CGPoint(x: (pageW - margin) - text.size().width, y: baseline - dmSans(8).ascender))
    }

    private static func layout(_ text: String, _ attributes: [NSAttributedString.Key: Any], gap: CGFloat) -> (text: NSAttributedString, height: CGFloat, gap: CGFloat) {
        let string = NSAttributedString(string: text, attributes: attributes)
        let rect = string.boundingRect(
            with: CGSize(width: pageW - margin * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // A little room for tall scripts' marks above/below the line (Android's includePad).
        return (string, ceil(rect.height) + 2, gap)
    }

    // MARK: - Styles

    private static func style(_ font: UIFont, _ color: UIColor, kern: CGFloat = 0, oblique: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if kern != 0 { attrs[.kern] = kern }
        if oblique != 0 { attrs[.obliqueness] = oblique }
        return attrs
    }

    private static func poppins(_ size: CGFloat) -> UIFont { AppFont.uiFont("Poppins-SemiBold", size, fallbackWeight: .semibold) }
    private static func dmSans(_ size: CGFloat) -> UIFont { AppFont.uiFont("DMSans-Regular", size, fallbackWeight: .regular) }
    private static func dmSansBold(_ size: CGFloat) -> UIFont { AppFont.uiFont("DMSans-Bold", size, fallbackWeight: .bold) }

    private static var brandStyle: [NSAttributedString.Key: Any] { style(dmSansBold(9), clay, kern: 9 * 0.12) }
    private static var titleStyle: [NSAttributedString.Key: Any] { style(poppins(24), ink) }
    private static var metaStyle: [NSAttributedString.Key: Any] { style(dmSans(10), secondary) }
    private static var labelStyle: [NSAttributedString.Key: Any] { style(dmSansBold(7.5), secondary, kern: 7.5 * 0.08) }
    private static var bodyStyle: [NSAttributedString.Key: Any] { style(dmSans(11), body) }
    private static var phraseStyle: [NSAttributedString.Key: Any] { style(poppins(16), ink) }
    /** DM Sans has no italic file; slant it like Android's synthetic italic. */
    private static var romanStyle: [NSAttributedString.Key: Any] { style(dmSans(10.5), secondary, oblique: 0.2) }
    private static var footerStyle: [NSAttributedString.Key: Any] { style(dmSans(8), tertiary) }

    private static func exportDir() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("exports")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Only the latest export is ever needed; don't let old ones pile up.
        for file in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            try? FileManager.default.removeItem(at: file)
        }
        return dir
    }

    private static func fileStem() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "vadan-phrases-" + formatter.string(from: Date())
    }
}
