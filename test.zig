const std = @import("std");
const Hasher = @import("lib.zig").Hasher;

const expectEqualSlices = std.testing.expectEqualSlices;

test "single input little endian" {
    const input: [32]u8 = .{1} ** 32;
    const hash = try Hasher.hash(&input, .little);

    try expectEqualSlices(u8, &.{
        230, 117, 27,  127, 210, 224, 145, 185, 157,
        99,  172, 7,   132, 30,  241, 130, 136, 166,
        99,  99,  197, 198, 25,  204, 119, 97,  238,
        129, 229, 172, 191, 5,
    }, &hash);
}

test "single input big endian" {
    const input: [32]u8 = .{1} ** 32;
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        5,   191, 172, 229, 129, 238, 97,  119, 204, 25,
        198, 197, 99,  99,  166, 136, 130, 241, 30,  132,
        7,   172, 99,  157, 185, 145, 224, 210, 127, 27,
        117, 230,
    }, &hash);
}

test "two input big endian" {
    const input: [64]u8 = .{1} ** 32 ++ .{2} ** 32;
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        13,  84,  225, 147, 143, 138, 140, 28,  125, 235, 94, 3,  85,
        242, 99,  25,  32,  123, 132, 254, 156, 162, 206, 27, 38, 231,
        53,  200, 41,  130, 25,  144,
    }, &hash);
}

test "two input 2" {
    const input: [64]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        0,   122, 243, 70,  226, 211, 4,   39,  158, 121, 224,
        169, 243, 2,   63,  119, 18,  148, 167, 138, 203, 112,
        231, 63,  144, 175, 226, 124, 173, 64,  30,  129,
    }, &hash);
}

test "two input 3" {
    const input: [64]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    var hasher = Hasher.init(.big);
    try hasher.append(input[0..32]);
    try hasher.append(input[32..64]);
    const hash = try hasher.finish();

    try expectEqualSlices(u8, &.{
        0,   122, 243, 70,  226, 211, 4,   39,  158, 121, 224,
        169, 243, 2,   63,  119, 18,  148, 167, 138, 203, 112,
        231, 63,  144, 175, 226, 124, 173, 64,  30,  129,
    }, &hash);
}

test "two input 4" {
    const input: [64]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .little);

    try expectEqualSlices(u8, &.{
        63,  147, 84,  28,  199, 24,  211, 148, 251,
        216, 239, 126, 31,  29,  178, 151, 216, 111,
        3,   250, 57,  177, 193, 144, 117, 9,   175,
        19,  155, 109, 68,  2,
    }, &hash);
}

test "3 inputs" {
    const input: [96]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        2,   192, 6,   110, 16,  167, 42,  189, 43, 51, 195, 178,
        20,  203, 62,  129, 188, 177, 182, 227, 9,  97, 205, 35,
        194, 2,   177, 134, 115, 191, 37,  67,
    }, &hash);
}

test "4 inputs" {
    const input: [128]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        8,   44,  156, 55,  10,  13,  36, 244, 65,
        111, 188, 65,  74,  55,  104, 31, 120, 68,
        45,  39,  216, 99,  133, 153, 28, 23,  214,
        252, 12,  75,  125, 113,
    }, &hash);
}

test "5 inputs" {
    const input: [160]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        16,  56,  150, 5,   174, 104, 141, 79,  20,  219, 133,
        49,  34,  196, 125, 102, 168, 3,   199, 43,  65,  88,
        156, 177, 191, 134, 135, 65,  178, 6,   185, 187,
    }, &hash);
}

test "6 inputs" {
    const input: [192]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        42,  115, 246, 121, 50,  140, 62,  171, 114, 74,  163,
        229, 189, 191, 80,  179, 144, 53,  215, 114, 159, 19,
        91,  151, 9,   137, 15,  133, 197, 220, 94,  118,
    }, &hash);
}

test "7 inputs" {
    const input: [224]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    };

    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        34,  118, 49,  10,  167, 243, 52,  58,  40,  66,
        20,  19,  157, 157, 169, 89,  190, 42,  49,  178,
        199, 8,   165, 248, 25,  84,  178, 101, 229, 58,
        48,  184,
    }, &hash);
}

test "8 inputs" {
    const input: [256]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1,
    };

    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        23,  126, 20,  83, 196, 70, 225, 176, 125, 43, 66, 51,
        66,  81,  71,  9,  92,  79, 202, 187, 35,  61, 35, 11,
        109, 70,  162, 20, 217, 91, 40,  132,
    }, &hash);
}

test "9 inputs" {
    const input: [288]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1,
    };

    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        14,  143, 238, 47, 228, 157, 163, 15,  222, 235, 72,
        196, 46,  187, 68, 204, 110, 231, 5,   95,  97,  251,
        202, 94,  49,  59, 138, 95,  202, 131, 76,  71,
    }, &hash);
}

test "10 inputs" {
    const input: [320]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        46, 196, 198, 94,  99,  120, 171, 140, 115, 48,  133, 79,
        74, 112, 119, 193, 255, 146, 96,  228, 72,  133, 196, 184,
        29, 209, 49,  173, 58,  134, 205, 150,
    }, &hash);
}

test "11 inputs" {
    const input: [352]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    };
    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        0,   113, 61,  65, 236, 166, 53,  241, 23,  212, 236,
        188, 235, 95,  58, 102, 220, 65,  66,  235, 112, 181,
        103, 101, 188, 53, 143, 27,  236, 64,  187, 155,
    }, &hash);
}

test "12 inputs" {
    const input: [384]u8 = .{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1,
    };

    const hash = try Hasher.hash(&input, .big);

    try expectEqualSlices(u8, &.{
        20,  57,  11,  224, 186, 239, 36,  155, 212, 124, 101, 221,
        172, 101, 194, 229, 46,  133, 19,  192, 129, 193, 205, 114,
        201, 128, 6,   9,   142, 154, 143, 190,
    }, &hash);
}

test "chain" {
    const chain: []const [32]u8 = &.{
        .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 0 },
        .{ 20, 163, 229, 120, 146, 206, 105, 118, 12, 185, 174, 172, 18, 100, 185, 59, 193, 178, 207, 35, 150, 88, 47, 161, 121, 171, 69, 207, 202, 209, 26, 86 },
        .{ 40, 108, 204, 142, 32, 195, 146, 117, 251, 9, 135, 75, 18, 92, 4, 237, 239, 166, 159, 252, 220, 133, 240, 159, 218, 87, 204, 192, 81, 123, 226, 159 },
        .{ 48, 89, 179, 159, 107, 189, 239, 94, 116, 138, 142, 77, 41, 203, 181, 87, 157, 205, 12, 227, 136, 215, 182, 103, 100, 203, 86, 30, 122, 172, 202, 240 },
        .{ 35, 73, 234, 64, 67, 202, 91, 192, 158, 100, 95, 50, 115, 226, 80, 48, 83, 103, 209, 72, 142, 189, 157, 78, 106, 139, 255, 212, 252, 25, 130, 105 },
        .{ 39, 198, 4, 121, 230, 134, 48, 224, 44, 26, 182, 143, 172, 28, 165, 31, 191, 145, 56, 87, 94, 33, 66, 234, 239, 0, 96, 224, 203, 199, 196, 230 },
        .{ 17, 82, 17, 41, 167, 54, 195, 182, 137, 177, 240, 198, 232, 8, 87, 32, 137, 69, 251, 1, 85, 254, 121, 36, 251, 226, 251, 141, 121, 59, 167, 129 },
        .{ 36, 199, 19, 131, 71, 199, 84, 244, 171, 213, 58, 48, 26, 152, 164, 244, 159, 206, 193, 113, 157, 18, 9, 164, 39, 119, 121, 188, 103, 164, 170, 145 },
        .{ 41, 215, 208, 65, 207, 92, 174, 185, 232, 218, 5, 168, 78, 213, 93, 120, 235, 46, 196, 48, 136, 185, 145, 217, 190, 215, 161, 184, 133, 198, 160, 245 },
        .{ 0, 26, 155, 86, 121, 32, 236, 65, 43, 96, 120, 205, 252, 174, 59, 8, 159, 188, 3, 113, 152, 68, 230, 116, 159, 99, 134, 187, 47, 179, 159, 40 },
        .{ 46, 230, 246, 41, 34, 220, 147, 171, 66, 196, 172, 119, 251, 35, 134, 15, 35, 90, 91, 208, 168, 19, 60, 248, 66, 240, 0, 206, 53, 93, 17, 115 },
        .{ 18, 22, 234, 76, 2, 225, 173, 143, 0, 39, 139, 236, 42, 128, 234, 128, 244, 72, 1, 68, 64, 192, 221, 230, 164, 16, 118, 44, 19, 65, 102, 137 },
        .{ 0, 247, 64, 132, 214, 155, 184, 99, 12, 158, 157, 3, 45, 38, 237, 15, 105, 93, 120, 26, 105, 135, 255, 61, 73, 227, 43, 105, 253, 139, 250, 223 },
    };

    for (0..chain.len - 1, 1..) |i, j| {
        const input = std.mem.sliceAsBytes(chain[0 .. i + 1]);
        const next = chain[j];
        const hash = try Hasher.hash(input, .big);
        try expectEqualSlices(u8, &next, &hash);
    }

    var hasher = Hasher.init(.big);
    for (chain[0..12]) |item| {
        try hasher.append(&item);
    }
    const result = try hasher.finish();
    try expectEqualSlices(u8, &chain[12], &result);
}

test "non-32 byte aligned length" {
    const input: [21]u8 = .{1} ++ .{0} ** 20;
    try std.testing.expectError(
        error.InputNotMultipleOf32,
        Hasher.hash(&input, .big),
    );
}
