-- test_mongo_driver.lua — Tests for lua-mongo.c (skynet.mongo.driver)
-- Covers: op_msg, reply (unpack_reply), length (reply_length)
local skynet = require "skynet"
local T = require "testlib"

T.case("op_msg creates valid OP_MSG packet", function()
    local driver = require "skynet.mongo.driver"
    local bson = require "bson"

    -- Create a simple BSON command document
    local cmd = bson.encode({ ping = 1 })
    local request_id = 12345
    local flags = 0

    local packet = driver.op_msg(request_id, flags, cmd)
    T.assert_true(type(packet) == "string", "op_msg returns string")
    T.assert_true(#packet > 20, "packet has header + payload")

    -- Verify header structure (little-endian int32 fields)
    -- Bytes 0-3: message length
    local len_bytes = packet:sub(1, 4)
    local len = string.byte(len_bytes, 1) +
                string.byte(len_bytes, 2) * 256 +
                string.byte(len_bytes, 3) * 65536 +
                string.byte(len_bytes, 4) * 16777216
    T.assert_eq(#packet, len, "message length matches packet size")

    -- Bytes 4-7: request_id
    local rid = string.byte(packet, 5) +
                string.byte(packet, 6) * 256 +
                string.byte(packet, 7) * 65536 +
                string.byte(packet, 8) * 16777216
    T.assert_eq(request_id, rid, "request_id in header")

    -- Bytes 12-15: opcode should be OP_MSG (2013)
    local opcode = string.byte(packet, 13) +
                   string.byte(packet, 14) * 256 +
                   string.byte(packet, 15) * 65536 +
                   string.byte(packet, 16) * 16777216
    T.assert_eq(2013, opcode, "opcode is OP_MSG")
end)

T.case("op_msg with flags", function()
    local driver = require "skynet.mongo.driver"
    local bson = require "bson"

    local cmd = bson.encode({ hello = 1 })
    local packet = driver.op_msg(1, 2, cmd) -- flags = MSG_MORE_TO_COME
    T.assert_true(type(packet) == "string", "op_msg with flags")
    T.assert_true(#packet > 0, "non-empty packet")
end)

T.case("op_msg with nil cmd errors", function()
    local driver = require "skynet.mongo.driver"
    local ok, err = pcall(driver.op_msg, 1, 0, nil)
    T.assert_true(not ok, "op_msg with nil cmd should error")
end)

T.case("reply_length decodes 4-byte little-endian length", function()
    local driver = require "skynet.mongo.driver"

    -- Encode length 100 in little-endian: 100, 0, 0, 0
    local len_str = string.char(100, 0, 0, 0)
    local result = driver.length(len_str)
    -- reply_length returns length - 4 (subtracts the length field itself)
    T.assert_eq(96, result, "length 100 - 4 = 96")

    -- Encode length 256 + 4 = 260 in little-endian
    local len_str2 = string.char(4, 1, 0, 0) -- 4 + 256 = 260
    local result2 = driver.length(len_str2)
    T.assert_eq(256, result2, "length 260 - 4 = 256")
end)

T.case("reply_length with large value", function()
    local driver = require "skynet.mongo.driver"

    -- 65540 in little-endian: 4, 0, 1, 0
    local len_str = string.char(4, 0, 1, 0)
    local result = driver.length(len_str)
    T.assert_eq(65536, result, "large length - 4")
end)

T.case("unpack_reply with valid OP_MSG response", function()
    local driver = require "skynet.mongo.driver"
    local bson = require "bson"

    -- header_t layout (message_length is NOT included, already stripped by caller):
    --   request_id(4) + response_to(4) + opcode(4) + flags(4) = 16 bytes
    -- Then: payload_type(1) + document
    local doc = bson.encode({ ok = 1 })
    local doc_str = tostring(doc)

    local request_id = 42
    local response_to = 7

    local function le32(v)
        return string.char(v % 256, math.floor(v/256) % 256,
                          math.floor(v/65536) % 256, math.floor(v/16777216) % 256)
    end

    -- No message_length prefix — reply() receives data after length has been stripped
    local msg = le32(request_id) .. le32(response_to) .. le32(2013) .. le32(0) .. string.char(0) .. doc_str

    local succ, id, doc_ptr = driver.reply(msg)
    T.assert_eq(true, succ, "reply success")
    T.assert_eq(response_to, id, "response_to id matches")
    T.assert_true(doc_ptr ~= nil, "document pointer returned")
end)

T.case("unpack_reply with too-short data", function()
    local driver = require "skynet.mongo.driver"
    -- Data shorter than header
    local succ = driver.reply("short")
    T.assert_eq(false, succ, "short data returns false")
end)

T.case("unpack_reply with wrong opcode errors", function()
    local driver = require "skynet.mongo.driver"

    local function le32(v)
        return string.char(v % 256, math.floor(v/256) % 256,
                          math.floor(v/65536) % 256, math.floor(v/16777216) % 256)
    end

    -- header_t: request_id + response_to + opcode + flags (no message_length)
    -- Use wrong opcode (2012 = OP_COMPRESSED)
    local msg = le32(1) .. le32(1) .. le32(2012) .. le32(0) .. string.rep("\0", 20)
    local ok, err = pcall(driver.reply, msg)
    T.assert_true(not ok, "wrong opcode should error")
end)

T.case("unpack_reply with MORE_TO_COME flag", function()
    local driver = require "skynet.mongo.driver"
    local bson = require "bson"

    local function le32(v)
        return string.char(v % 256, math.floor(v/256) % 256,
                          math.floor(v/65536) % 256, math.floor(v/16777216) % 256)
    end

    local doc = bson.encode({ ok = 1 })
    local doc_str = tostring(doc)

    -- header_t: request_id + response_to + opcode + flags (no message_length)
    -- MSG_MORE_TO_COME = 1 << 1 = 2
    local msg = le32(1) .. le32(5) .. le32(2013) .. le32(2) .. string.char(0) .. doc_str

    local succ, id, doc_ptr = driver.reply(msg)
    T.assert_eq(true, succ, "MORE_TO_COME flag accepted")
    T.assert_eq(5, id, "response_to id")
end)

T.run()
