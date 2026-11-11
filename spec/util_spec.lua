local helper = dofile("spec/helper.lua")

describe("Util.Sanitize", function()
	local Util

	before_each(function()
		Util = helper.load().Util
	end)

	it("removes color codes", function()
		assert.equals("red text", Util.Sanitize("|cffff0000red|r text"))
	end)

	it("removes textures and atlases", function()
		assert.equals("a b", Util.Sanitize("a |TInterface\\Icons\\x:16|t|A:foo:16:16|ab"))
	end)

	it("removes hyperlinks but keeps their visible text", function()
		assert.equals("[Sword]", Util.Sanitize("|Hitem:1234:0|h[Sword]|h"))
	end)

	it("removes stray pipes and unbalanced escapes", function()
		assert.equals("ab c", Util.Sanitize("a|b ||c"))
		assert.equals("xyz", Util.Sanitize("x|Tyz"))
	end)

	it("leaves no pipe character in any output", function()
		local nasty = "|cnRED:x|r |K1|k |Hplayer:Bob|h[Bob]|h |T1:1|t || | |n |A:a:1:1|a"
		assert.is_nil(Util.Sanitize(nasty):find("|", 1, true))
	end)

	it("replaces control characters and collapses spaces", function()
		assert.equals("a b c", Util.Sanitize("  a\n\tb\r\n   c  "))
	end)

	it("cuts to 140 characters by default", function()
		assert.equals(140, #Util.Sanitize(string.rep("x", 500)))
	end)

	it("does not split a multi-byte character", function()
		local s = string.rep("\195\169", 10) -- ten two-byte characters
		assert.equals(string.rep("\195\169", 3), Util.Sanitize(s, 3))
	end)

	it("returns an empty string for non-strings", function()
		assert.equals("", Util.Sanitize(nil))
		assert.equals("", Util.Sanitize({}))
	end)
end)

describe("Util helpers", function()
	local Util

	before_each(function()
		Util = helper.load().Util
	end)

	it("builds case-insensitive name keys", function()
		assert.equals("n:bob-stormrage", Util.NameKey("Bob", "Stormrage"))
		assert.equals("n:bob", Util.NameKey("Bob", nil))
		assert.equals("n:bob", Util.NameKey("Bob", ""))
	end)

	it("splits typed names", function()
		local name, suffix = Util.SplitTypedName("Bob-Area 52")
		assert.equals("Bob", name)
		assert.equals("Area 52", suffix)
		name, suffix = Util.SplitTypedName("Bob")
		assert.equals("Bob", name)
		assert.is_nil(suffix)
		assert.is_nil(Util.SplitTypedName("   "))
	end)

	it("merges defaults without overwriting valid values", function()
		local dst = { a = 5, b = "wrong type" }
		Util.MergeDefaults(dst, { a = 1, b = true, c = { d = 2 } })
		assert.equals(5, dst.a)
		assert.equals(true, dst.b)
		assert.equals(2, dst.c.d)
	end)

	it("deep copies without sharing tables", function()
		local src = { a = { b = 1 } }
		local copy = Util.DeepCopy(src)
		copy.a.b = 2
		assert.equals(1, src.a.b)
	end)

	it("parses legacy dates", function()
		assert.is_not_nil(Util.ParseLegacyDate("2025-05-31 20:15"))
		assert.is_nil(Util.ParseLegacyDate("yesterday"))
		assert.is_nil(Util.ParseLegacyDate(nil))
	end)

	it("escapes pipes for display", function()
		assert.equals("a||b", Util.Escape("a|b"))
	end)
end)
