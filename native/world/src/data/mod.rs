#![allow(dead_code)]

extern crate byteorder;

pub const CHUNK_SECTION_HEIGHT: usize = 16;
pub const MAX_BITMASK: u16 = ((1u32 << CHUNK_SECTION_HEIGHT) - 1) as u16;
pub const SECTION_SIZE: usize = 16;
pub const BIOME_BUF_LEN: usize = SECTION_SIZE * SECTION_SIZE;
pub const SECTION_BUF_LEN: usize = BIOME_BUF_LEN * SECTION_SIZE;

pub mod block;
pub mod chunk_section;
pub mod chunk;

pub use self::block::{ BlockData };
pub use self::chunk_section::{ ChunkSection };
pub use self::chunk::{ Chunk };
