-- test_sproto.lua — Test sproto C library (encode/decode/pack/unpack)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local sprotoparser = require "sprotoparser"
                local sproto = require "sproto"
                testlib.assert_true(type(sprotoparser) == "table", "sprotoparser should be table")
                testlib.assert_true(type(sproto) == "table", "sproto should be table")

                -- Define a simple protocol
                local schema = [[
                .Person {
                    name 0 : string
                    age 1 : integer
                    married 2 : boolean
                }

                .Item {
                    id 0 : integer
                    name 1 : string
                    count 2 : integer
                }

                .Inventory {
                    items 0 : *Item
                }

                hello 1 {
                    request {
                        who 0 : string
                    }
                    response {
                        msg 0 : string
                    }
                }
                ]]

                local bin = sprotoparser.parse(schema)
                testlib.assert_true(type(bin) == "string", "parse should return binary string")
                testlib.assert_true(#bin > 0, "parsed binary should be non-empty")

                local sp = sproto.new(bin)
                testlib.assert_true(sp ~= nil, "sproto.new should succeed")

                -- Test encode/decode Person
                local person_data = { name = "Alice", age = 30, married = true }
                local encoded = sp:encode("Person", person_data)
                testlib.assert_true(type(encoded) == "string", "encode should return string")
                testlib.assert_true(#encoded > 0, "encoded should be non-empty")

                local decoded = sp:decode("Person", encoded)
                testlib.assert_eq("Alice", decoded.name, "decoded name")
                testlib.assert_eq(30, decoded.age, "decoded age")
                testlib.assert_eq(true, decoded.married, "decoded married")

                -- Test encode/decode with default values
                local partial = { name = "Bob" }
                local enc2 = sp:encode("Person", partial)
                local dec2 = sp:decode("Person", enc2)
                testlib.assert_eq("Bob", dec2.name, "partial decode name")

                -- Test repeated field (array)
                local inv_data = {
                    items = {
                        { id = 1, name = "sword", count = 1 },
                        { id = 2, name = "shield", count = 2 },
                        { id = 3, name = "potion", count = 10 },
                    }
                }
                local inv_enc = sp:encode("Inventory", inv_data)
                local inv_dec = sp:decode("Inventory", inv_enc)
                testlib.assert_eq(3, #inv_dec.items, "inventory should have 3 items")
                testlib.assert_eq("sword", inv_dec.items[1].name, "item 1 name")
                testlib.assert_eq(10, inv_dec.items[3].count, "item 3 count")

                -- Test exist_type
                testlib.assert_true(sp:exist_type("Person"), "Person type should exist")
                testlib.assert_true(sp:exist_type("Item"), "Item type should exist")
                testlib.assert_false(sp:exist_type("NonExist"), "NonExist type should not exist")

                -- Test sproto pack/unpack (0-compression)
                local core = require "sproto.core"
                testlib.assert_true(type(core.pack) == "function", "core.pack should be function")
                testlib.assert_true(type(core.unpack) == "function", "core.unpack should be function")

                local test_data = string.rep("\x01\x02\x03\x04", 100)
                local packed = core.pack(test_data)
                testlib.assert_true(type(packed) == "string", "pack should return string")
                local unpacked = core.unpack(packed)
                testlib.assert_eq(test_data, unpacked, "pack/unpack round-trip")

                -- Test pack with zeros (good compression)
                local zeros = string.rep("\x00", 200)
                local packed_zeros = core.pack(zeros)
                testlib.assert_true(#packed_zeros < #zeros, "zeros should compress well")
                local unpacked_zeros = core.unpack(packed_zeros)
                testlib.assert_eq(zeros, unpacked_zeros, "zeros pack/unpack")

                -- Test encode empty table
                local empty_person = {}
                local enc_empty = sp:encode("Person", empty_person)
                testlib.assert_true(type(enc_empty) == "string", "encode empty should work")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
