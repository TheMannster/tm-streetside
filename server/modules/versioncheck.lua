if Config.VersionCheck and Config.VersionCheck.Enabled == false then return end

local REPO     = 'TheMannster/tm-streetside'
local BRANCH   = 'main'
local RESOURCE = GetCurrentResourceName()
local LOCAL    = GetResourceMetadata(RESOURCE, 'version', 0) or '0.0.0'

local RAW = ('https://raw.githubusercontent.com/%s/%s'):format(REPO, BRANCH)

local function parseVersion(str)
    str = tostring(str or ''):gsub('^[vV]', '')
    local parts = {}
    for chunk in str:gmatch('[^%.]+') do
        parts[#parts + 1] = tonumber(chunk) or 0
    end
    return parts
end

local function compareVersions(a, b)
    local pa, pb = parseVersion(a), parseVersion(b)
    local n = math.max(#pa, #pb)
    for i = 1, n do
        local av, bv = pa[i] or 0, pb[i] or 0
        if av < bv then return -1
        elseif av > bv then return 1 end
    end
    return 0
end

-- Returns just the top section (latest version block) of a CHANGELOG.md.
-- Standard format: each version is delimited by a level-2 heading like
-- "## [1.2.0]" or "## 1.2.0".
local function topChangelogSection(md)
    if not md or md == '' then return nil end
    local first = md:find('\n##%s')
    if not first then return md end
    local rest = md:sub(first + 1)
    local second = rest:find('\n##%s')
    if second then
        return rest:sub(1, second - 1)
    end
    return rest
end

-- Plaintext for FiveM console (no Markdown noise).
local function changelogLineToPlain(line)
    local l = line
    l = l:gsub('^%s*#+%s+', '')
    l = l:gsub('`([^`]*)`', "'%1'")
    l = l:gsub('`', '')
    l = l:gsub('%*%*', '')
    l = l:gsub('^%s*%-%s+', '• ')
    l = l:gsub('—', ' - ')
    return (l:match('^%s*(.-)%s*$') or l)
end

local function wordwrap(str, maxLen, indent)
    local res = {}
    local line = ''
    for word in str:gmatch('%S+') do
        local test = (line == '' and (indent .. word) or (line .. ' ' .. word))
        if #test > maxLen and line ~= '' then
            res[#res + 1] = line
            line = indent .. word
        elseif line == '' then
            line = indent .. word
        else
            line = line .. ' ' .. word
        end
    end
    if line ~= '' then res[#res + 1] = line end
    return res
end

local function printOutdatedNotice(localVer, remoteVer, changelogRaw)
    local function pl(s)
        print(s .. '^7')
    end

    pl('')
    pl('^5----------------------------------------------------')
    pl(('^3[TM:version WARN]^7  Update available  ^3v%s^7 → ^2v%s^7'):format(localVer, remoteVer))
    pl('^5----------------------------------------------------')
    pl(('^7  Download: ^4https://github.com/%s^7'):format(REPO))
    pl('^5----------------------------------------------------')

    local section = topChangelogSection(changelogRaw)
    if section and section:match('%S') then
        pl('^7  ^5Latest release notes:^7')
        local lines = {}
        for line in (section .. '\n'):gmatch('([^\n]*)\n') do
            if line:match('%S') then lines[#lines + 1] = line end
        end

        if #lines > 0 then
            local firstPlain = changelogLineToPlain(lines[1])
            local onlyVersion = firstPlain:match('^%[([%d%.]+)%]$')
            if onlyVersion then
                pl(('^7    ^2v%s^7'):format(onlyVersion))
                table.remove(lines, 1)
            end
        end

        for _, raw in ipairs(lines) do
            local plain = changelogLineToPlain(raw)
            if plain ~= '' then
                for _, w in ipairs(wordwrap(plain, 72, '  ')) do
                    pl('^7' .. w)
                end
            end
        end
    else
        pl('^9  (Changelog not available; check the repo on GitHub.)^7')
    end

    pl('^5----------------------------------------------------')
    pl('')
end

local function fetch(url, cb)
    PerformHttpRequest(url, function(status, body, _h)
        cb((status == 200) and body or nil, status)
    end, 'GET', '', { ['User-Agent'] = 'tm-streetside-versioncheck' })
end

CreateThread(function()
    Wait(3000)

    fetch(RAW .. '/fxmanifest.lua', function(manifest, status)
        if not manifest then
            TM.Log.warn('version',
                ('check failed (HTTP %s) - running ^2v%s^7'):format(tostring(status), LOCAL))
            return
        end

        local padded = '\n' .. manifest
        local remote = padded:match("[\n\r;]version%s+'([^']+)'")
                    or padded:match('[\n\r;]version%s+"([^"]+)"')
        if not remote then
            TM.Log.warn('version', 'could not find version field in remote fxmanifest.lua')
            return
        end

        local cmp = compareVersions(LOCAL, remote)
        if cmp == 0 then
            TM.Log.info('version',
                ('Up to date (^2v%s^7, GitHub ^2v%s^7)'):format(LOCAL, remote))
            return
        end

        if cmp > 0 then
            TM.Log.info('version',
                ('Pre-release build (^2v%s^7) — ahead of the published GitHub release (^2v%s^7)'):format(
                    LOCAL, remote))
            return
        end

        fetch(RAW .. '/CHANGELOG.md', function(changelog)
            printOutdatedNotice(LOCAL, remote, changelog)
        end)
    end)
end)
