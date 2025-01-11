//! A script used in conformance testing with light-poseidon.

use std::process::abort;
use {
    ark_bn254::Fr,
    light_poseidon::{Poseidon, PoseidonBytesHasher, PoseidonError},
    std::env::args,
};

#[repr(transparent)]
pub struct PoseidonHash(pub [u8; 32]);

fn main() {
    let args = args();
    let mut input: Vec<u8> = vec![];
    args.skip(1)
        .for_each(|arg| input.push(arg.parse().unwrap()));
    if input.len() % 32 != 0 {
        panic!("wrong input size");
    }

    let batched: Vec<&[u8]> = input.chunks(32).collect();
    let result = hash(&batched).unwrap_or_else(|_| {
        println!("error");
        abort()
    });
    println!("result: {:?}", result.0);
}

fn hash(vals: &[&[u8]]) -> Result<PoseidonHash, PoseidonError> {
    let mut hasher = Poseidon::<Fr>::new_circom(vals.len())?;
    let res = hasher.hash_bytes_le(vals)?;
    return Ok(PoseidonHash(res));
}

