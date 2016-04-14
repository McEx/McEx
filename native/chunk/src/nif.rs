#![feature(plugin)]
#![plugin(rustler_codegen)]

use std::io::Cursor;
use std::mem;

extern crate byteorder;
use byteorder::{BigEndian, ReadBytesExt, WriteBytesExt};

#[macro_use]
extern crate rustler;
use rustler::{ NifEnv, NifTerm, NifResult, NifEncoder, NifDecoder };
use rustler::binary::{NifBinary, OwnedNifBinary};
use rustler::resource::ResourceCell;
use rustler::atom::{get_atom, init_atom};

rustler_export_nifs!(
    "Elixir.McChunk.Native",
    [("n_new", 1, new),
     ("n_decode", 2, decode),
     ("n_encode", 1, encode),
     ("n_get", 3, get),
     ("n_set", 4, set)],
    Some(on_load)
);

fn on_load(env: &NifEnv, _load_info: NifTerm) -> bool {
    resource_struct_init!(BitArray, env);
    init_atom("ok");
    true
}

#[NifResource]
struct BitArray {
    size: usize,
    data: Vec<u64>,
}

impl BitArray {
    fn new(size: usize) -> Self {
        let mut data = Vec::with_capacity(size);
        for _ in 0..size {
            data.push(0);
        }
        BitArray {
            size: size,
            data: data,
        }
    }

    fn size(&self) -> usize {
        self.size
    }
    fn byte_size(&self) -> usize {
        self.size * mem::size_of::<u64>()
    }

    fn encode(&self, out: &mut [u8]) {
        let mut wtr = Cursor::new(out);
        for val in &self.data {
            wtr.write_u64::<BigEndian>(*val).unwrap();
        }
    }

    fn decode(input: &[u8], len: usize) -> Self {
        let mut rdr = Cursor::new(input);
        let mut res = BitArray::new(len);
        for pos in 0..len {
            res.data[pos] = rdr.read_u64::<BigEndian>().unwrap();
        }
        res
    }

    fn get(&self, bbits: u8, index: u32) -> u64 {
        let max_value = (1 << bbits) - 1;
        let bbits_32 = bbits as u32;
        let start_long = (index * bbits_32) / 64;
        let start_offset = (index * bbits_32) % 64;
        let end_long = ((index + 1) *  bbits_32 - 1) / 64;

        let start_val = self.data[start_long as usize] >> start_offset;

        let res = if start_long == end_long {
            start_val
        } else {
            let end_offset = 64 - start_offset;
            let end_val = self.data[end_long as usize] << end_offset;

            start_val | end_val
        };
        res & max_value
    }

    fn set(&mut self, bbits: u8, index: u32, value: u64) {
        let max_value = (1 << bbits) - 1;
        let bbits_32 = bbits as u32;
        let start_long = (index * bbits_32) / 64;
        let start_offset = (index * bbits_32) % 64;
        let end_long = ((index + 1) *  bbits_32 - 1) / 64;

        let start_val_a = self.data[start_long as usize] & !(max_value << start_offset);
        let start_val_b = (value & max_value) << start_offset;
        self.data[start_long as usize] = start_val_a | start_val_b;

        if start_long != end_long {
            let end_offset = 64 - start_offset;
            let j1 = bbits_32 - end_offset;
            let end_val_a = self.data[end_long as usize] >> j1 << j1;
            let end_val_b = (value & max_value) >> end_offset;

            self.data[end_long as usize] = end_val_a | end_val_b;
        }
    }
}

fn new<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> NifResult<NifTerm<'a>> {
    let size: u32 = try!(NifDecoder::decode(args[0]));
    let holder = ResourceCell::new(BitArray::new(size as usize));
    Ok(holder.encode(env))
}

fn decode<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> NifResult<NifTerm<'a>> {
    let bin: NifBinary = try!(NifDecoder::decode(args[0]));
    let size: u32 = try!(NifDecoder::decode(args[1]));

    let res = BitArray::decode(bin.as_slice(), size as usize);
    let holder = ResourceCell::new(res);

    Ok(holder.encode(env))
}

fn encode<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> NifResult<NifTerm<'a>> {
    let holder: ResourceCell<BitArray> = try!(NifDecoder::decode(args[0]));
    let ba = holder.read().ok().unwrap();

    let mut bin = OwnedNifBinary::alloc(ba.byte_size()).unwrap();
    ba.encode(bin.as_mut_slice());

    Ok(bin.release(env).get_term(env))
}

fn get<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> NifResult<NifTerm<'a>> {
    let holder: ResourceCell<BitArray> = try!(NifDecoder::decode(args[0]));
    let ba = holder.read().ok().unwrap();
    let bbits: u8 = try!(NifDecoder::decode(args[1]));
    let index: u32 = try!(NifDecoder::decode(args[2]));

    let res = ba.get(bbits, index);

    Ok(res.encode(env))
}

fn set<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> NifResult<NifTerm<'a>> {
    let holder: ResourceCell<BitArray> = try!(NifDecoder::decode(args[0]));
    let mut ba = holder.write().ok().unwrap();
    let bbits: u8 = try!(NifDecoder::decode(args[1]));
    let index: u32 = try!(NifDecoder::decode(args[2]));
    let val: u64 = try!(NifDecoder::decode(args[3]));

    ba.set(bbits, index, val);

    Ok(get_atom("ok").unwrap().to_term(env))
}
