-- test_socket_buffer.lua — Test lua-socket.c buffer operations (buffer/push/pop/readall/readline/clear/header/str2p/drop)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local driver = require "skynet.socketdriver"
                testlib.assert_true(type(driver) == "table", "socketdriver should be a table")

                -- Test driver.buffer: creates a new socket buffer
                local buf = driver.buffer()
                testlib.assert_true(buf ~= nil, "buffer() should return userdata")

                -- Create a buffer pool table (pool[1] = free_node lightuserdata or nil)
                local pool = {}

                -- Test driver.push: push data into buffer
                -- push(buffer, pool, msg_lightuserdata, size) → returns total size
                local msg1 = driver.str2p("hello world")
                local total = driver.push(buf, pool, msg1, 11)
                testlib.assert_true(type(total) == "number", "push should return total size")
                testlib.assert_eq(11, total, "first push total should equal msg size")

                -- Push more data
                local msg2 = driver.str2p("second data!")
                local total2 = driver.push(buf, pool, msg2, 12)
                testlib.assert_eq(23, total2, "total should accumulate")

                -- Test driver.pop: pop specified bytes from buffer
                -- pop(buffer, pool, size) → (string_or_nil, remaining_size)
                local data, remaining = driver.pop(buf, pool, 11)
                testlib.assert_true(type(data) == "string", "pop should return string")
                testlib.assert_eq("hello world", data, "popped data should match")
                testlib.assert_eq(12, remaining, "remaining should be 12")

                -- Test driver.readall: read all remaining data
                local all = driver.readall(buf, pool)
                testlib.assert_true(type(all) == "string", "readall should return string")
                testlib.assert_eq("second data!", all, "readall should return remaining data")

                -- Push again for clear test
                local msg3 = driver.str2p("clear_test")
                driver.push(buf, pool, msg3, 10)

                -- Test driver.clear: clears all buffer content
                driver.clear(buf, pool)

                -- After clear, readall should return empty
                local after_clear = driver.readall(buf, pool)
                testlib.assert_eq("", after_clear, "readall after clear should be empty")

                -- Test driver.readline: read until separator
                local line_data = "line1\nline2\nline3\n"
                local line_msg = driver.str2p(line_data)
                driver.push(buf, pool, line_msg, #line_data)

                -- readline(buffer, pool_or_nil, separator) → string or nil
                -- With pool=nil, it only checks if line is available
                local check = driver.readline(buf, nil, "\n")
                testlib.assert_true(check == true, "readline check should return true when line available")

                -- With pool table, it actually consumes the line
                local line1 = driver.readline(buf, pool, "\n")
                testlib.assert_eq("line1", line1, "first readline should return line1")

                local line2 = driver.readline(buf, pool, "\n")
                testlib.assert_eq("line2", line2, "second readline should return line2")

                local line3 = driver.readline(buf, pool, "\n")
                testlib.assert_eq("line3", line3, "third readline should return line3")

                -- No more lines
                local no_line = driver.readline(buf, pool, "\n")
                testlib.assert_eq(nil, no_line, "no more lines")

                -- Test driver.header: parses big-endian integer from string
                -- 1 byte
                local h1 = driver.header("\x05")
                testlib.assert_eq(5, h1, "1-byte header")

                -- 2 bytes big-endian
                local h2 = driver.header("\x01\x00")
                testlib.assert_eq(256, h2, "2-byte header 0x0100")

                local h2b = driver.header("\x00\xFF")
                testlib.assert_eq(255, h2b, "2-byte header 0x00FF")

                -- 4 bytes big-endian
                local h4 = driver.header("\x00\x01\x00\x00")
                testlib.assert_eq(65536, h4, "4-byte header 0x00010000")

                -- Test driver.str2p: converts string to lightuserdata (malloc copy)
                local test_str = "str2p test data"
                local ud = driver.str2p(test_str)
                testlib.assert_true(ud ~= nil, "str2p should return lightuserdata")

                -- Use str2p result in buffer
                driver.push(buf, pool, ud, #test_str)
                local readback = driver.readall(buf, pool)
                testlib.assert_eq(test_str, readback, "str2p data should round-trip through buffer")

                -- Test driver.pop with size 0 (should return nil)
                local msg4 = driver.str2p("pop_test")
                driver.push(buf, pool, msg4, 8)
                local nil_pop, rem = driver.pop(buf, pool, 0)
                testlib.assert_eq(nil, nil_pop, "pop with size 0 should return nil")
                driver.clear(buf, pool)

                -- Test driver.pop with size larger than buffer
                local msg5 = driver.str2p("small")
                driver.push(buf, pool, msg5, 5)
                local big_pop, rem2 = driver.pop(buf, pool, 100)
                testlib.assert_eq(nil, big_pop, "pop with too-large size should return nil")
                driver.clear(buf, pool)

                -- Test readline with multi-char separator
                local multi_sep_data = "part1\r\npart2\r\n"
                local multi_msg = driver.str2p(multi_sep_data)
                driver.push(buf, pool, multi_msg, #multi_sep_data)
                local mline1 = driver.readline(buf, pool, "\r\n")
                testlib.assert_eq("part1", mline1, "readline with \\r\\n separator")
                local mline2 = driver.readline(buf, pool, "\r\n")
                testlib.assert_eq("part2", mline2, "second readline with \\r\\n")
                driver.clear(buf, pool)

                -- Test readline on empty buffer
                local empty_line = driver.readline(buf, pool, "\n")
                testlib.assert_eq(nil, empty_line, "readline on empty buffer returns nil")

                -- Test multiple pushes then pop spanning nodes
                for i = 1, 20 do
                    local chunk = driver.str2p(string.format("chunk%02d_", i))
                    driver.push(buf, pool, chunk, 9)
                end
                -- Total = 20 * 9 = 180 bytes
                local big_data, big_rem = driver.pop(buf, pool, 180)
                testlib.assert_eq(180, #big_data, "pop spanning multiple nodes")
                testlib.assert_eq(0, big_rem, "remaining should be 0")

                -- Test driver.drop: frees a lightuserdata msg
                local drop_msg = driver.str2p("to_be_dropped")
                driver.drop(drop_msg, #"to_be_dropped")

                -- Test driver.info: returns socket info list
                local info = driver.info()
                testlib.assert_true(type(info) == "table", "info should return table")

                -- Test clear with nil buffer (should not error)
                driver.clear(nil, pool)

                -- Test header with 3-byte value
                local h3 = driver.header("\x01\x00\x00")
                testlib.assert_eq(65536, h3, "3-byte header 0x010000")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
