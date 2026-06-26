-- test_crypt_extra.lua — Extended crypt tests covering more C functions
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local crypt = require "skynet.crypt"

                -- Test hashkey
                local hash = crypt.hashkey("test_key_string")
                testlib.assert_true(type(hash) == "string", "hashkey should return string")
                testlib.assert_eq(8, #hash, "hashkey should return 8 bytes")

                -- hashkey deterministic
                local hash2 = crypt.hashkey("test_key_string")
                testlib.assert_eq(hash, hash2, "hashkey should be deterministic")

                -- different input gives different hash
                local hash3 = crypt.hashkey("different_key")
                testlib.assert_ne(hash, hash3, "different input should give different hash")

                -- Test randomkey
                local rk1 = crypt.randomkey()
                testlib.assert_true(type(rk1) == "string", "randomkey should return string")
                testlib.assert_eq(8, #rk1, "randomkey should return 8 bytes")

                local rk2 = crypt.randomkey()
                testlib.assert_ne(rk1, rk2, "randomkey should be different each time")

                -- Test Diffie-Hellman key exchange
                local key1 = crypt.randomkey()
                local key2 = crypt.randomkey()

                local pub1 = crypt.dhexchange(key1)
                testlib.assert_true(type(pub1) == "string", "dhexchange should return string")
                testlib.assert_eq(8, #pub1, "dhexchange should return 8 bytes")

                local pub2 = crypt.dhexchange(key2)
                testlib.assert_true(type(pub2) == "string", "dhexchange should return string")

                -- Both sides derive the same secret
                local secret1 = crypt.dhsecret(pub2, key1)
                local secret2 = crypt.dhsecret(pub1, key2)
                testlib.assert_eq(secret1, secret2, "DH secrets should match")
                testlib.assert_eq(8, #secret1, "DH secret should be 8 bytes")

                -- Test hmac64 (both args must be exactly 8 bytes)
                local challenge8 = crypt.hashkey("challenge")
                local secret8 = crypt.hashkey("secret")
                testlib.assert_eq(8, #challenge8, "hashkey for hmac64 should be 8 bytes")
                testlib.assert_eq(8, #secret8, "hashkey for hmac64 should be 8 bytes")

                local hmac = crypt.hmac64(challenge8, secret8)
                testlib.assert_true(type(hmac) == "string", "hmac64 should return string")
                testlib.assert_eq(8, #hmac, "hmac64 should return 8 bytes")

                -- hmac64 deterministic
                local hmac2 = crypt.hmac64(challenge8, secret8)
                testlib.assert_eq(hmac, hmac2, "hmac64 should be deterministic")

                -- Test hmac64_md5 (both args must be exactly 8 bytes)
                local hmac_md5 = crypt.hmac64_md5(challenge8, secret8)
                testlib.assert_true(type(hmac_md5) == "string", "hmac64_md5 should return string")
                testlib.assert_eq(8, #hmac_md5, "hmac64_md5 should return 8 bytes")

                -- Test sha1
                local sha = crypt.sha1("hello")
                testlib.assert_true(type(sha) == "string", "sha1 should return string")
                testlib.assert_eq(20, #sha, "sha1 should return 20 bytes")

                -- sha1 deterministic
                local sha2 = crypt.sha1("hello")
                testlib.assert_eq(sha, sha2, "sha1 should be deterministic")

                -- sha1 empty string
                local sha_empty = crypt.sha1("")
                testlib.assert_eq(20, #sha_empty, "sha1 of empty string should be 20 bytes")

                -- sha1 different input gives different hash
                local sha_other = crypt.sha1("world")
                testlib.assert_ne(sha, sha_other, "different input different sha1")

                -- Test hexdecode (inverse of hexencode)
                local hex = crypt.hexencode("hello")
                local dehex = crypt.hexdecode(hex)
                testlib.assert_eq("hello", dehex, "hexdecode should reverse hexencode")

                -- hexdecode of known hex string
                local dehex2 = crypt.hexdecode("48454c4c4f")
                testlib.assert_eq("HELLO", dehex2, "hexdecode of known hex")

                -- Test hmac_hash (first arg must be exactly 8 bytes)
                local hmac_h = crypt.hmac_hash(crypt.hashkey("mykey"), "message to hash")
                testlib.assert_true(type(hmac_h) == "string", "hmac_hash should return string")
                testlib.assert_eq(8, #hmac_h, "hmac_hash should return 8 bytes")

                -- Test base64 edge cases
                local b64_empty = crypt.base64encode("")
                testlib.assert_eq("", crypt.base64decode(b64_empty), "base64 empty round-trip")

                local b64_one = crypt.base64encode("a")
                testlib.assert_eq("a", crypt.base64decode(b64_one), "base64 single char")

                -- Test base64 with binary data
                local binary = string.char(0, 1, 2, 255, 254, 128)
                local b64_bin = crypt.base64encode(binary)
                testlib.assert_eq(binary, crypt.base64decode(b64_bin), "base64 binary round-trip")

                -- Test xor_str with different lengths
                local xor1 = crypt.xor_str("abcd", "1234")
                testlib.assert_eq(4, #xor1, "xor_str should return same length")
                -- xor with self should be all zeros
                local xor_self = crypt.xor_str("abcd", "abcd")
                testlib.assert_eq(string.char(0,0,0,0), xor_self, "xor with self should be zeros")

                -- Test DES with different padding modes
                local key = "testkey8"

                -- Test iso7816_4 with various lengths
                for i = 1, 8 do
                    local input = string.rep("z", i)
                    local enc = crypt.desencode(key, input, crypt.padding.iso7816_4)
                    local dec = crypt.desdecode(key, enc, crypt.padding.iso7816_4)
                    testlib.assert_eq(input, dec, "DES iso7816_4 round-trip len " .. i)
                end

                -- Test pkcs7 with various lengths
                for i = 1, 16 do
                    local input = string.rep("x", i)
                    local enc = crypt.desencode(key, input, crypt.padding.pkcs7)
                    local dec = crypt.desdecode(key, enc, crypt.padding.pkcs7)
                    testlib.assert_eq(input, dec, "DES pkcs7 round-trip len " .. i)
                end

                -- Test hmac_sha1 with longer inputs
                local hmac_long = crypt.hmac_sha1("a_secret_key_longer_than_block", "message data to authenticate")
                testlib.assert_true(type(hmac_long) == "string", "hmac_sha1 long key should work")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
