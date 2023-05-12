# liblzma is in the public domain

when defined(windows):
    const liblzma = "liblzma.dll"
elif defined(macosx):
    const liblzma = "liblzma.dylib"
else:
    const liblzma = "liblzma.so"

import os

type
    Pint* = ptr int64
    Psizet* = ptr csize_t
    XZStream* {.final, pure.} = object
        nextIn*: cstring
        availIn*: int
        totalIn*: int
        nextOut*: cstring
        availOut*: int
        totalOut*: int
        allocator*: pointer
        internal*: pointer
        reservedPtr1*: pointer
        reservedPtr2*: pointer
        reservedPtr3*: pointer
        reservedPtr4*: pointer
        seekPos*: int
        reservedInt2*: int
        reservedInt3*: int
        reservedInt4*: int
        reservedEnum1*: int32
        reservedEnum2*: int32
    XZlibStreamError* = object of ValueError

const
    LZMA_PRESET_DEFAULT* = 6.int32  ## Default compression level
    LZMA_STREAM_INIT = XZStream(
        nextIn: nil,
        availIn: 0,
        totalIn: 0,
        nextOut: nil,
        availOut: 0,
        totalOut: 0,
        allocator: nil,
        internal: nil,
        reservedPtr1: nil,
        reservedPtr2: nil,
        reservedPtr3: nil,
        reservedPtr4: nil,
        seekPos: 0,
        reservedInt2: 0,
        reservedInt3: 0,
        reservedInt4: 0,
        reservedEnum1: 0,
        reservedEnum2: 0)           ## Initialize stream
    BUFSIZ = 8 * 1024
    # returns
    LZMA_OK* = 0                    ## Operation completed successfully
    LZMA_STREAM_END* = 1            ## End of stream was reached
    LZMA_NO_CHECK* = 2              ## Input stream has no integrity check
    LZMA_UNSUPPORTED_CHECK* = 3     ## Cannot calculate the integrity check
    LZMA_GET_CHECK* = 4             ## Integrity check type is now available
    LZMA_MEM_ERROR* = 5             ## Cannot allocate memory
    LZMA_MEMLIMIT_ERROR* = 6        ## Memory usage limit was reached
    LZMA_FORMAT_ERROR* = 7          ## File format not recognized
    LZMA_OPTIONS_ERROR* = 8         ## Invalid or unsupported options
    LZMA_DATA_ERROR* = 9            ## Data is corrupt
    LZMA_BUF_ERROR* = 10            ## No progress is possible 
    LZMA_PROG_ERROR* = 11           ## Programming error (arguments given to the function are invalid or the internal state of the decoder is corrupt)
    LZMA_SEEK_NEEDED* = 12          ## Request to change the input file position
    # checks
    LZMA_CHECK_NONE* = 0.int32      ## No Check is calculated
    LZMA_CHECK_CRC32* = 1.int32     ## CRC32 using the polynomial from the IEEE 802.3 standard
    LZMA_CHECK_CRC64* = 4.int32     ## CRC64 using the polynomial from the ECMA-182 standard
    LZMA_CHECK_SHA256* = 10.int32   ## SHA256
    # actions
    LZMA_RUN* = 0.int32             ## Continue coding
    LZMA_SYNC_FLUSH* = 1.int32      ## Make all the input available at output
    LZMA_FULL_FLUSH* = 2.int32      ## Finish encoding of the current Block
    LZMA_FINISH* = 3.int32          ## Finish the coding operation
    LZMA_FULL_BARRIER* = 4.int32    ## Finish encoding of the current Block
    # decoder flags
    LZMA_TELL_NO_CHECK = 0x01
    LZMA_TELL_UNSUPPORTED_CHECK = 0x02
    LZMA_TELL_ANY_CHECK = 0x04
    LZMA_CONCATENATED = 0x08
    LZMA_IGNORE_CHECK = 0x10

proc lzma_easy_encoder*(
    strm: var XZStream,
    preset, check: int32): int {.cdecl, dynlib: liblzma, importc: "lzma_easy_encoder".}
    ## preset is compression preset to use [0, 9],
    ## 0 (no compression), 9 (slow compression, small output),
    ## typically use LZMA_PRESET_DEFAULT
    ## check is integrity check type to use, typically LZMA_CHECK_CRC64.

proc lzma_stream_decoder*(
    strm: var XZStream,
    memlimit: int,
    flags: int32): int {.cdecl, dynlib: liblzma, importc: "lzma_stream_decoder".}
    ## memlimit uses high(int) to effectively disable the limiter

proc lzma_code*(
    strm: var XZStream,
    action: int32): int {.cdecl, dynlib: liblzma, importc: "lzma_code".}

proc lzma_end*(
    strm: var XZStream) {.cdecl, dynlib: liblzma, importc: "lzma_end".}

proc lzma_easy_buffer_encode*(
    preset, check: int32,
    allocator: pointer,
    inString: cstring,
    inSize: int,
    outString: cstring,
    outPos: Psizet,
    outSize: csize_t): int {.cdecl, dynlib: liblzma, importc: "lzma_easy_buffer_encode".}
    ## allocator set to nil to use malloc() and free()

proc lzma_stream_buffer_bound*(
    uncompressed_size: csize_t
): csize_t {.cdecl, dynlib: liblzma, importc: "lzma_stream_buffer_bound".}

proc lzma_stream_buffer_decode*(
    memlimit: Pint,
    flags: int32,
    allocator: pointer,
    inString: cstring,
    inPos: pointer,
    inSize: int,
    outString: cstring,
    outPos: pointer,
    outSize: int): int {.cdecl, dynlib: liblzma, importc: "lzma_stream_buffer_decode".}
    ## decoder flags not used

proc xz*(source: string, preset=LZMA_PRESET_DEFAULT, check=LZMA_CHECK_CRC64, rm=true): string =
    ## compresses source to source.xz and optionally deletes it
    ## returns compressed filename
    if not source.fileExists:
        raise newException(OSError, "Uncompressed source file missing")
    if fileExists(source & ".xz"):
        raise newException(OSError, "Compressed target file already exists")
    var
        fin = open(source)
        fout = open(source & ".xz", fmWrite)
        inbuf: array[BUFSIZ, char]
        outbuf: array[BUFSIZ, char]
        strm = LZMA_STREAM_INIT
        stat = lzma_easy_encoder(strm, preset, check)
        ret: int
        action = LZMA_RUN
    case stat:
        of LZMA_OK: discard
        of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
        of LZMA_OPTIONS_ERROR: raise newException(XZlibStreamError, "Specified preset is not supported")
        of LZMA_UNSUPPORTED_CHECK: raise newException(XZlibStreamError, "Specified integrity check is not supported")
        else: raise newException(XZlibStreamError, "Unknown error(" & $stat & "), possibly a bug")
    strm.nextIn = nil
    strm.availIn = 0
    strm.nextOut = cast[cstring](addr outbuf)
    strm.availOut = BUFSIZ
    while true:
        strm.nextIn = cast[cstring](addr inbuf)
        strm.availIn = fin.readBuffer(inbuf[0].addr, BUFSIZ)
        if strm.availIn == 0:
            action = LZMA_FINISH
        ret = lzma_code(strm, action)
        if strm.availOut == 0 or ret == LZMA_STREAM_END:
            var writeSize = BUFSIZ - strm.availOut
            discard fout.writeBuffer(outbuf[0].addr, writeSize)
            strm.nextOut = cast[cstring](addr outbuf)
            strm.availOut = BUFSIZ
        if ret != LZMA_OK:
            if ret == LZMA_STREAM_END:
                break
            case ret:
                of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
                of LZMA_DATA_ERROR: raise newException(XZlibStreamError, "File size limits exceeded")
                else: raise newException(XZlibStreamError, "Unknown error(" & $ret & "), possibly a bug")
    lzma_end(strm)
    fin.close
    fout.close
    if rm:
        removeFile(source)
    return source & ".xz"

proc unxz*(source: string, rm=true): string =
    ## decompresses source.xz to source and optionally deletes it
    ## returns uncompressed filename
    if not source.fileExists:
        raise newException(OSError, "Compressed source file missing")
    if fileExists(source[0 .. ^4]):
        raise newException(OSError, "Uncompressed target file already exists")
    var
        fin = open(source)
        fout = open(source[0 .. ^4], fmWrite)
        inbuf: array[BUFSIZ, char]
        outbuf: array[BUFSIZ, char]
        strm = LZMA_STREAM_INIT
        stat = lzma_stream_decoder(strm, high(int), 0)
        ret: int
        action = LZMA_RUN
    case stat:
        of LZMA_OK: discard
        of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
        of LZMA_OPTIONS_ERROR: raise newException(XZlibStreamError, "Unsupported decompressor flags")
        else: raise newException(XZlibStreamError, "Unknown error(" & $stat & "), possibly a bug")
    strm.nextIn = nil
    strm.availIn = 0
    strm.nextOut = cast[cstring](addr outbuf)
    strm.availOut = BUFSIZ
    while true:
        if strm.availIn == 0:
            strm.nextIn = cast[cstring](addr inbuf)
            strm.availIn = fin.readBuffer(inbuf[0].addr, BUFSIZ)
        ret = lzma_code(strm, action)
        if strm.availOut == 0 or ret == LZMA_STREAM_END:
            var writeSize = BUFSIZ - strm.availOut
            discard fout.writeBuffer(outbuf[0].addr, writeSize)
            strm.nextOut = cast[cstring](addr outbuf)
            strm.availOut = BUFSIZ
        if ret != LZMA_OK:
            if ret == LZMA_STREAM_END:
                break
            case ret:
                of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
                of LZMA_FORMAT_ERROR: raise newException(XZlibStreamError, "The input is not in the .xz format")
                of LZMA_OPTIONS_ERROR: raise newException(XZlibStreamError, "Unsupported compression options")
                of LZMA_DATA_ERROR: raise newException(XZlibStreamError, "Compressed file is corrupt")
                of LZMA_BUF_ERROR: raise newException(XZlibStreamError, "Compressed file is truncated or otherwise corrupt")
                else: raise newException(XZlibStreamError, "Unknown error(" & $ret & "), possibly a bug")
    lzma_end(strm)
    fin.close
    fout.close
    if rm:
        removeFile(source)
    return source[0 .. ^4]

proc compress*(inString: cstring, preset=LZMA_PRESET_DEFAULT, check=LZMA_CHECK_CRC64): seq[byte] =
    var
        inSize = inString.len
        outSize : csize_t = lzma_stream_buffer_bound(cast[csize_t](inSize))
        outString = newSeq[byte](outSize + 1)
        outPos : csize_t = 0
    var ret = lzma_easy_buffer_encode(preset, check, nil, inString, inSize, cast[cstring](outString[0].addr), outPos.addr, outSize)
    case ret:
        of LZMA_OK: discard
        of LZMA_BUF_ERROR: raise newException(XZlibStreamError, "Not enough output buffer space")
        of LZMA_OPTIONS_ERROR: raise newException(XZlibStreamError, "Unsupported compression options")
        of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
        of LZMA_DATA_ERROR: raise newException(XZlibStreamError, "Compressed string is corrupt")
        of LZMA_PROG_ERROR: raise newException(XZlibStreamError, "Invalid compression parameters")
        else: raise newException(XZlibStreamError, "Unknown error(" & $ret & "), possibly a bug")
    result = @outString[0..outPos]

proc decompress*(inString: openArray[byte]): cstring =
    var
        memlimit = high(int64)
        inBuf = newSeq[byte](inString.len)
        flags = 0.int32
        inSize = inString.len
        outSize = inSize * 2
        outString = newSeq[byte](outSize)
        inPos = 0
        outPos = 0
    for i in 0..inString.len-1:
        inBuf[i] = inString[i]
    var
        ret = lzma_stream_buffer_decode(memlimit.addr, flags, nil, cast[cstring](inBuf[0].addr), inPos.addr, inSize, cast[cstring](outString[0].addr), outPos.addr, outSize)
    # If the compression ratio is really good, we may need to double the outbuf again
    if ret == LZMA_BUF_ERROR:
        outSize *= 2
        outString = newSeq[byte](outSize)
        ret = lzma_stream_buffer_decode(memlimit.addr, flags, nil, cast[cstring](inBuf[0].addr), inPos.addr, inSize, cast[cstring](outString[0].addr), outPos.addr, outSize)
    case ret:
        of LZMA_OK: discard
        of LZMA_FORMAT_ERROR: raise newException(XZlibStreamError, "The input is not in the .xz format")
        of LZMA_OPTIONS_ERROR: raise newException(XZlibStreamError, "Unsupported decompression options")
        of LZMA_DATA_ERROR: raise newException(XZlibStreamError, "Compressed string is corrupt")        
        of LZMA_MEM_ERROR: raise newException(XZlibStreamError, "Memory allocation failed")
        of LZMA_MEMLIMIT_ERROR: raise newException(XZlibStreamError, "Memory usage limit was reached")
        of LZMA_BUF_ERROR: raise newException(XZlibStreamError, "Not enough output buffer space")
        of LZMA_PROG_ERROR: raise newException(XZlibStreamError, "Invalid decompression parameters")
        else: raise newException(XZlibStreamError, "Unknown error(" & $ret & "), possibly a bug")
    result = cast[cstring](outString[0].addr)

when isMainModule:
    let s = cstring("The quick brown fox jumps over the lazy dog")
    echo(s.compress.decompress)

