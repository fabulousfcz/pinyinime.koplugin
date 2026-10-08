local source = debug.getinfo(1, "S").source:gsub("^@", "")
local plugin_root = source:match("^(.*)/lib/english_suggestions%.lua$")
local WORDS = dofile(plugin_root .. "/data/english_words.lua")

local MAX_CANDIDATES = 5
local MIN_PREFIX_LENGTH = 2
local MAX_PREFIX_LENGTH = 18
local MAX_LEARNED_WORDS = 500

local buckets = {}
for rank, word in ipairs(WORDS) do
    local prefix = word:sub(1, 2)
    local bucket = buckets[prefix]
    if not bucket then
        bucket = {}
        buckets[prefix] = bucket
    end
    bucket[#bucket + 1] = { word = word, rank = rank }
end

local EnglishSuggestions = {}

local function wordCase(word, prefix)
    if prefix == prefix:upper() then
        return word:upper()
    elseif prefix:sub(1, 1) == prefix:sub(1, 1):upper() then
        return word:sub(1, 1):upper() .. word:sub(2)
    end
    return word
end

local function getCurrentWord(inputbox)
    local chars = inputbox.charlist or {}
    local cursor = inputbox.charpos or (#chars + 1)
    if cursor ~= #chars + 1 then
        return nil
    end
    local reverse = {}
    for index = cursor - 1, 1, -1 do
        local char = chars[index]
        if type(char) == "string" and char:match("^[A-Za-z]$") then
            reverse[#reverse + 1] = char
        else
            break
        end
    end
    local prefix = {}
    for index = #reverse, 1, -1 do
        prefix[#prefix + 1] = reverse[index]
    end
    local word = table.concat(prefix)
    if #word < MIN_PREFIX_LENGTH or #word > MAX_PREFIX_LENGTH then
        return nil
    end
    return word
end

function EnglishSuggestions:new(inputbox, keyboard, settings)
    return setmetatable({
        inputbox = inputbox,
        keyboard = keyboard,
        settings = settings,
        current_prefix = nil,
        current_candidates = {},
    }, { __index = self })
end

function EnglishSuggestions:getState()
    local prefix = getCurrentWord(self.inputbox)
    self.current_prefix = prefix
    self.current_candidates = {}
    if not prefix then
        return { candidates = {}, candidate_count = 0 }
    end

    local lower_prefix = prefix:lower()
    local bucket = buckets[lower_prefix:sub(1, 2)] or {}
    local learned = self.settings and self.settings.isPersonalizationEnabled
            and self.settings:isPersonalizationEnabled()
        and self.settings.english_word_frequency or {}
    local ranked = {}
    for _, item in ipairs(bucket) do
        local word = item.word
        if #word > #lower_prefix and word:sub(1, #lower_prefix) == lower_prefix then
            local score = (tonumber(learned[word]) or 0) * 100000 - item.rank
            local candidate = wordCase(word, prefix)
            local insert_at = #ranked + 1
            for index, existing in ipairs(ranked) do
                if score > existing.score then
                    insert_at = index
                    break
                end
            end
            table.insert(ranked, insert_at, { text = candidate, score = score })
            if #ranked > MAX_CANDIDATES then
                table.remove(ranked)
            end
        end
    end

    local kinds = {}
    for index, item in ipairs(ranked) do
        self.current_candidates[index] = item.text
        kinds[index] = "completion"
    end
    return {
        code = prefix,
        candidates = self.current_candidates,
        candidate_kinds = kinds,
        candidate_count = #self.current_candidates,
        selected_index = 1,
    }
end

function EnglishSuggestions:accept(slot)
    local state = self:getState()
    local candidate = state.candidates[slot]
    local prefix = self.current_prefix
    if not candidate or not prefix then
        return false
    end
    for _ = 1, #prefix do
        self.inputbox:delChar()
    end
    self.inputbox:addChars(candidate .. " ")

    if self.settings and self.settings.learnEnglishWord then
        self.settings:learnEnglishWord(candidate:lower(), MAX_LEARNED_WORDS)
    end
    return true
end

return EnglishSuggestions
