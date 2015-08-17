#[macro_use]
extern crate ruster_unsafe;
use ruster_unsafe::*;

#[macro_use]
pub mod nif;

mod chunk_data;
use chunk_data::{ Chunk };

nif_init!(b"Elixir.McEx.Native.Chunk\0", Some(load), None, None, None,
        nif!(b"n_create\0", 1, create));

//static mut atom_ok:ERL_NIF_TERM = 0 as ERL_NIF_TERM;
//static mut res_type: *mut nif::ErlNifResourceType = 0 as *mut _;
//static mut t_res: nif::NifStructResourceType<Chunk> = unsafe { mem::uninitialized() };
static mut chunk_resource_type: Option<nif::NifStructResourceType<Chunk>> = None;

extern "C" fn load(env: *mut ErlNifEnv, 
                   _priv_data: *mut *mut c_void, 
                   _load_info: ERL_NIF_TERM) -> c_int {
    let n_env = nif::NifEnv { env: env };
    unsafe {
        chunk_resource_type = Some(
            nif::open_struct_resource_type::<Chunk>(&n_env, "", "Chunk",
                                                    nif::ErlNifResourceFlags::ERL_NIF_RT_CREATE).unwrap());
        //atom_ok = enif_make_atom(env, b"ok\0" as *const u8);
    }
    0
}

nif_func!(create, |env, args| {
    //let data: &mut Chunk = nif::alloc_resource::<Chunk>(unsafe { &mut *res_type });
    
    let (t1, t2) = try!(decode_tuple!(env, args[0], (i64, i64)));
    println!("t1: {}, t2: {}", t1, t2);
    
    let chunk_res_type = unsafe { &chunk_resource_type }.as_ref().unwrap();

    let (res, term) = nif::alloc_struct_resource::<Chunk>(env, chunk_res_type);
    Ok(term)
});

nif_func!(assemble_packet, |env, args| {
    let chunk_res_type = unsafe { &chunk_resource_type }.as_ref().unwrap();
    let chunk: &mut Chunk = try!(nif::get_struct_resource(env, chunk_res_type, args[0]));
    Ok(nif::nif_atom(env, "ok"))
});
