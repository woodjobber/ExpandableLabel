//
//  ExpandableLabel.swift
//  xiangzhe
//
//  Created by chengbin on 2021/9/8.
//

#if canImport(UIKit)

import UIKit

private typealias LineIndexTuple = (line: CTLine, index: Int)

/**
 * The delegate of ExpandableLabel.
 */
public protocol ExpandableLabelDelegate: AnyObject {
    func expandableLabel(_ label: ExpandableLabel, needsPerformAction action: ExpandableLabel.Action)
}

/**
 * ExpandableLabel
 */
open class ExpandableLabel: UILabel {

    public enum TextReplacementType {
        case character
        case word
    }

    public enum Action {
        case willExpand
        case didExpand
        case willCollapse
        case didCollapse
    }

    /// The delegate of ExpandableLabel
    weak open var delegate: ExpandableLabelDelegate?

    /// Set 'true' if the label should be collapsed or 'false' for expanded.
    @IBInspectable open var collapsed: Bool = true {
        didSet {
            super.attributedText = (collapsed) ? self.collapsedText : self.expandedText
            super.numberOfLines = (collapsed) ? self.collapsedNumberOfLines : 0
            if let animationView = animationView {
                UIView.animate(withDuration: 0.25) {
                    animationView.layoutIfNeeded()
                }
            }
        }
    }

    /// Set 'true' if the label can be expanded or 'false' if not.
    /// The default value is 'true'.
    @IBInspectable open var shouldExpand: Bool = true

    /// Set 'true' if the label can be collapsed or 'false' if not.
    /// The default value is 'false'.
    @IBInspectable open var shouldCollapse: Bool = false

    /// Set the link name (and attributes) that is shown when collapsed.
    /// The default value is "展开". Cannot be nil.
    @objc open var collapsedAttributedLink: NSAttributedString!

    /// Set the link name (and attributes) that is shown when expanded.
    /// The default value is "收起". Can be nil.
    @objc open var expandedAttributedLink: NSAttributedString?

    /// Set the ellipsis that appears just after the text and before the link.
    /// The default value is "...". Can be nil.
    @objc open var ellipsis: NSAttributedString?

    /// Add add a `space` charactor between ellipsis and `展开` button.
    /// The default value is "true".
    @objc open var shouldAddSpaceBetweenEllipsisAndMore: Bool = true

    /// Add trim all `space` charactor before add `展开` button.
    /// The default value is "true".
    @objc open var shouldTrimLeftSpace: Bool = true

    /// Set a view to animate changes of the label collapsed state with. If this value is nil, no animation occurs.
    /// Usually you assign the superview of this label or a UIScrollView in which this label sits.
    /// Also don't forget to set the contentMode of this label to top to smoothly reveal the hidden lines.
    /// The default value is 'nil'.
    @objc open var animationView: UIView?

    open var textReplacementType: TextReplacementType = .character

    //
    // MARK: Private
    //

    private var expandedText: NSAttributedString?
    private var collapsedText: NSAttributedString?
    private let touchSize = CGSize(width: 50, height: 50)
    private var linkRect: CGRect?
    private var collapsedNumberOfLines: Int = 0
    private var expandedLinkPosition: NSTextAlignment?
    private var collapsedLinkTextRange: NSRange?
    private var expandedLinkTextRange: NSRange?
    open var originAttributedText: NSAttributedString? {
        didSet {
            if let originAttributedText = originAttributedText, originAttributedText.length > 0 {
                self.collapsedText = getCollapsedText(for: originAttributedText, link: collapsedAttributedLink)
                self.expandedText = getExpandedText(for: originAttributedText, link: expandedAttributedLink)
                attributedText = collapsed ? collapsedText : expandedText
            } else {
                self.expandedText = nil
                self.collapsedText = nil
                attributedText = nil
            }
        }
    }

    open override var numberOfLines: Int {
        didSet {
            collapsedNumberOfLines = numberOfLines
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    public init() {
        super.init(frame: .zero)
    }
    private func safeFont(name fontName: String, size fontSize: CGFloat) -> UIFont {
        let font = UIFont(name: fontName, size: fontSize)
        if font == nil {
            return UIFont.systemFont(ofSize: fontSize)
        }
        return font!
    }
    private func commonInit() {
        self.isUserInteractionEnabled = true
        self.lineBreakMode = .byClipping
        self.collapsedNumberOfLines = numberOfLines
        let attrs: [NSAttributedString.Key : Any] = [.font: safeFont(name: "PingFangSC Regular", size: font.pointSize), .foregroundColor: UIColor(red: 0.98, green: 0.47, blue: 0.17, alpha: 1)]
        
        self.expandedAttributedLink = NSAttributedString(string: "收起", attributes: attrs)
        self.collapsedAttributedLink = NSAttributedString(string: "展开", attributes: attrs)
        self.ellipsis = NSAttributedString(string: "...", attributes: [.font: safeFont(name: "PingFangSC Regular", size: font.pointSize), .foregroundColor: textColor as Any])
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    open override var text: String? {
        set(text) {
            if let text = text {
                let attr: [NSAttributedString.Key: Any] = [
                    .font : font as Any, .foregroundColor: textColor as Any
                ]
                self.attributedText = NSAttributedString(string: text,attributes: attr)
            } else {
                self.attributedText = nil
            }
        }
        get {
            return self.attributedText?.string
        }
    }

    open override var bounds: CGRect {
        didSet {
            self.originAttributedText = self.originAttributedText?.copy() as? NSAttributedString
        }
    }

    private func textReplaceWordWithLink(_ lineIndex: LineIndexTuple, text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        var lineText = text.text(for: lineIndex.line)

        let linkText = NSMutableAttributedString()
        if let ellipsis = self.ellipsis {
            linkText.append(ellipsis)
            if shouldAddSpaceBetweenEllipsisAndMore {
                linkText.append(NSAttributedString(string: " ", attributes: [.font: font as Any]))
            }
        }
        linkText.append(linkName)
        while shouldTrimLeftSpace && lineText.string.hasSuffix(" ") {
            let length = lineText.string.endIndex.utf16Offset(in: lineText.string) - 1
            
            lineText = lineText.attributedSubstring(from: NSRange(location: 0, length: length))
        }

        var lineTextWithLink = NSMutableAttributedString(attributedString: lineText)

        lineTextWithLink.append(linkText)
        let fits = self.textFitsWidth(lineTextWithLink)
        if fits {
            return lineTextWithLink
        }
        (lineText.string as NSString).enumerateSubstrings(in: NSRange(location: 0, length: lineText.length),
                                                          options: [.byWords, .reverse]) { (_, subRange, _, stop) -> Void in
            var lineTextWithLastWordRemoved = lineText.attributedSubstring(from: NSRange(location: 0, length: subRange.location))
            if self.shouldTrimLeftSpace {
                while lineTextWithLastWordRemoved.string.hasSuffix(" ") {
                    let length = lineTextWithLastWordRemoved.string.endIndex.utf16Offset(in: lineTextWithLastWordRemoved.string) - 1
                    
                    lineTextWithLastWordRemoved = lineTextWithLastWordRemoved.attributedSubstring(from: NSRange(location: 0, length: length))
                }
            }

            let lineTextWithAddedLink = NSMutableAttributedString(attributedString: lineTextWithLastWordRemoved)

            lineTextWithAddedLink.append(linkText)
            let fits = self.textFitsWidth(lineTextWithAddedLink)
            if fits {
                lineTextWithLink = lineTextWithAddedLink
                let lineTextWithLastWordRemovedRect = lineTextWithLastWordRemoved.boundingRect(for: self.frame.size.width)
                let wordRect = linkName.boundingRect(for: self.frame.size.width)
                let width = lineTextWithLastWordRemoved.string.isEmpty ? self.frame.width : wordRect.size.width
                self.linkRect = CGRect(x: lineTextWithLastWordRemovedRect.size.width, y: self.font.lineHeight * CGFloat(lineIndex.index), width: width, height: wordRect.size.height)
                stop.pointee = true
            }
        }
        return lineTextWithLink
    }

    private func textReplaceWithLink(_ lineIndex: LineIndexTuple, text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        let lineText = text.text(for: lineIndex.line)
        let lineTextTrimmedNewLines = NSMutableAttributedString()
        lineTextTrimmedNewLines.append(lineText)
        let nsString = lineTextTrimmedNewLines.string as NSString
        let range = nsString.rangeOfCharacter(from: CharacterSet.newlines)
        if range.length > 0 {
            lineTextTrimmedNewLines.replaceCharacters(in: range, with: "")
        }
        let linkText = NSMutableAttributedString()
        if let ellipsis = self.ellipsis {
            linkText.append(ellipsis)
            if shouldAddSpaceBetweenEllipsisAndMore {
                linkText.append(NSAttributedString(string: " ", attributes: [.font: font as Any]))
            }
        }
        linkText.append(linkName)
        var numberCharacterWillDelete: Int = 0
        repeat {
            let newLength = lineTextTrimmedNewLines.string.endIndex.utf16Offset(in: lineTextTrimmedNewLines.string) - numberCharacterWillDelete
            let truncatedString = lineTextTrimmedNewLines.attributedSubstring(from: NSRange(location: 0, length: newLength))

            if (shouldTrimLeftSpace && !truncatedString.string.hasSuffix(" ")) ||
                !shouldTrimLeftSpace {
                let lineTextWithLink = NSMutableAttributedString(attributedString: truncatedString)
                lineTextWithLink.append(linkText)
                let fits = self.textFitsWidth(lineTextWithLink)
                if fits {
                    return lineTextWithLink
                }
            }
            numberCharacterWillDelete += 1
        } while numberCharacterWillDelete < lineText.string.endIndex.utf16Offset(in: lineText.string)
        lineTextTrimmedNewLines.append(linkText)
        return lineTextTrimmedNewLines
    }

    private func getExpandedText(for text: NSAttributedString?, link: NSAttributedString?) -> NSAttributedString? {
        guard let text = text else { return nil }
        let expandedText = NSMutableAttributedString()
        expandedText.append(text)
        if let link = link, textWillBeTruncated(expandedText) {
            let spaceOrNewLine = expandedLinkPosition == nil ? "  " : "\n"
            expandedText.append(NSAttributedString(string: "\(spaceOrNewLine)"))
            expandedText.append(NSMutableAttributedString(string: "\(link.string)", attributes: link.attributes(at: 0, effectiveRange: nil)))
            expandedLinkTextRange = NSRange(location: expandedText.length - link.length, length: link.length)
        }

        return expandedText
    }

    private func getCollapsedText(for text: NSAttributedString?, link: NSAttributedString) -> NSAttributedString? {
        guard let text = text else { return nil }
        let lines = text.lines(for: frame.size.width)
        if collapsedNumberOfLines > 0 && collapsedNumberOfLines < lines.count {
            let lastLineRef = lines[collapsedNumberOfLines-1] as CTLine
            var lineIndex: LineIndexTuple?
            var modifiedLastLineText: NSAttributedString?

            if self.textReplacementType == .word {
                lineIndex = (lastLineRef, collapsedNumberOfLines - 1)
                if let lineIndex = lineIndex {
                    modifiedLastLineText = textReplaceWordWithLink(lineIndex, text: text, linkName: link)
                }
            } else {
                lineIndex = (lastLineRef, collapsedNumberOfLines - 1)
                if let lineIndex = lineIndex {
                    modifiedLastLineText = textReplaceWithLink(lineIndex, text: text, linkName: link)
                }
            }

            if let lineIndex = lineIndex, let modifiedLastLineText = modifiedLastLineText {
                let collapsedLines = NSMutableAttributedString()
                for index in 0..<lineIndex.index {
                    collapsedLines.append(text.text(for: lines[index]))
                }
                collapsedLines.append(modifiedLastLineText)
                collapsedLinkTextRange = NSRange(location: collapsedLines.length - link.length, length: link.length)
                return collapsedLines
            } else {
                return nil
            }
        }
        return text
    }

    private func findLineWithWords(lastLine: CTLine, text: NSAttributedString, lines: [CTLine]) -> LineIndexTuple {
        var lastLineRef = lastLine
        var lastLineIndex = collapsedNumberOfLines - 1
        var lineWords = spiltIntoWords(str: text.text(for: lastLineRef).string as NSString)
        while lineWords.count < 2 && lastLineIndex > 0 {
            lastLineIndex -=  1
            lastLineRef = lines[lastLineIndex] as CTLine
            lineWords = spiltIntoWords(str: text.text(for: lastLineRef).string as NSString)
        }
        return (lastLineRef, lastLineIndex)
    }

    private func spiltIntoWords(str: NSString) -> [String] {
        var strings: [String] = []
        str.enumerateSubstrings(in: NSRange(location: 0, length: str.length),
                                options: [.byWords, .reverse]) { (word, _, _, stop) -> Void in
            if let unwrappedWord = word {
                strings.append(unwrappedWord)
            }
            if strings.count > 1 { stop.pointee = true }
        }
        return strings
    }

    private func textFitsWidth(_ text: NSAttributedString) -> Bool {
        var lineHeightMultiple: CGFloat = 0
        var lineSpacing: CGFloat = 0
        for index in 0..<text.length {
            if let style = text.attribute(NSAttributedString.Key.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle {
                lineHeightMultiple = max(lineHeightMultiple, style.lineHeightMultiple)
                lineSpacing = max(lineHeightMultiple, style.lineSpacing)
            }
        }
        return (text.boundingRect(for: frame.size.width).size.height <= font.lineHeight * lineHeightMultiple + lineSpacing) as Bool
    }

    private func textWillBeTruncated(_ text: NSAttributedString) -> Bool {
        let lines = text.lines(for: frame.size.width)
        return collapsedNumberOfLines > 0 && collapsedNumberOfLines < lines.count
    }

    // MARK: Touch Handling

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLinkHighlighted(touches, event: event, highlighted: true)
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLinkHighlighted(touches, event: event, highlighted: false)
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        if collapsed {
            if shouldExpand && setLinkHighlighted(touches, event: event, highlighted: false) {
                delegate?.expandableLabel(self, needsPerformAction: .willExpand)
                collapsed = false
                delegate?.expandableLabel(self, needsPerformAction: .didExpand)
            }
        } else {
            guard let range = self.expandedLinkTextRange else {
                return
            }
            /// Enlarge cliking area
            let expandrange = NSRange(location: range.location - 5, length: range.length + 5)
            if shouldCollapse && ExpandableLabel.isTouchInLabelRange(touch: touch, label: self, inRange: expandrange) {
                delegate?.expandableLabel(self, needsPerformAction: .willCollapse)
                collapsed = true
                delegate?.expandableLabel(self, needsPerformAction: .didCollapse)
                setNeedsDisplay()
            }
        }
    }

    @objc static public func isTouchInLabelRange(touch: UITouch, label: UILabel, inRange targetRange: NSRange) -> Bool {
        guard let attributedText = label.attributedText else {
            return false
        }
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize.zero)
        let textStorage = NSTextStorage(attributedString: attributedText)

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.heightTracksTextView = true
        textContainer.maximumNumberOfLines = label.numberOfLines
        let labelSize = label.bounds.size
        textContainer.size = labelSize
        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        let locationOfTouchInLabel = touch.location(in: label)

        if !textBoundingBox.contains(locationOfTouchInLabel) {
            return false
        }

        let locationOfTouchInTextContainer = CGPoint(x: locationOfTouchInLabel.x, y: locationOfTouchInLabel.y)
        let indexOfCharacter = layoutManager.characterIndex(
            for: locationOfTouchInTextContainer,
            in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        let characterBoundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: indexOfCharacter, length: 1), in: textContainer)
        if !characterBoundingRect.contains(locationOfTouchInTextContainer) {
            return false
        }
        return NSLocationInRange(Int(indexOfCharacter), targetRange)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        setLinkHighlighted(touches, event: event, highlighted: false)
    }

    open func setLessLinkWith(lessLink: String, attributes: [NSAttributedString.Key: Any], position: NSTextAlignment?) {
        var alignedattributes = attributes
        if let pos = position {
            expandedLinkPosition = pos
            let titleParagraphStyle = NSMutableParagraphStyle()
            titleParagraphStyle.alignment = pos
            alignedattributes[.paragraphStyle] = titleParagraphStyle

        }
        expandedAttributedLink = NSMutableAttributedString(string: lessLink, attributes: alignedattributes)
    }

    private func textClicked(touches: Set<UITouch>?, event: UIEvent?) -> Bool {
        let touch = event?.allTouches?.first
        let location = touch?.location(in: self)
        let textRect = self.attributedText?.boundingRect(for: self.frame.width)
        if let location = location, let textRect = textRect {
            let finger = CGRect(x: location.x - touchSize.width / 2, y: location.y - touchSize.height / 2,
                                width: touchSize.width, height: touchSize.height)
            if finger.intersects(textRect) {
                return true
            }
        }
        return false
    }

    @discardableResult private func setLinkHighlighted(_ touches: Set<UITouch>?, event: UIEvent?, highlighted: Bool) -> Bool {
        guard let touch = touches?.first else {
            return false
        }
        guard let range = self.collapsedLinkTextRange else {
            return false
        }
        /// Enlarge cliking area
        let expandrange = NSRange(location: range.location - 5, length: range.length + 5)
        if collapsed && ExpandableLabel.isTouchInLabelRange(touch: touch, label: self, inRange: expandrange) {
            setNeedsDisplay()
            return true
        }
        return false
    }
}

// MARK: Convenience Methods

private extension NSAttributedString {

    func lines(for width: CGFloat) -> [CTLine] {
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
        let frameSetterRef: CTFramesetter = CTFramesetterCreateWithAttributedString(self as CFAttributedString)
        let frameRef: CTFrame = CTFramesetterCreateFrame(frameSetterRef, CFRange(location: 0, length: 0), path.cgPath, nil)
        let linesNS: NSArray = CTFrameGetLines(frameRef)
        if let lines: [CTLine] = linesNS as? [CTLine] {
            return lines
        }
        return []
    }

    func text(for lineRef: CTLine) -> NSAttributedString {
        let lineRangeRef: CFRange = CTLineGetStringRange(lineRef)
        let range: NSRange = NSRange(location: lineRangeRef.location, length: lineRangeRef.length)
        return self.attributedSubstring(from: range)
    }

    func boundingRect(for width: CGFloat) -> CGRect {
        return self.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                 options: .usesLineFragmentOrigin, context: nil)
    }
}

#endif
