//
//  StringExtensionTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class StringExtensionTests: XCTestCase {

    func testHtmlEscapedString() {
        NSError.disableSwizzledDescription = true
        defer { NSError.disableSwizzledDescription = false }

        XCTAssertEqual("\"DuckDuckGo\"®".escapedUnicodeHtmlString(), "&quot;DuckDuckGo&quot;®")
        XCTAssertEqual("i don‘t want to 'sleep'™".escapedUnicodeHtmlString(), "i don‘t want to &apos;sleep&apos;™")
        XCTAssertEqual("{ $embraced [&text]}".escapedUnicodeHtmlString(), "&#123; &#36;embraced &#91;&amp;text&#93;&#125;")
        XCTAssertEqual("X ^ 2 + y / 2 = 4 < 6%".escapedUnicodeHtmlString(), "X &#94; 2 + y &#x2F; 2 &#61; 4 &lt; 6&percnt;")
        XCTAssertEqual("<some&tag>".escapedUnicodeHtmlString(), "&lt;some&amp;tag&gt;")
        XCTAssertEqual("© “text” with «emojis» 🩷🦆".escapedUnicodeHtmlString(), "© “text” with «emojis» 🩷🦆")
        XCTAssertEqual("`my.mail@duck.com`".escapedUnicodeHtmlString(), "&#97;my.mail&#64;duck.com&#97;")
        XCTAssertEqual("<hey beep=\\\"#test\\\" boop='#' fool=1 >floop!<b>burp</b></hey>".escapedUnicodeHtmlString(),
                       "&lt;hey beep&#61;&#92;&quot;&#35;test&#92;&quot; boop&#61;&apos;&#35;&apos; fool&#61;1 &gt;floop&excl;&lt;b&gt;burp&lt;&#x2F;b&gt;&lt;&#x2F;hey&gt;")

        XCTAssertEqual(URLError(URLError.Code.cannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: "Could not connect to the server."]).localizedDescription.escapedUnicodeHtmlString(), "Could not connect to the server.")
    }

    // MARK: - File paths detection

    func testFindRangesOfFilePaths1() {
        let input = """
        (
            0   CoreFoundation                      0x0000000183d66ccc __exceptionPreprocess + 176
            1   libobjc.A.dylib                     0x000000018384e788 objc_exception_throw + 60
            2   AppKit                              0x0000000187f35728 +[NSStoryboard storyboardWithName:bundle:] + 0
            3   AppKit                              0x0000000187f35770 +[NSStoryboard storyboardWithName:bundle:] + 72
            4   DuckDuckGo                          0x0000000102db88c0 $sSo12NSStoryboardC4name6bundleABSS_So8NSBundleCSgtcfCTO + 64
            5   DuckDuckGo                          0x0000000102f3e1c8 $s04DuckA18Go_Privacy_Browser20TabBarViewControllerC6create013tabCollectionG5ModelAcA0ekgL0C_tFZ + 156
            6   DuckDuckGo                          0x0000000103240324 $s04DuckA18Go_Privacy_Browser18MainViewControllerC013tabCollectionF5Model15bookmarkManager24autofillPopoverPresenterAcA03TabifJ0CSg_AA08BookmarkL0_pAA08AutofillnO0_ptcfc + 1164
            7   DuckDuckGo                          0x000000010323fe88 $s04DuckA18Go_Privacy_Browser18MainViewControllerC013tabCollectionF5Model15bookmarkManager24autofillPopoverPresenterAcA03TabifJ0CSg_AA08BookmarkL0_pAA08AutofillnO0_ptcfC + 64
            8   DuckDuckGo                          0x0000000102eecdf0 $s04DuckA18Go_Privacy_Browser14WindowsManagerC13makeNewWindow33_DF58FCBC4B179E56B939B7A5BC5A48B8LL22tabCollectionViewModel11contentSize5popUp10burnerMode24autofillPopoverPresenterAA04MainI10ControllerCAA03TabuvW0CSg_So6CGSizeVSgSbAA10BurnerModeOAA24AutofillPopoverPresenter_ptFZ + 372
            9   DuckDuckGo                          0x0000000102eec484 $s04DuckA18Go_Privacy_Browser14WindowsManagerC13openNewWindow4with10burnerMode13droppingPoint11contentSize04showI05popUp12lazyLoadTabs14isMiniaturizedAA04MainI0CSgAA22TabCollectionViewModelCSg_AA06BurnerL0OSo7CGPointVSgSo6CGSizeVSgS4btFZ + 400
            10  DuckDuckGo                          0x000000010350edf4 $s04DuckA18Go_Privacy_Browser11AppDelegateC9newWindowyyypSgF + 184
            11  DuckDuckGo                          0x000000010350eeb4 $s04DuckA18Go_Privacy_Browser11AppDelegateC9newWindowyyypSgFTo + 152
            12  AppKit                              0x00000001876edc70 -[NSApplication(NSResponder) sendAction:to:from:] + 460
            13  AppKit                              0x00000001877b74a4 -[NSMenuItem _corePerformAction] + 372
            14  AppKit                              0x0000000187d64af4 _NSMenuPerformActionWithHighlighting + 152
            15  AppKit                              0x0000000187be0318 -[NSMenu _performActionForItem:atIndex:fromEvent:] + 212
            16  AppKit                              0x00000001877b66bc -[NSMenu performKeyEquivalent:] + 376
            17  AppKit                              0x0000000187d3b9a4 routeKeyEquivalent + 444
            18  AppKit                              0x0000000187d39ae8 -[NSApplication(NSEventRouting) sendEvent:] + 700
            19  AppKit                              0x00000001879878cc -[NSApplication _handleEvent:] + 60
            20  AppKit                              0x000000018753bcdc -[NSApplication run] + 512
            21  DuckDuckGo                          0x00000001030a5e1c $s04DuckA18Go_Privacy_Browser7AppMainV4mainyyFZ + 116
            22  DuckDuckGo                          0x00000001030a5e3c $s04DuckA18Go_Privacy_Browser7AppMainV5$mainyyFZ + 12
            23  DuckDuckGo                          0x00000001030a5e54 main + 12
            24  dyld                                0x000000018388a0e0 start + 2360
        )
        UserScript/UserScript.swift:69: Fatal error: Failed to load JavaScript contentScope from \(Bundle.main.bundlePath)/Contents/Resources/ContentScopeScripts_ContentScopeScripts.bundle/Contents/Resources/contentScope.js
        """
        let output = input.rangesOfFilePaths()

        let line = #line
        let expectations = [
            "libobjc.A.dylib",
            "UserScript/UserScript.swift",
            "\(Bundle.main.bundlePath)/Contents/Resources/ContentScopeScripts_ContentScopeScripts.bundle/Contents/Resources/contentScope.js",
        ]
        for idx in 0..<max(expectations.count, output.count) {
            let result = output[safe: idx].map { String(input[$0]) } ?? "<nil>"
            let expectation = expectations[safe: idx]
            XCTAssertEqual(result, expectation ?? "<nil>", "idx=\(idx)", line: expectation == nil ? #line : UInt(line + idx + 2))
        }

        XCTAssertEqual(input.sanitized(), """
        (
            0   CoreFoundation                      0x0000000183d66ccc __exceptionPreprocess + 176
            1   libobjc.A.dylib                     0x000000018384e788 objc_exception_throw + 60
            2   AppKit                              0x0000000187f35728 +[NSStoryboard storyboardWithName:bundle:] + 0
            3   AppKit                              0x0000000187f35770 +[NSStoryboard storyboardWithName:bundle:] + 72
            4   DuckDuckGo                          0x0000000102db88c0 $sSo12NSStoryboardC4name6bundleABSS_So8NSBundleCSgtcfCTO + 64
            5   DuckDuckGo                          0x0000000102f3e1c8 $s04DuckA18Go_Privacy_Browser20TabBarViewControllerC6create013tabCollectionG5ModelAcA0ekgL0C_tFZ + 156
            6   DuckDuckGo                          0x0000000103240324 $s04DuckA18Go_Privacy_Browser18MainViewControllerC013tabCollectionF5Model15bookmarkManager24autofillPopoverPresenterAcA03TabifJ0CSg_AA08BookmarkL0_pAA08AutofillnO0_ptcfc + 1164
            7   DuckDuckGo                          0x000000010323fe88 $s04DuckA18Go_Privacy_Browser18MainViewControllerC013tabCollectionF5Model15bookmarkManager24autofillPopoverPresenterAcA03TabifJ0CSg_AA08BookmarkL0_pAA08AutofillnO0_ptcfC + 64
            8   DuckDuckGo                          0x0000000102eecdf0 $s04DuckA18Go_Privacy_Browser14WindowsManagerC13makeNewWindow33_DF58FCBC4B179E56B939B7A5BC5A48B8LL22tabCollectionViewModel11contentSize5popUp10burnerMode24autofillPopoverPresenterAA04MainI10ControllerCAA03TabuvW0CSg_So6CGSizeVSgSbAA10BurnerModeOAA24AutofillPopoverPresenter_ptFZ + 372
            9   DuckDuckGo                          0x0000000102eec484 $s04DuckA18Go_Privacy_Browser14WindowsManagerC13openNewWindow4with10burnerMode13droppingPoint11contentSize04showI05popUp12lazyLoadTabs14isMiniaturizedAA04MainI0CSgAA22TabCollectionViewModelCSg_AA06BurnerL0OSo7CGPointVSgSo6CGSizeVSgS4btFZ + 400
            10  DuckDuckGo                          0x000000010350edf4 $s04DuckA18Go_Privacy_Browser11AppDelegateC9newWindowyyypSgF + 184
            11  DuckDuckGo                          0x000000010350eeb4 $s04DuckA18Go_Privacy_Browser11AppDelegateC9newWindowyyypSgFTo + 152
            12  AppKit                              0x00000001876edc70 -[NSApplication(NSResponder) sendAction:to:from:] + 460
            13  AppKit                              0x00000001877b74a4 -[NSMenuItem _corePerformAction] + 372
            14  AppKit                              0x0000000187d64af4 _NSMenuPerformActionWithHighlighting + 152
            15  AppKit                              0x0000000187be0318 -[NSMenu _performActionForItem:atIndex:fromEvent:] + 212
            16  AppKit                              0x00000001877b66bc -[NSMenu performKeyEquivalent:] + 376
            17  AppKit                              0x0000000187d3b9a4 routeKeyEquivalent + 444
            18  AppKit                              0x0000000187d39ae8 -[NSApplication(NSEventRouting) sendEvent:] + 700
            19  AppKit                              0x00000001879878cc -[NSApplication _handleEvent:] + 60
            20  AppKit                              0x000000018753bcdc -[NSApplication run] + 512
            21  DuckDuckGo                          0x00000001030a5e1c $s04DuckA18Go_Privacy_Browser7AppMainV4mainyyFZ + 116
            22  DuckDuckGo                          0x00000001030a5e3c $s04DuckA18Go_Privacy_Browser7AppMainV5$mainyyFZ + 12
            23  DuckDuckGo                          0x00000001030a5e54 main + 12
            24  dyld                                0x000000018388a0e0 start + 2360
        )
        UserScript.swift:69: Fatal error: Failed to load JavaScript contentScope from DuckDuckGo.app/Contents/Resources/ContentScopeScripts_ContentScopeScripts.bundle/Contents/Resources/contentScope.js
        """)
    }

    func testFindRangesOfFilePaths2() {
        let input = """
        DuckDuckGo_Privacy_Browser/MainMenuActions.swift:686: Fatal error: 'try!' expression unexpectedly raised an error: Error Domain=NSCocoaErrorDomain Code=260 "The file “pa”th.txt” couldn’t be opened because there is no such file." UserInfo={NSFilePath=/non/exиstent file/pa”th.txt, NSUnderlyingError=0x600001a62580 {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
        Error Domain=NSCocoaErrorDomain Code=260 "The file “pa”th.txt” couldn’t be opened because there is no such file." UserInfo={NSFilePath=/non/exis“tent folder/pa”th.txt, NSUnderlyingError=0x60000057da10 {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
        """
        let output = input.rangesOfFilePaths()

        let line = #line
        let expectations = [
            "DuckDuckGo_Privacy_Browser/MainMenuActions.swift",
            "pa”th.txt",
            "/non/exиstent file/pa”th.txt",
            "pa”th.txt",
            "/non/exis“tent folder/pa”th.txt",
        ]
        for idx in 0..<max(expectations.count, output.count) {
            let result = output[safe: idx].map { String(input[$0]) } ?? "<nil>"
            let expectation = expectations[safe: idx]
            XCTAssertEqual(result, expectation ?? "<nil>", "\(idx)", line: expectation == nil ? #line : UInt(line + idx + 2))
        }

        XCTAssertEqual(input.sanitized(), """
        DuckDuckGo_Privacy_Browser/MainMenuActions.swift:686: Fatal error: 'try!' expression unexpectedly raised an error: Error Domain=NSCocoaErrorDomain Code=260 "The file “<removed>” couldn’t be opened because there is no such file." UserInfo={NSFilePath=<removed>, NSUnderlyingError=0x600001a62580 {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
        Error Domain=NSCocoaErrorDomain Code=260 "The file “<removed>” couldn’t be opened because there is no such file." UserInfo={NSFilePath=<removed>, NSUnderlyingError=0x60000057da10 {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
        """)
    }

    func testFindRangesOfFilePaths3() {
        let input = """
        assertion failed: 23E224: libxpc.dylib + 202836 [C43D5322-9B69-37EE-B51E-45FDE5D81B5B]: 0x10000017
        assertion failed: 23E224: libxpc.dylib + 202836 [C43D5322-9B69-37EE-B51E-45FDE5D81B5B]: 0x10000017
        bundle \(Bundle.main.bundleURL.absoluteString)
        """
        let output = input.rangesOfFilePaths()

        let line = #line
        let expectations = [
            "libxpc.dylib",
            "libxpc.dylib",
            Bundle.main.bundleURL.absoluteString,
        ]
        for idx in 0..<max(expectations.count, output.count) {
            let result = output[safe: idx].map { String(input[$0]) } ?? "<nil>"
            let expectation = expectations[safe: idx]
            XCTAssertEqual(result, expectation ?? "<nil>", "\(idx)", line: expectation == nil ? #line : UInt(line + idx + 2))
        }

        XCTAssertEqual(input.sanitized(), """
        assertion failed: 23E224: libxpc.dylib + 202836 [C43D5322-9B69-37EE-B51E-45FDE5D81B5B]: 0x10000017
        assertion failed: 23E224: libxpc.dylib + 202836 [C43D5322-9B69-37EE-B51E-45FDE5D81B5B]: 0x10000017
        bundle file:///DuckDuckGo.app/
        """)
    }

    func testFindRangesOfFilePaths4() {
        let input = """
        In file included from /Volumes/some мрé/directoy/3.33A.37.2/something else/dogs.txt,
         from /some/directoy/something else/dogs.txt, from ~/some/directoyr/3.33A.37.2/something else/dogs.txt, from /var/log/xyz/10032008. 10g,
        from /var/log/xyz/test.c: 29:
        Solution: please the file something.h has to be alone without others include, it has to be present in release letter,
        in order to be included in /var/log/xyz/test. automatically parse /the/file/name
        Other Note: send me an email at admin@duckduckgo.com!
        The file something. must contain the somethinge.h and not the ecpfmbsd.h because it doesn't contain C operative c in /var/filename.c.
        """
        let output = input.rangesOfFilePaths()

        let line = #line
        let expectations = [
            "/Volumes/some мрé/directoy/3.33A.37.2/something else/dogs.txt",
            "/some/directoy/something else/dogs.txt",
            "~/some/directoyr/3.33A.37.2/something else/dogs.txt",
            "/var/log/xyz/10032008",
            "/var/log/xyz/test.c",
            "something.h",
            "/var/log/xyz/test",
            "/the/file/name",
            "somethinge.h",
            "ecpfmbsd.h",
            "/var/filename.c",
        ]
        for idx in 0..<max(expectations.count, output.count) {
            let result = output[safe: idx].map { String(input[$0]) } ?? "<nil>"
            let expectation = expectations[safe: idx]
            XCTAssertEqual(result, expectation ?? "<nil>", "\(idx)", line: expectation == nil ? #line : UInt(line + idx + 2))
        }

        XCTAssertEqual(input.sanitized(), """
        In file included from <removed>,
         from <removed>, from <removed>, from <removed>. 10g,
        from test.c: 29:
        Solution: please the file <removed> has to be alone without others include, it has to be present in release letter,
        in order to be included in <removed>. automatically parse <removed>
        Other Note: send me an email at <removed>!
        The file something. must contain the <removed> and not the <removed> because it doesn't contain C operative c in filename.c.
        """)
    }

    func testFindRangesOfFilePaths_emptyString() {
        let input = ""
        let output = input.rangesOfFilePaths()
        XCTAssertEqual(output, [])
        XCTAssertEqual(input.sanitized(), "")
    }

    func testFindRangesOfFilePaths_pathsMissing1() {
        let input = """
        Error Domain=OSLogErrorDomain Code=-1 "issue with predicate: no such field: level" UserInfo={NSLocalizedDescription=issue with predicate: no such field: level}
        """
        let output = input.rangesOfFilePaths()
        XCTAssertEqual(output.map { input[$0] }, [])
        XCTAssertEqual(input.sanitized(), input)
    }

    func testFindRangesOfFilePaths_pathsMissing2() {
        let input = """
        The application has crashed
        """
        let output = input.rangesOfFilePaths()
        XCTAssertEqual(output.map { input[$0] }, [])
        XCTAssertEqual(input.sanitized(), input)
    }

}
