local emoji = "🎃"
assert(utf8.len(emoji) == 1)
assert(utf8.char(0x1F383) == emoji)
assert(emoji:match(utf8.charpattern) == emoji)
print(utf8.offset(emoji, 1) == 1)
