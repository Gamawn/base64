# base64

Example:

```zig
const in = "Ym9hcmRmZA==";
const expect = "boardfd";

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const b = Base64.init();

const in_result = try b.decode(allocator, in);

try testing.expectEqualDeep(expect, in_result);
```