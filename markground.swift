#!/usr/bin/env xcrun swift

//
//  markground.swift
//  Playground to Markdown README convertor
//
//  Created by Matěj Jirásek on 01/05/16.
//  Copyright © 2016 Matěj Kašpar Jirásek. All rights reserved.
//

import Foundation

// MARK: - Chapter structure

struct Chapter {

    var title: String
    var head: String
    var body: String

    init(title: String = "", head: String = "", body: String = "") {
        self.title = title
        self.head = head
        self.body = body
    }

}

// MARK: - Delagate for parser of the playground folder

class ContentsParserDelegate: NSObject, NSXMLParserDelegate {

    var pages = [String]()

    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {

        if elementName == "page", let page = attributeDict["name"] {
            pages.append(page)
        }
    }

}

// MARK: - Parser for the Swift file of one chapter

class ChapterParser {

    let headDivider = "//: -----"

    var isParsingHead = false
    var isParsingDocumentation = true
    var isParsingFirstLine = true

    var head = ""
    var body = ""

    init(file: NSURL) {
        parse(file)
    }

    func parse(file: NSURL) {

        let content = try! String(contentsOfURL: file)

        if content.containsString(headDivider) {
            isParsingHead = true
        }

        let rows = content.componentsSeparatedByString("\n")
        rows.forEach { (row) in

            // Simply omit row containing special links from playground
            if row.containsString("@next") || row.containsString("@previous") {
                return
            }

            // If we encountered head divider reset state and continue parsing body
            if row == headDivider {
                isParsingHead = false
                isParsingDocumentation = true
                isParsingFirstLine = true
                return
            }

            if row.hasPrefix("//:") {
                // Parsing documentation
                if !isParsingDocumentation && !isParsingFirstLine {
                    writeLine("")
                    writeLine("```")
                    writeLine("")
                }

                let length = row.hasPrefix("//: ") ? 4 : 3
                let markdown = row.substringFromIndex(row.startIndex.advancedBy(length))

                writeLine(markdown)

                isParsingDocumentation = true
            } else {
                // Parsing code
                if isParsingDocumentation {
                    writeLine("")
                    writeLine("```swift")
                    writeLine("")
                }
                writeLine(row)

                isParsingDocumentation = false
            }

            if isParsingFirstLine && row != "" {
                isParsingFirstLine = false
            }

        }

        if isParsingDocumentation == false {
            writeLine("")
            writeLine("```")
        }
        writeLine("")
    }

    func writeLine(string: String) {
        write(string + "\n")
    }

    func write(string: String) {
        if isParsingHead {
            head.appendContentsOf(string)
        } else {
            body.appendContentsOf(string)
        }
    }
}

// MARK: - Main function

func main() {

    var arguments = Process.arguments
    arguments.removeAtIndex(0)

    // Help
    if arguments.contains("-h") || arguments.contains("--help") {
        help()
    }

    // Table of contents settings
    var tableOfContents = true
    if let index = arguments.indexOf("-t") {
        arguments.removeAtIndex(index)
        tableOfContents = false
    }
    if let index = arguments.indexOf("--no-toc") {
        arguments.removeAtIndex(index)
        tableOfContents = false
    }

    // Load output file
    var output: NSURL? = nil
    if let index = arguments.indexOf("-o") {

        if arguments.count > index + 1 {
            output = NSURL(fileURLWithPath: arguments[index + 1])
        }

        arguments.removeAtIndex(index)
        arguments.removeAtIndex(index)
    }

    // Load playground
    if arguments.count == 0 {
        print("No playground file in arguments.")
        exit(3)
    }

    let dir = NSURL(fileURLWithPath: NSFileManager.defaultManager().currentDirectoryPath)
    let url = dir.URLByAppendingPathComponent(arguments[0])
    let contents = url.URLByAppendingPathComponent("contents.xcplayground")

    if let parser = NSXMLParser(contentsOfURL: contents) {
        
        // Assign parser delegate
        let delegate = ContentsParserDelegate()
        parser.delegate = delegate
        
        // Handle parser errors
        if !parser.parse() {
            print(parser.parserError)
            exit(2)
        }

        var chapters = [Chapter]()

        if chapters.count > 0 {
            // Convert every found chapter to markdown if the playground uses chapters
            let pagesFolder = url.URLByAppendingPathComponent("Pages")

            var chapters = [Chapter]()

            delegate.pages.forEach({ (page) in

                let pageContents = pagesFolder.URLByAppendingPathComponent(page + ".xcplaygroundpage").URLByAppendingPathComponent("Contents.swift")
                let parser = ChapterParser(file: pageContents)

                let chapter = Chapter(title: page, head: parser.head, body: parser.body)
                chapters.append(chapter)
                
            })
        } else {
            // Parse just one file
            tableOfContents = false

            let swiftContents = url.URLByAppendingPathComponent("Contents.swift")
            let parser = ChapterParser(file: swiftContents)

            let chapter = Chapter(title: "", head: parser.head, body: parser.body)
            chapters.append(chapter)
        }
        
        // Add head if there was one for the first file
        var markdown = ""
        if let head = chapters.first?.head {
            markdown.appendContentsOf(head)
        }
        
        // Add table of contents if selected
        if tableOfContents {
            markdown.appendContentsOf("\n\n## Table of contents\n\n")
            chapters.forEach({ (chapter) in
                markdown.appendContentsOf("* [" + chapter.title + "](#" + chapter.title.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "-") + ")\n")
            })
            markdown.appendContentsOf("\n")
        }
        
        // Add the chapter texts
        chapters.forEach({ (chapter) in
            if chapter.title != "" {
                markdown.appendContentsOf("\n\n## " + chapter.title + "\n\n")
            }
            markdown.appendContentsOf(chapter.body)
        })
        
        // And print the result
        if let output = output {
            try! markdown.writeToURL(output, atomically: true, encoding: NSUTF8StringEncoding)
        } else {
            print(markdown)
        }
        
    } else {
        print("Contents of the playground could not be loaded.")
        exit(1)
    }

}

// MARK: - Help function

func help() {

    print("usage: ./markground.swift [--help | -h] [--no-toc | -t]")
    print("                          [-o <path>] <playground>")

    exit(0)
}

// Run the main function in the end
main()
