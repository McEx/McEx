//#![feature(trace_macros)]
//trace_macros!(true);

#![feature(plugin)]
#![plugin(rustler_codegen)]

//#[macro_use(nif_init, nif_init_func, nif_func, nif_func_args, decode_tuple, decode_term_array_to_tuple)]
extern crate rustler;
use rustler::{NifTerm, NifEnv, NifError};
use rustler::{ NifEncoder, NifDecoder };
use rustler::resource::ResourceTypeHolder;
use rustler::binary::{OwnedNifBinary, NifBinary};

//mod chunk_data;
//use chunk_data::{ Chunk, BlockData };
mod data;
use data::{ Chunk, BlockData };

extern crate opensimplex;
use opensimplex::OsnContext;

extern crate libc;
use libc::{ c_int, c_void };

rustler_export_nifs!("Elixir.McEx.Native.Chunk", 
                     [("n_create", 0, create),
                      ("n_assemble_packet", 2, assemble_packet),
                      ("n_generate_chunk", 2, generate_chunk)],
                     Some(on_load));

fn on_load(env: &NifEnv, load_info: NifTerm) -> bool {
    resource_struct_init!(Chunk, env);
    true
}

fn create<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> Result<NifTerm<'a>, NifError> {
    let holder = ResourceTypeHolder::new(env, Chunk::default());
    holder.write().unwrap().set_block(0, 100, 0, BlockData::new(1, 1));
    Ok(holder.encode(env))
}

extern crate time;

#[NifTuple] struct PacketAssemblyParams { skylight: bool, entire_chunk: bool, bitmask: u32 }
#[NifTuple] struct PacketAssemblyResponse<'a> { written_bitmask: u32, size: u32, chunk_data: NifTerm<'a> }
fn assemble_packet<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> Result<NifTerm<'a>, NifError> {
    let holder: ResourceTypeHolder<Chunk> = try!(NifDecoder::decode(args[0], env));
    let params: PacketAssemblyParams = try!(NifDecoder::decode(args[1], env));

    let mut_chunk = holder.write().unwrap();
    let transmit_size = mut_chunk.get_transmit_size(params.skylight, params.entire_chunk, params.bitmask as u16);

    let mut binary = OwnedNifBinary::alloc(transmit_size).unwrap();
    let (written_bitmask, size) = mut_chunk.write_transmit_data(params.skylight, params.entire_chunk, 
                                                             params.bitmask as u16, binary.as_mut_slice());

    let binary_fin = binary.release(env);

    Ok(PacketAssemblyResponse { written_bitmask: written_bitmask as u32, size: size, chunk_data: binary_fin.get_term(env) }.encode(env))
}

#[NifTuple] struct ChunkPos { x: i32, z: i32 }
fn generate_chunk<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> Result<NifTerm<'a>, NifError> {
    let holder: ResourceTypeHolder<Chunk> = try!(NifDecoder::decode(args[0], env));
    let chunk_pos: ChunkPos = try!(NifDecoder::decode(args[1], env));

    let noise = OsnContext::new(1).unwrap();
    let mut mut_chunk = holder.write().unwrap();

    let c_x = chunk_pos.x as f64 * 2.0;
    let c_z = chunk_pos.z as f64 * 2.0;

    for y in 0..64 {
        let baseline_ref = (((y as f64) / 64.0) * 2.0) - 1.0;
        for x in 0..16 {
            for z in 0..16 {
                if noise.noise3(c_x + ((x as f64) / 8.0), (y as f64) / 8.0, c_z + (z as f64) / 8.0) > baseline_ref {
                    mut_chunk.set_block(x, y, z, BlockData::new(2, 0));
                }
            }
        }
    }

    Ok(15.encode(env))
}

/*#[NifTuple] struct BlockPos { x: u32, y: u32, z: u32 }
fn set_block<'a>(env: &'a NifEnv, args: &Vec<NifTerm>) -> Result<NifTerm<'a>, NifError> {
    let holder: ResourceTypeHolder<Chunk> = try!(NifDecoder::decode(args[0], env));
    let pos: BlockPos = try!(NifDecoder::decode(args[1], env));
    let val: u32 = try!(NifDecoder::decode(args[2], env));

    holder.write().unwrap().set_block(pos.x, pos.y, pos.y, BlockData::new_raw(val as u16));


}*/
