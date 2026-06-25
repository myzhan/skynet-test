-- test_crypt.lua — Test skynet.crypt (DES, base64, MD5)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local crypt = require "skynet.crypt"
                testlib.assert_true(type(crypt) == "table", "crypt module should be a table")

                -- Test base64 encode/decode
                local encoded = crypt.base64encode("hello world")
                testlib.assert_true(type(encoded) == "string", "base64encode should return string")
                local decoded = crypt.base64decode(encoded)
                testlib.assert_eq("hello world", decoded, "base64 round-trip")

                -- Test hex encode
                local hex = crypt.hexencode("abc")
                testlib.assert_eq("616263", hex, "hexencode should produce hex string")

                -- Test DES encode/decode
                local key = "12345678"
                local des_encoded = crypt.desencode(key, "test", crypt.padding.pkcs7)
                testlib.assert_true(type(des_encoded) == "string", "desencode should return string")
                local des_decoded = crypt.desdecode(key, des_encoded, crypt.padding.pkcs7)
                testlib.assert_eq("test", des_decoded, "DES round-trip")

                -- Test DES with empty string
                local empty_enc = crypt.desencode(key, "", crypt.padding.pkcs7)
                local empty_dec = crypt.desdecode(key, empty_enc, crypt.padding.pkcs7)
                testlib.assert_eq("", empty_dec, "DES empty string round-trip")

                -- Test DES with iso7816_4 padding
                local des_enc2 = crypt.desencode(key, "abc", crypt.padding.iso7816_4)
                local des_dec2 = crypt.desdecode(key, des_enc2, crypt.padding.iso7816_4)
                testlib.assert_eq("abc", des_dec2, "DES iso7816_4 round-trip")

                -- Test base64 encode of binary data
                local raw = crypt.desencode(key, "raw", crypt.padding.pkcs7)
                local b64 = crypt.base64encode(raw)
                local raw2 = crypt.base64decode(b64)
                local result = crypt.desdecode(key, raw2, crypt.padding.pkcs7)
                testlib.assert_eq("raw", result, "base64 + DES round-trip")

                -- Test xor_str
                local xored = crypt.xor_str("abc", "xyz")
                testlib.assert_true(type(xored) == "string", "xor_str should return string")

                -- Test hmac_sha1 (takes binary key + message)
                local hmac_result = crypt.hmac_sha1(key, "message")
                testlib.assert_true(type(hmac_result) == "string", "hmac_sha1 should return string")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
