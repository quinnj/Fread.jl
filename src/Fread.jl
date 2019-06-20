module Fread

using Mmap

Base.getindex(ptr::Ptr{UInt8}) = unsafe_load(ptr)

function skip_white(pch)
    ch = pch[]
    while ch[] == UInt8(' ') || ch[] == UInt8('\t')
        ch += 1
    end
    pch[] = ch
    return
end

function eol(pch)
    ch = pch[]
    while ch[] == UInt8('\r')
        ch += 1
    end
    if ch[] == UInt8('\n')
        pch[] = ch
        return true
    end
    return pch[][] == UInt8('\r')
end

function countfields(pch, sep, eof)
    skip_white(pch)
    ch = pch[]
    if eol(pch) || ch == eof
        pch[] = ch + 1
        return 0
    end
    ncol = 1
    while ch < eof
        ch, off, len = Field(ch, sep, C_NULL)
        if ch[] == sep
            ch += 1
            ncol += 1
            continue
        end
        pch[] = ch
        if eol(pch)
            pch[] += 1
            return ncol
        end
        break
    end
    pch[] = ch
    return ncol
end

end_of_field(ch, sep) = ch[] === sep || ch[] <= 13 && (ch[] == 0x00 || eol(Ref(ch)))

function Field(ch, sep, anchor)
    fieldStart = ch
    if ch[] !== UInt8('"')
        while !end_of_field(ch, sep)
            ch += 1
        end
        fieldLen = Int(ch - fieldStart)
        return ch, Int(fieldStart - anchor), fieldLen
    end
end

function fread(file)
    t0 = time()
    mmp = Mmap.mmap(file)
    fileSize = filesize(file)
    sof = pointer(mmp)
    eof = sof + fileSize
    tMap = time()
    pos = sof
    row1line = 1
    ch = pos
    lineStart = ch
    ch = pos = lineStart
    jumpLines = 100
    seps = [',', '\0']
    nseps = 1
    topSep = UInt8(127)
    topNumLines=0
    topNumFields=1
    topQuoteRule=-1
    topSkip=0
    firstJumpEnd = C_NULL
    prevStart = C_NULL
    topStart = C_NULL
    for quoteRule = 0:3
        for s = 1:nseps+1
            sep = seps[s]
            whiteChar = 0
            ch = pos
            prevLineStart=ch
            lineStart=ch
            pch = Ref(ch)
            lastncol = countfields(pch, sep, eof)
            ch = pch[]
            thisBlockStart = lineStart
            thisBlockPrevStart = C_NULL
            thisBlockLines = 1
            thisRow = 0
            while ch < eof && (thisRow += 1) < jumpLines
                prevLineStart = lineStart
                lineStart = ch
                pch = Ref(ch)
                thisncol = countfields(pch, sep, eof)
                ch = pch[]
                if thisncol == lastncol
                    thisBlockLines += 1
                    continue
                end
            end
            if (thisBlockLines > topNumLines && lastncol > 1) ||
                (thisBlockLines == topNumLines &&
                lastncol > topNumFields &&
                (quoteRule < 2 || quoteRule <= topQuoteRule) &&
                (topNumFields <= 1 || sep !== UInt8(' ')))
                topNumLines = thisBlockLines
                topNumFields = lastncol
                topSep = sep
                topQuoteRule = quoteRule
                firstJumpEnd = ch
                topStart = thisBlockStart
                prevstart = thisBlockPrevStart
                topSkip = thisRow - thisBlockLines
            end
        end
    end
    quoteRule = topQuoteRule
    sep = topSep
    ncol = topNumFields
    ch = pos = topStart
    row1line += topSkip
    pch = Ref(ch)
    tt = countfields(pch, sep, eof)
    ch = pos

    nJumps = 0
    sampleLines = 0
    autoFirstColName = false
    estnrow = 1
    allocnrow = 0
    meanLineLen = 0.0
    bytesRead = 0
    type = zeros(Int8, ncol)
    tmpType = zeros(Int8, ncol)
    type0 = Int8(1)
    for j = 1:ncol
        tmpType[j] = type[j] = type0
    end
    jump0size = Int(firstJumpEnd - pos)
    nJumps = 1
    sz = Int(eof - pos)
    if jump0size > 0
        if jump0size * 100 * 2 < sz
            nJumps = 100
        elseif jump0size * 10 * 2 < sz
            nJumps = 10
        end
    end
    nJumps += 1
    sampleLines = 0
    sumLen = 0.0
    sumLenSq = 0.0
    minLen = typemax(Int32)
    maxLen = -1
    lastRowEnd = pos
    firstRowStart = pos
    for jump = 1:nJumps
        
    end
end

end # module
