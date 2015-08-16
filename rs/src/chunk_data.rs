#![allow(dead_code)]
extern crate byteorder;
use self::byteorder::{LittleEndian, WriteBytesExt};

const CHUNK_SECTION_HEIGHT: usize = 16;
const MAX_BITMASK: u16 = ((1u32 << CHUNK_SECTION_HEIGHT) - 1) as u16;
const SECTION_SIZE: usize = 16;
const BIOME_BUF_LEN: usize = SECTION_SIZE * SECTION_SIZE;
const SECTION_BUF_LEN: usize = BIOME_BUF_LEN * SECTION_SIZE;

struct ChunkSection {
    block_data: [BlockData; SECTION_BUF_LEN], // 2 bytes per block
    block_light: [u8; SECTION_BUF_LEN / 2], // 1/2 byte per block
    skylight: [u8; SECTION_BUF_LEN / 2], // 1/2 byte per block
    count: u16,
}

pub struct Chunk {
    sections: [ChunkSection; CHUNK_SECTION_HEIGHT],
    biome: [u8; BIOME_BUF_LEN], // 1 byte per block column
}

#[derive(Copy, Clone)]
pub struct BlockData {
    value: u16,
}
impl BlockData {
    fn new(id: u16, meta: u8) -> BlockData {
        BlockData {
            value: (id << 4) | (meta as u16 & 15),
        }
    }
    fn get_value(&self) -> &u16 {
        &self.value
    }
    fn set_value_raw(&mut self, value: u16) {
        self.value = value;
    }
    fn set_value(&mut self, id: u16, meta: u8) {
        self.set_value_raw((id << 4) | (meta as u16 & 15))
    }
    fn is_air(&self) -> bool {
        self.value == 0
    }
}
impl Default for BlockData {
    fn default() -> BlockData {
        BlockData {
            value: 0
        }
    }
}


impl ChunkSection {
    #[inline(always)]
    fn block_array_index(x: u16, y: u16, z: u16) -> usize {
        ((x & 15) | ((z & 15) << 4) | ((y & 15) << 8)) as usize
    }

    fn get_block(&self, x: u16, y: u16, z: u16) -> &BlockData {
        &self.block_data[ChunkSection::block_array_index(x, y, z)]
    }

    fn set_block_raw(&mut self, x: u16, y: u16, z: u16, block: BlockData) {
        self.block_data[ChunkSection::block_array_index(x, y, z)] = block;
    }
    fn set_block(&mut self, x: u16, y: u16, z: u16, block: BlockData) {
        if self.get_block(x, y, z).is_air() && !block.is_air() {
            self.count += 1;
        } else if !self.get_block(x, y, z).is_air() && block.is_air() {
            self.count -= 1;
        }
        self.set_block_raw(x, y, z, block);
    }

    fn recount(&mut self) {
        self.count = 0;
        for block in &self.block_data[..] {
            if !block.is_air() {
                self.count += 1;
            }
        }
    }
    fn is_empty(&self) -> bool {
        //for block in &self.block_data[..] {
        //    if !block.is_air() {
        //        return false;
        //    }
        //}
        //true
        self.count == 0
    }

    fn borrow_block_data(&self) -> &[BlockData; SECTION_BUF_LEN] {
        return &self.block_data;
    }
    fn borrow_light_data(&self) -> &[u8; SECTION_BUF_LEN / 2] {
        return &self.block_light;
    }
    fn borrow_skylight_data(&self) -> &[u8; SECTION_BUF_LEN / 2] {
        return &self.skylight;
    }
}
impl Default for ChunkSection {
    fn default() -> ChunkSection {
        ChunkSection {
            block_data: [BlockData::default(); SECTION_BUF_LEN],
            block_light: [0u8; SECTION_BUF_LEN / 2],
            skylight: [0u8; SECTION_BUF_LEN / 2],
            count: 0,
        }
    }
}

fn count_bits(num: u16) -> u8 {
    let mut res = 0;
    let mut num = num;
    while num > 0 {
        res += 1;
        num = num & (num - 1);
    }
    res
}

impl Chunk {
    #[inline(always)]
    fn section_array_index(y: u16) -> usize {
        ((y >> 4) & 15) as usize
    }
    pub fn get_block(&self, x: u16, y: u16, z: u16) -> &BlockData {
        self.sections[Chunk::section_array_index(y)].get_block(x, y, z)
    }

    fn count_bytes(entire_chunk: bool, num_sections: u8, skylight: bool) -> u32 {
        let mut byte_size: u32 = 0;

        let mut section_size: u32 = (SECTION_BUF_LEN as u32) * 5 / 2;
        if skylight { section_size += (SECTION_BUF_LEN as u32) / 2 };
        byte_size += num_sections as u32 * section_size;

        if entire_chunk { byte_size += BIOME_BUF_LEN as u32 };

        byte_size
    }

    pub fn get_transmit_data(&self, skylight: bool, entire_chunk: bool, bitmask: u16, 
                             get_buffer_fun: &Fn(u32) -> Vec<u8>) -> (u16, Vec<u8>, u32) {
        let mut section_bitmask: u16;
        if entire_chunk {
            section_bitmask = MAX_BITMASK;
        } else {
            section_bitmask = bitmask & MAX_BITMASK;
        }

        let mut added_sections: Vec<&ChunkSection> = Vec::with_capacity(16);
        for section_num in 0..CHUNK_SECTION_HEIGHT {
            let section = &self.sections[section_num];
            if section.is_empty() {
                section_bitmask = section_bitmask & !(1 << section_num);
            }

            if section_bitmask & (1 << section_num) != 0 {
                added_sections.push(section);
            }
        }
        let num_sections = count_bits(section_bitmask);
        let byte_size = Chunk::count_bytes(entire_chunk, num_sections, skylight);

        let mut buffer: Vec<u8> = get_buffer_fun(byte_size);

        // Block types
        for section in &added_sections { 
            for block in &section.borrow_block_data()[..] {
                buffer.write_u16::<byteorder::LittleEndian>(*block.get_value()).unwrap();
            }
        }
        // Block light
        for section in &added_sections {
            for light in &section.borrow_light_data()[..] {
                buffer.write_u8(*light).unwrap();
            }
        }

        if skylight {
            for section in &added_sections {
                for light in &section.borrow_skylight_data()[..] {
                    buffer.write_u8(*light).unwrap();
                }
            }
        }

        if entire_chunk {
            for biome in &self.biome[..] {
                buffer.write_u8(*biome).unwrap();
            }
        }
        
        (section_bitmask, buffer, byte_size)
    }
}
