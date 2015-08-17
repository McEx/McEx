extern crate ruster_unsafe;
pub use self::ruster_unsafe::{ ERL_NIF_TERM, ErlNifResourceFlags, ErlNifResourceType };

extern crate libc;
pub use self::libc::{ c_char, size_t, c_int, c_uint, c_void };

extern crate std;
use std::ffi::CString;
use std::mem;
use std::marker::PhantomData;


pub struct NifEnv {
    pub env: *mut ruster_unsafe::ErlNifEnv,
}

#[derive(Clone, Copy)]
pub enum NifError {
    BadArg,
    Atom(&'static str),
}

#[derive(Clone, Copy)]
pub struct NifTerm<'a> {
    pub term: ERL_NIF_TERM,
    env_life: PhantomData<&'a NifEnv>,
}
impl<'a> NifTerm<'a> {
    pub fn new(env: &'a NifEnv, inner: ERL_NIF_TERM) -> Self {
        NifTerm {
            term: inner,
            env_life: PhantomData
        }
    }
}

pub struct NifResourceType {
    pub res: *mut ErlNifResourceType
}
pub struct NifStructResourceType<T> {
    pub res: NifResourceType,
    pub struct_type: PhantomData<T>,
}

// Atoms are a special case of a term. They can be stored and used on all envs regardless of where
// it lives and when it is created.
#[derive(PartialEq, Eq)]
pub struct NifAtom {
    term: ERL_NIF_TERM,
}

#[repr(C)]
pub struct NifBinary {
    size: c_int,
    dat: *mut u8,
    owned: bool,
}

pub trait NifEncoder {
    fn encode<'a>(self, env: &'a NifEnv) -> NifTerm<'a>;
}
pub trait NifDecoder {
    fn decode<'a>(term: NifTerm, env: &'a NifEnv) -> Result<Self, NifError>;
}

macro_rules! impl_number_transcoder {
    ($typ:ty, $encode_fun:ident, $decode_fun:ident) => {
        impl NifEncoder for $typ {
            fn encode<'a>(self, env: &'a NifEnv) -> NifTerm<'a> {
                #![allow(unused_unsafe)]
                NifTerm::new(env, unsafe { ruster_unsafe::$encode_fun(env.env, self) })
            }
        }
        impl NifDecoder for $typ {
            fn decode<'a>(term: NifTerm, env: &'a NifEnv) -> Result<$typ, NifError> {
                #![allow(unused_unsafe)]
                let mut res: $typ = Default::default();
                if unsafe { ruster_unsafe::$decode_fun(env.env, term.term, (&mut res) as *mut $typ) } == 0 {
                    return Err(NifError::BadArg);
                }
                Ok(res)
            }
        }
    }
}

impl_number_transcoder!(libc::c_int, enif_make_int, enif_get_int);
impl_number_transcoder!(libc::c_uint, enif_make_uint, enif_get_uint);
impl_number_transcoder!(u64, enif_make_uint64, enif_get_uint64);
impl_number_transcoder!(i64, enif_make_int64, enif_get_int64);
impl_number_transcoder!(libc::c_double, enif_make_double, enif_get_double);
//impl_number_encoder!(libc::c_long, enif_make_long);
//impl_number_encoder!(libc::c_ulong, enif_make_ulong);

// Start erlang spesific implementations //

// This is problematic, erlang uses Latin1 while rust uses UTF-8. Everything will work for basic
// ascii characters. God knows what happens if it's not. I hope it's not. Please don't.
//impl<'a> NifEncoder for &'a str {
//    fn encode<'b>(self, env: &'b NifEnv) -> NifTerm<'b> {
//        NifTerm::new(env, unsafe {
//            ruster_unsafe::enif_make_string_len(env.env, 
//                                                self.as_ptr() as *const u8,
//                                                self.len() as size_t,
//                                                ruster_unsafe::ErlNifCharEncoding::ERL_NIF_LATIN1)
//        })
//    }
//}
//impl NifDecoder for String {
//    fn decode<'a>(term: NifTerm, env: &'a NifEnv) -> Result<String, NifError> {
//        let mut length: c_uint = 0;
//        if unsafe { ruster_unsafe::enif_get_list_length(env.env, term.term, &mut length as *mut c_uint) } == 0 {
//            return Err(NifError::BadArg);
//        }
//        let buf: Vec<u8> = Vec::with_capacity(length as usize);
//        ruster_unsafe::enif_get_string(env.env, term.term, buf.as_mut_ptr(), buf.len() as c_uint, 
//                                       ruster_unsafe::ErlNifCharEncoding::ERL_NIF_LATIN1);
//        CString::new(buf)
//    }
//}

// End erlang spesific implementations //

// Resources
pub fn open_resource_type_raw(env: &NifEnv, module: &str, name: &str, 
                         flags: ErlNifResourceFlags) -> Result<NifResourceType, &'static str> {
    let module_p = CString::new(module).unwrap().as_bytes_with_nul().as_ptr();
    let name_p = CString::new(name).unwrap().as_bytes_with_nul().as_ptr();
    unsafe {
        let mut tried: ErlNifResourceFlags = mem::uninitialized();
        let res = ruster_unsafe::enif_open_resource_type(env.env, module_p, name_p, None, flags, 
                                                         (&mut tried as *mut ErlNifResourceFlags));
        if !res.is_null() {
            return Ok(NifResourceType { res: res });
        }
    }
    Err("Error when opening resource type")
}
pub unsafe fn alloc_resource_raw(res_type: &NifResourceType, size: usize) -> *mut c_void {
    ruster_unsafe::enif_alloc_resource((res_type.res as *mut ErlNifResourceType), size as size_t)
}
// End Resources

// Resource Structs
pub fn open_struct_resource_type<T>(env: &NifEnv, module: &str, name: &str,
                                 flags: ErlNifResourceFlags) -> Result<NifStructResourceType<T>, &'static str> {
    let res: NifResourceType = try!(open_resource_type_raw(env, module, name, flags));
    Ok(NifStructResourceType {
        res: res,
        struct_type: PhantomData,
    })
}
pub fn alloc_struct_resource<'a, T>(env: &'a NifEnv, res_type: &NifStructResourceType<T>) -> (&'a mut T, NifTerm<'a>) {
    let res = unsafe { 
        let buf: *mut c_void = alloc_resource_raw(&res_type.res, mem::size_of::<T>());
        &mut *(buf as *mut T)
    };
    let res_ptr = (res as *mut T) as *mut c_void;
    let term = NifTerm::new(env, unsafe { ruster_unsafe::enif_make_resource(env.env, res_ptr) });
    unsafe { ruster_unsafe::enif_release_resource(res_ptr) };
    (res, term)
}
pub fn get_struct_resource<'a, T>(env: &'a NifEnv, 
                                  res_type: &NifStructResourceType<T>, term: NifTerm)-> Result<&'a mut T, NifError> {
    let res: &mut T = unsafe { mem::uninitialized() };
    if unsafe { ruster_unsafe::enif_get_resource(env.env, term.term, res_type.res.res, 
                                     &mut ((res as *mut T) as *mut c_void) as *mut *mut c_void ) } == 0 {
        return Err(NifError::BadArg);
    }
    Ok(res)
}
// End Resource Structs

pub fn get_tuple<'a>(env: &'a NifEnv, term: NifTerm) -> Result<Vec<NifTerm<'a>>, NifError> {
    let mut arity: c_int = 0;
    let mut array_ptr: *const ERL_NIF_TERM = unsafe { mem::uninitialized() };
    let success = unsafe { ruster_unsafe::enif_get_tuple(env.env, term.term, 
                                                         &mut arity as *mut c_int, 
                                                         &mut array_ptr as *mut *const ERL_NIF_TERM) };
    if success == 0 {
        return Err(NifError::BadArg);
    }
    let term_array = unsafe { std::slice::from_raw_parts(array_ptr, arity as usize) };
    Ok(term_array.iter().map(|x| { NifTerm::new(env, *x) }).collect::<Vec<NifTerm>>())
}

pub fn decode_type<T: NifDecoder>(term: NifTerm, env: &NifEnv) -> Result<T, NifError> {
    NifDecoder::decode(term, env)
}

#[macro_export]
macro_rules! decode_tuple {
    (@count ()) => { 0 };
    (@count ($_i:ty, $($rest:tt)*)) => { 1 + decode_tuple!(@count ($($rest)*)) };
    (@accum $_env:expr, $_list:expr, $_num:expr, ($(,)*) -> ($($body:tt)*)) => {
        decode_tuple!(@as_expr ($($body)*))
    };
    (@accum $env:expr, $list:expr, $num:expr, ($head:ty, $($tail:tt)*) -> ($($body:tt)*)) => {
        decode_tuple!(@accum $env, $list, ($num+1), ($($tail)*) -> ($($body)* decode_tuple!(@decode_arg $env, $head, $list[$num]),))
    };
    (@as_expr $e:expr) => {$e};
    (@decode_arg $env:expr, $typ:ty, $val:expr) => {
        match $crate::nif::decode_type::<$typ>($val, $env) {
            Ok(val) => val,
            Err(val) => return Err(val),
        }
    };
    ($env:expr, $term:expr, ($($typs:ty),*)) => {
        {
            let num_expr: usize = decode_tuple!(@count ($($typs,)*));
            let terms = try!($crate::nif::get_tuple($env, $term));
            if terms.len() != num_expr {
                Err($crate::nif::NifError::BadArg)
            } else {
                Ok(decode_tuple!(@accum $env, terms, 0, ($($typs),*,) -> ()))
            }
        }
    }
}

//macro_rules! decode_tuple {
//    ($env:expr, $term:expr, ($($typ:ty),+)) => {
//        let num_expr: usize = count_typ!($($typ,)*);
//        let terms = try!($crate::nif::get_tuple($env, $term));
//        if terms.len() != num_expr {
//            Err($crate::nif::NifError::BadArg)
//        } else {
//            Ok((decode_tuple_arg!($env, terms, 0, ($($typ,)*))))
//        }
//    }
//}

#[macro_export]
macro_rules! nif_func {
    ($name:ident, $fun:expr) => (
        extern "C" fn $name(r_env: *mut ErlNifEnv,
                            argc: c_int,
                            argv: *const ERL_NIF_TERM) -> ERL_NIF_TERM {
            use $crate::nif::{ NifEnv, NifTerm, NifError, size_t };
            let env = NifEnv { env: r_env };
            let terms = unsafe { std::slice::from_raw_parts(argv, argc as usize) }.iter()
                .map(|x| { NifTerm::new(&env, *x) }).collect::<Vec<NifTerm>>();
            let inner_fun: &for<'a> Fn(&'a NifEnv, &Vec<NifTerm>) -> Result<NifTerm<'a>, NifError> = &$fun;
            let res: Result<NifTerm, NifError> = inner_fun(&env, &terms);
            match res {
                Ok(ret) => ret.term,
                Err(NifError::BadArg) => 
                    unsafe { ruster_unsafe::enif_make_badarg(r_env) },
                Err(NifError::Atom(name)) => 
                    unsafe { ruster_unsafe::enif_make_atom_len(r_env, 
                                                               name.as_ptr() as *const u8, 
                                                               name.len() as size_t) },
            }
        });
}

#[macro_export]
macro_rules! nif_atom {
    ($env:expr, $name:ident) => ({
        const atom_name: &'static str = stringify!($name);
        ruster_unsafe::enif_make_atom_len(
            $env.env,
            atom_name.as_ptr() as *const u8,
            atom_name.len() as $crate::nif::size_t)
    });
}

pub fn nif_atom<'a>(env: &'a NifEnv, name: &str) -> NifTerm<'a> {
    unsafe { 
        NifTerm::new(env, ruster_unsafe::enif_make_atom_len(
            env.env,
            name.as_ptr() as *const u8,
            name.len() as size_t))
    }
}
