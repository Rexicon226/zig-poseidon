# zig-poseidon

zig-poseidon is an implementation of the [Poseidon hash](https://eprint.iacr.org/2019/458).

## What is it?

Poseidon hash was made for zero-knowledge hashing. It's useful for commitments and Merkle trees and is generally faster than Pedersen hash. According to the original paper, it can also be used in signature schemes.

## Security 

**PLEASE NOTE**: This library is **un-audited** and largely unproven by anyone other than myself. 

Please don't use it in any production environment!!

As the author of [Sig's](https://github.com/Syndica/sig) SVM, where Poseidon hash is a syscall provided to on-chain programs, I hope we'll get an official audit of this library soon.

## Parameters

The current implementation of the library works with pre-generated parameters over the BN254 curve. I plan to expand to support most, if not all, of the parameters suggested by the original creators.

The parameters included right now are:
- `x^5` S-Boxes
- `width - 2 <= T <= 13`
- `inputs - 1 <= N <= 12`
- 8 full rounds
- The number of partial rounds depends on `T`

I plan to finish porting over the original Sage script for generating the round constants, and you'll be able to specify which constants you want to be generated at build time.

## API

The API of this library is very simple and inflexible at the moment. Due to some security concerns, I'm not currently planning on allowing variable-sized inputs. This means that the inputs to the `hash` function must be a multiple of 32 or else an error will be returned.

The API itself has two different modes, what you could call "streaming" mode, and a one-shot API.

One-shot example:
```zig
const Hasher = @import("poseidon").Hasher;

const input: [32]u8 = .{1} ** 32;
const result: [32]u8 = try Hasher.hash(&input, .big);
```

"Streaming" example:
```zig
const Hasher = @import("poseidon").Hasher;

const input1: [32]u8 = .{1} ** 32;
const input2: [32]u8 = .{2} ** 32;

var hasher = Hasher.init(.big);
try hasher.append(&input1);
try hasher.append(&input2);
const result: [32]u8 = try hasher.finish();
```

As you can see, both approaches take in an endianness configuration.

### Implementations

I took direct "inspiration" from [Light Poseidon](https://github.com/Lightprotocol/light-poseidon?tab=readme-ov-file#implementation) for this section, as I feel it's helpful to users of such libraries since the authors of the hash say you can fiddle with the round constants a bit, making different implementations potentially incompatible.

The library is compatible with:
- [light-poseidon](https://github.com/Lightprotocol/light-poseidon)
- [Firedancer's implementation](https://github.com/firedancer-io/firedancer/tree/39fbaa898c4b99b64d452ae3cadb3ee2a6db7269/src/ballet/bn254)
- [original SageMath implementation](https://extgit.iaik.tugraz.at/krypto/hadeshash/-/tree/master/)

And others as well.

### Performance

The library currently takes advantage of Zig's native big integer types, such as `u256` and `u512` for the computations. Unfortunately, LLVM is not very good at legalizing some operations which negatively impacts the performance. In the future, I'm very eager to manually handle the limbs and test out different advanced strategies for doing fast Montgomery operations. I've found [this](https://baincapitalcrypto.com/optimizing-montgomery-multiplication-in-webassembly/) article to be particularly inspiring on the different ways available.

Here are the current benchmarks for the library, taken on an Apple M3 MBP. I will replace them with a benchmark from a Ryzen 7950X3D desktop when I have the chance (may forget forever).
```
Benchmarking poseidon_bn254_x5_1: 10 us / iterations ; 336 ns / byte
Benchmarking poseidon_bn254_x5_2: 14 us / iterations ; 221 ns / byte
Benchmarking poseidon_bn254_x5_3: 21 us / iterations ; 224 ns / byte
Benchmarking poseidon_bn254_x5_4: 32 us / iterations ; 257 ns / byte
Benchmarking poseidon_bn254_x5_5: 45 us / iterations ; 283 ns / byte
Benchmarking poseidon_bn254_x5_6: 64 us / iterations ; 334 ns / byte
Benchmarking poseidon_bn254_x5_7: 81 us / iterations ; 363 ns / byte
Benchmarking poseidon_bn254_x5_8: 100 us / iterations ; 390 ns / byte
Benchmarking poseidon_bn254_x5_9: 116 us / iterations ; 402 ns / byte
Benchmarking poseidon_bn254_x5_10: 150 us / iterations ; 470 ns / byte
Benchmarking poseidon_bn254_x5_11: 164 us / iterations ; 467 ns / byte
Benchmarking poseidon_bn254_x5_12: 205 us / iterations ; 535 ns / byte
```

TLDR; it is a bit worse than `light-poseidon` with a hint of LLVM's optimizer failing to remove easy stack usages. Much to experiment with, and much to improve on.
