#[macro_use]
extern crate ruster_unsafe;
use ruster_unsafe::*;

#[macro_use]
pub mod nif;

mod chunk_data;
use chunk_data::{ Chunk };

nif_init!(b"Elixir.McEx.Native.Chunk\0", Some(load), None, None, None,
        nif!(b"n_create\0", 1, create));

static mut atom_ok:ERL_NIF_TERM = 0 as ERL_NIF_TERM;
//static mut res_type: *mut nif::ErlNifResourceType = 0 as *mut _;
//static mut t_res: nif::NifStructResourceType<Chunk> = unsafe { mem::uninitialized() };
static mut t_res: Option<nif::NifStructResourceType<Chunk>> = None;

extern "C" fn load(env: *mut ErlNifEnv, 
                   _priv_data: *mut *mut c_void, 
                   _load_info: ERL_NIF_TERM) -> c_int {
    let n_env = nif::NifEnv { env: env };
    unsafe {
        //res_type = nif::open_resource_type(&n_env, "", "Chunk", nif::ErlNifResourceFlags::ERL_NIF_RT_CREATE).unwrap() 
        //    as *mut nif::ErlNifResourceType;
        let t = nif::open_struct_resource_type::<Chunk>(&n_env, "", "Chunk", 
                                                        nif::ErlNifResourceFlags::ERL_NIF_RT_CREATE).unwrap();
        t_res = Some(t);
        atom_ok = enif_make_atom(env, b"ok\0" as *const u8);
        //enif_open_resource_type(env, 
        //                        b"Elixir.McEx.Native.Chunk\0" as *const u8, 
        //                        b"Chunk\0" as *const u8, 
        //                        None, 
        //                        ErlNifResourceFlags::ERL_NIF_RT_CREATE,
        //                        None)
    }
    0
}

nif_func!(create, |env, args| {
    //let data: &mut Chunk = nif::alloc_resource::<Chunk>(unsafe { &mut *res_type });
    
    let (t1, t2) = try!(decode_tuple!(env, args[0], (i64, i64)));
    println!("t1: {}, t2: {}", t1, t2);
    
    let chunk_res_type_opt = unsafe { &t_res };
    let chunk_res_type: &nif::NifStructResourceType<Chunk> = chunk_res_type_opt.as_ref().unwrap();

    let (res, term) = nif::alloc_struct_resource::<Chunk>(env, chunk_res_type);
    Ok(term)
    //nif::NifTerm::new(env, args[0]);
    //Ok(nif::NifEncoder::encode(12, env))
    //Ok(nif::nif_atom(env, "ok"))
    //Err(nif::NifError::BadArg)
});

//nif_func!(assemble_packet, |env, args| {
//    
//});

//extern "C" fn create(_env: *mut ErlNifEnv,
//                     _argc: c_int,
//                     _args: *const ERL_NIF_TERM) -> ERL_NIF_TERM {
//    unsafe { atom_ok }
//
//    //let res = unsafe { enif_alloc_resource(
//}
