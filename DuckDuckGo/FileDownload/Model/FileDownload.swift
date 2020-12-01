//
//  FileDownload.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

struct FileDownload {

    var request: URLRequest
    var suggestedName: String?

    /// Based on Content-Length header, if avialable.
    var contentLength: Int? {
        guard let contentLength = request.allHTTPHeaderFields?["Content-Length"] else { return nil }
        return Int(contentLength)
    }

    func bestFileName(mimeType: String?) -> String {
        return suggestedName ??
            fileNameFromURL(mimeType: mimeType) ??
            createUniqueFileName(mimeType: mimeType)
    }

    func createUniqueFileName(mimeType: String?) -> String {

        let suffix: String
        if let ext = Self.mimeTypes.first(where: { $0.keys.first == mimeType })?.first?.value {
            suffix = "." + ext
        } else {
            suffix = ""
        }

        let prefix: String
        if let host = request.url?.host?.drop(prefix: "www.").replacingOccurrences(of: ".", with: "_") {
            prefix = host + "_"
        } else {
            prefix = ""
        }

        return prefix + UUID().uuidString + suffix
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    func fileNameFromURL(mimeType: String?) -> String? {
        guard let url = request.url, !url.pathExtension.isEmpty else { return nil }

        if let mimeType = mimeType,
           hasMatchingMimeType(mimeType, extension: url.pathExtension) {
            // Mime-type and extensio match so go with it
            return url.lastPathComponent
        }

        if let ext = Self.mimeTypes.first(where: { $0.keys.first == mimeType })?.values.first {
            // there is a more appropriate extension, so use it
            return url.lastPathComponent + "." + ext
        }

        return url.lastPathComponent
    }

    func hasMatchingMimeType(_ mimeType: String, extension ext: String) -> Bool {
        return Self.mimeTypes.contains([mimeType: ext])
    }

}

extension FileDownload {

    static let mimeTypes = [
        ["application/envoy": "evy"],
        ["application/fractals": "fif"],
        ["application/futuresplash": "spl"],
        ["application/hta": "hta"],
        ["application/internet-property-stream": "acx"],
        ["application/mac-binhex40": "hqx"],
        ["application/msword": "doc"],
        ["application/msword": "dot"],
        ["application/oda": "oda"],
        ["application/olescript": "axs"],
        ["application/pdf": "pdf"],
        ["application/pics-rules": "prf"],
        ["application/pkcs10": "p10"],
        ["application/pkix-crl": "crl"],
        ["application/postscript": "ai"],
        ["application/postscript": "eps"],
        ["application/postscript": "ps"],
        ["application/rtf": "rtf"],
        ["application/set-payment-initiation": "setpay"],
        ["application/set-registration-initiation": "setreg"],
        ["application/vnd.ms-excel": "xla"],
        ["application/vnd.ms-excel": "xlc"],
        ["application/vnd.ms-excel": "xlm"],
        ["application/vnd.ms-excel": "xls"],
        ["application/vnd.ms-excel": "xlt"],
        ["application/vnd.ms-excel": "xlw"],
        ["application/vnd.ms-outlook": "msg"],
        ["application/vnd.ms-pkicertstore": "sst"],
        ["application/vnd.ms-pkiseccat": "cat"],
        ["application/vnd.ms-pkistl": "stl"],
        ["application/vnd.ms-powerpoint": "pot"],
        ["application/vnd.ms-powerpoint": "pps"],
        ["application/vnd.ms-powerpoint": "ppt"],
        ["application/vnd.ms-project": "mpp"],
        ["application/vnd.ms-works": "wcm"],
        ["application/vnd.ms-works": "wdb"],
        ["application/vnd.ms-works": "wks"],
        ["application/vnd.ms-works": "wps"],
        ["application/winhlp": "hlp"],
        ["application/x-bcpio": "bcpio"],
        ["application/x-cdf": "cdf"],
        ["application/x-compress": "z"],
        ["application/x-compressed": "tgz"],
        ["application/x-cpio": "cpio"],
        ["application/x-csh": "csh"],
        ["application/x-director": "dcr"],
        ["application/x-director": "dir"],
        ["application/x-director": "dxr"],
        ["application/x-dvi": "dvi"],
        ["application/x-gtar": "gtar"],
        ["application/x-gzip": "gz"],
        ["application/x-hdf": "hdf"],
        ["application/x-internet-signup": "ins"],
        ["application/x-internet-signup": "isp"],
        ["application/x-iphone": "iii"],
        ["application/x-javascript": "js"],
        ["application/x-latex": "latex"],
        ["application/x-msaccess": "mdb"],
        ["application/x-mscardfile": "crd"],
        ["application/x-msclip": "clp"],
        ["application/x-msdownload": "dll"],
        ["application/x-msmediaview": "m13"],
        ["application/x-msmediaview": "m14"],
        ["application/x-msmediaview": "mvb"],
        ["application/x-msmetafile": "wmf"],
        ["application/x-msmoney": "mny"],
        ["application/x-mspublisher": "pub"],
        ["application/x-msschedule": "scd"],
        ["application/x-msterminal": "trm"],
        ["application/x-mswrite": "wri"],
        ["application/x-netcdf": "cdf"],
        ["application/x-netcdf": "nc"],
        ["application/x-perfmon": "pma"],
        ["application/x-perfmon": "pmc"],
        ["application/x-perfmon": "pml"],
        ["application/x-perfmon": "pmr"],
        ["application/x-perfmon": "pmw"],
        ["application/x-pkcs12": "p12"],
        ["application/x-pkcs12": "pfx"],
        ["application/x-pkcs7-certificates": "p7b"],
        ["application/x-pkcs7-certificates": "spc"],
        ["application/x-pkcs7-certreqresp": "p7r"],
        ["application/x-pkcs7-mime": "p7c"],
        ["application/x-pkcs7-mime": "p7m"],
        ["application/x-pkcs7-signature": "p7s"],
        ["application/x-sh": "sh"],
        ["application/x-shar": "shar"],
        ["application/x-shockwave-flash": "swf"],
        ["application/x-stuffit": "sit"],
        ["application/x-sv4cpio": "sv4cpio"],
        ["application/x-sv4crc": "sv4crc"],
        ["application/x-tar": "tar"],
        ["application/x-tcl": "tcl"],
        ["application/x-tex": "tex"],
        ["application/x-texinfo": "texi"],
        ["application/x-texinfo": "texinfo"],
        ["application/x-troff": "roff"],
        ["application/x-troff": "t"],
        ["application/x-troff": "tr"],
        ["application/x-troff-man": "man"],
        ["application/x-troff-me": "me"],
        ["application/x-troff-ms": "ms"],
        ["application/x-ustar": "ustar"],
        ["application/x-wais-source": "src"],
        ["application/x-x509-ca-cert": "cer"],
        ["application/x-x509-ca-cert": "crt"],
        ["application/x-x509-ca-cert": "der"],
        ["application/ynd.ms-pkipko": "pko"],
        ["application/zip": "zip"],
        ["audio/basic": "au"],
        ["audio/basic": "snd"],
        ["audio/mid": "mid"],
        ["audio/mid": "rmi"],
        ["audio/mpeg": "mp3"],
        ["audio/x-aiff": "aif"],
        ["audio/x-aiff": "aifc"],
        ["audio/x-aiff": "aiff"],
        ["audio/x-mpegurl": "m3u"],
        ["audio/x-pn-realaudio": "ra"],
        ["audio/x-pn-realaudio": "ram"],
        ["audio/x-wav": "wav"],
        ["image/bmp": "bmp"],
        ["image/cis-cod": "cod"],
        ["image/gif": "gif"],
        ["image/ief": "ief"],
        ["image/jpeg": "jpe"],
        ["image/jpeg": "jpeg"],
        ["image/jpeg": "jpg"],
        ["image/pipeg": "jfif"],
        ["image/svg+xml": "svg"],
        ["image/tiff": "tif"],
        ["image/tiff": "tiff"],
        ["image/x-cmu-raster": "ras"],
        ["image/x-cmx": "cmx"],
        ["image/x-icon": "ico"],
        ["image/x-portable-anymap": "pnm"],
        ["image/x-portable-bitmap": "pbm"],
        ["image/x-portable-graymap": "pgm"],
        ["image/x-portable-pixmap": "ppm"],
        ["image/x-rgb": "rgb"],
        ["image/x-xbitmap": "xbm"],
        ["image/x-xpixmap": "xpm"],
        ["image/x-xwindowdump": "xwd"],
        ["message/rfc822": "mht"],
        ["message/rfc822": "mhtml"],
        ["message/rfc822": "nws"],
        ["text/css": "css"],
        ["text/h323": "323"],
        ["text/html": "htm"],
        ["text/html": "html"],
        ["text/html": "stm"],
        ["text/iuls": "uls"],
        ["text/plain": "bas"],
        ["text/plain": "c"],
        ["text/plain": "h"],
        ["text/plain": "txt"],
        ["text/richtext": "rtx"],
        ["text/scriptlet": "sct"],
        ["text/tab-separated-values": "tsv"],
        ["text/webviewhtml": "htt"],
        ["text/x-component": "htc"],
        ["text/x-setext": "etx"],
        ["text/x-vcard": "vcf"],
        ["video/mpeg": "mp2"],
        ["video/mpeg": "mpa"],
        ["video/mpeg": "mpe"],
        ["video/mpeg": "mpeg"],
        ["video/mpeg": "mpg"],
        ["video/mpeg": "mpv2"],
        ["video/mp4": "mp4"],
        ["video/quicktime": "mov"],
        ["video/quicktime": "qt"],
        ["video/x-la-asf": "lsf"],
        ["video/x-la-asf": "lsx"],
        ["video/x-ms-asf": "asf"],
        ["video/x-ms-asf": "asr"],
        ["video/x-ms-asf": "asx"],
        ["video/x-msvideo": "avi"],
        ["video/x-sgi-movie": "movie"],
        ["world/x-vrml": "flr"],
        ["world/x-vrml": "vrml"],
        ["world/x-vrml": "wrl"],
        ["world/x-vrml": "wrz"],
        ["world/x-vrml": "xaf"],
        ["world/x-vrml": "xof"]
    ]

}
